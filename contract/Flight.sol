// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./PlaneModel.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

enum FlightStatus {
    SCHEDULED,
    ONTIME,
    DELAYED,
    CANCELLED
}

contract Flight {
    // Flight details
    string public flightNumber;
    uint256 public flightTime;
    uint256 public origFlightTime;
    FlightStatus public flightStatus;
    uint256 flightStatusUpdateTime;
    string public src;
    string public dst;

    // Seating information
    PlaneModel public model;
    mapping(SeatCategory => uint256) public seats;
    SeatCategory[] categories;
    uint256 totalSeats;
    uint256 bookedSeats;
    mapping(string => Ticket) cfidToTicketMap;
    string[] cfids;

    address owner;
    
    error FlightFull();
    error SeatNotAvailableInCategory();
    error InvalidFlightStatusChange();
    
    constructor(string memory flNum, uint256 flTime, string memory flModel) {
        owner = msg.sender;
        flightNumber = flNum;
        flightTime = origFlightTime = flTime;
        flightStatus = FlightStatus.SCHEDULED;
        flightStatusUpdateTime = 0;
        
        model = getPlaneModel(flModel, owner);
        categories = model.getCategories();
        
        bookedSeats = 0;
        for(uint256 i = 0; i < categories.length; ++i) {
            seats[categories[i]] = model.layout(categories[i]);
            totalSeats += seats[categories[i]];
        }
    }

    modifier onlyAirline {
        require(msg.sender == owner, "Only the airlines can do this");
        _;
    }
    
    modifier onlyTicket(string calldata cfid) {
        Ticket tkt = cfidToTicketMap[cfid];
        require(address(tkt) == msg.sender, "Only the ticket contract can do this");
        _;
    }
    
    modifier flightValid {
        require(flightStatus == FlightStatus.SCHEDULED, "Flight status not valid for this action");
        _;
    }
    
    function bookSeat(SeatCategory category) payable external flightValid returns (string memory) {
        require(msg.value == model.prices(category), "Not enough Ether provided");

        if(bookedSeats == totalSeats) {
            revert FlightFull();
        }
        
        if(seats[category] == 0) {
            revert SeatNotAvailableInCategory();
        }
        
        string memory cfid = string(abi.encodePacked("CONFIRM", Strings.toString(bookedSeats)));

        Ticket tkt = new Ticket{value: msg.value}(cfid, owner, msg.sender, this, category);
        cfidToTicketMap[cfid] = tkt;
        cfids.push(cfid);

        --seats[category];
        ++bookedSeats;

        return cfid;
    }
    
    function getTicketFromID(string calldata cfid) external view returns (Ticket) {
        return cfidToTicketMap[cfid];
    }
    
    function cancelTicket(string calldata cfid) public flightValid onlyTicket(cfid) returns (uint256) {
        Ticket tkt = cfidToTicketMap[cfid];

        SeatCategory category = tkt.seatCategory();
        
        ++seats[category];
        --bookedSeats;
        
        uint256 refund = model.prices(category) - uint256((model.prices(category) * model.getCancellationPenalty(flightTime)) / 100);
        
        return refund;
    }

    function _updateStatus(FlightStatus status) private {
        flightStatus = status;
        flightStatusUpdateTime = block.timestamp;
    }

    function delayFlight(uint256 newFlightTime) external flightValid onlyAirline {
        origFlightTime = flightTime;
        flightTime = newFlightTime;
        
        _updateStatus(FlightStatus.DELAYED);
    }
    
    function updateStatus(FlightStatus status) external flightValid onlyAirline {
        require(status != FlightStatus.DELAYED, "Call delayFlight to do this.");
        _updateStatus(status);
    }
    
    function flightCancelledClaim(string calldata cfid) public onlyTicket(cfid) {
        Ticket tkt = cfidToTicketMap[cfid];

        SeatCategory category = tkt.seatCategory();
        
        ++seats[category];
        --bookedSeats;
    }
    
    function delayClaim(string calldata cfid) public onlyTicket(cfid) returns (uint256) {
        Ticket tkt = cfidToTicketMap[cfid];

        SeatCategory category = tkt.seatCategory();
        
        ++seats[category];
        --bookedSeats;
        
        uint256 refund = model.prices(category) - uint256((model.prices(category) * model.getDelayPenalty(flightTime, origFlightTime)) / 100);
        
        return refund;
    }
    
    function collectMoney() public onlyAirline {
        require(block.timestamp > flightTime + (7 days), "Cannot collect money yet. Wait for upto 7 days after departure.");
        
        for(uint256 i = 0; i < cfids.length; ++i) {
            Ticket tkt = cfidToTicketMap[cfids[i]];
            
            if(tkt.cancelled()) continue; // Already processed
            
            tkt.collectMoney();
        }
    }
    
    function setSource(string calldata _src) public onlyAirline {
        src = _src;
    }
    
    function setDest(string calldata _dst) public onlyAirline {
        dst = _dst;
    }
}

contract Ticket {
    string public confirmationID;
    address public airline;
    address public customer;
    Flight flightContract;
    SeatCategory public seatCategory;
    bool public cancelled;
    
    modifier onlyCustomer {
        require(msg.sender == customer, "Only the ticket owner can do this");
        _;
    }
    
    modifier onlyAirline {
        require(msg.sender == airline, "Only the airlines can do this");
        _;
    }

    modifier onlyFlight() {
        require(address(flightContract) == msg.sender, "Only the flight contract can do this");
        _;
    }
    
    modifier notCancelled {
        require(!cancelled, "Ticket is already cancelled");
        _;
    }
    
    event Booked(address indexed, address indexed, string);
    event Refunded(address indexed, uint256);
    event Cancelled(address indexed, string);
    event Collected(address indexed, uint256);
    
    constructor(string memory _confirmationID, address _airline, address _customer, Flight _flightContract, SeatCategory _seatCategory) payable {
        airline = _airline;
        customer = _customer;
        confirmationID = _confirmationID;
        flightContract = _flightContract;
        seatCategory = _seatCategory;
        cancelled = false;
        
        emit Booked(customer, address(this), confirmationID);
    }
    
    function ticketValue() external view returns (uint256) {
        return address(this).balance;
    }
    
    function cancel() external onlyCustomer notCancelled {
        require(block.timestamp < flightContract.flightTime() - (2 hours), "Ticket can only be cancelled two hours prior to departure");
        uint256 refund = flightContract.cancelTicket(confirmationID);
        uint256 balance = address(this).balance;
        
        payable(customer).transfer(refund);
        payable(airline).transfer(balance - refund);
        
        cancelled = true;
        
        emit Cancelled(customer, confirmationID);
        emit Refunded(customer, refund);
        emit Refunded(airline, balance - refund);
        
        assert(address(this).balance == 0);
    }
    
    function claim() external onlyCustomer notCancelled {
        require(block.timestamp >= flightContract.flightTime() + (24 hours), "Claim can be made 24 hours after departure");
        require(block.timestamp < flightContract.flightTime() + (7 days), "Claim can be made only upto 7 days after departure");
        
        FlightStatus status = flightContract.flightStatus();
        if(status == FlightStatus.CANCELLED) {
            uint256 balance = address(this).balance;

            flightContract.flightCancelledClaim(confirmationID);

            payable(customer).transfer(balance);

            cancelled = true;

            emit Cancelled(customer, confirmationID);
            emit Refunded(customer, balance);
            
            assert(address(this).balance == 0);
        }
        else if(status == FlightStatus.DELAYED) {
            uint256 refund = flightContract.delayClaim(confirmationID);
            uint256 balance = address(this).balance;

            payable(customer).transfer(refund);
            payable(airline).transfer(balance - refund);

            cancelled = true;

            emit Cancelled(customer, confirmationID);
            emit Refunded(customer, refund);
            emit Refunded(airline, balance - refund);

            assert(address(this).balance == 0);
        }
        else if(status == FlightStatus.SCHEDULED) {
            uint256 balance = address(this).balance;

            flightContract.flightCancelledClaim(confirmationID);

            payable(customer).transfer(balance);

            cancelled = true;
            
            emit Cancelled(customer, confirmationID);
            emit Refunded(customer, balance);

            assert(address(this).balance == 0);
        }
        else {
            // do nothing, flight was on time. No refunds.
        }
    }
    
    function collectMoney() public onlyFlight {
        uint256 balance = address(this).balance;

        payable(airline).transfer(balance);
        
        emit Collected(airline, balance);
        
        assert(address(this).balance == 0);
    }
}

