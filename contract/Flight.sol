// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./PlaneModel.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

enum FlightStatus {
    SCHEDULED,
    ONTIME,
    DELAYED,
    DEPARTED,
    CANCELLED
}

contract Flight {
    // Flight details
    string public flightNumber;
    uint256 public flightTime;
    FlightStatus public flightStatus;
    uint256 public flightStatusUpdateTime;

    // Seating information
    PlaneModel model;
    mapping(SeatCategory => uint256) public seats;
    SeatCategory[] categories;
    uint256 totalSeats;
    uint256 bookedSeats;
    mapping(string => Ticket) cfidToTicketMap;

    address owner;
    
    error FlightFull();
    error SeatNotAvailableInCategory();
    error InvalidFlightStatusChange();
    
    constructor(string memory flNum, uint256 flTime) {
        owner = msg.sender;
        flightNumber = flNum;
        flightTime = flTime;
        flightStatus = FlightStatus.SCHEDULED;
        flightStatusUpdateTime = 0;
        model = new AirbusA320Neo();
        categories = model.getCategories();
        bookedSeats = 0;
        for(uint256 i = 0; i < categories.length; ++i) {
            seats[categories[i]] = model.getLayout(categories[i]);
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
        require(flightStatus != FlightStatus.DEPARTED && flightStatus != FlightStatus.CANCELLED, "Flight status not valid for this action");
        _;
    }
    
    function bookSeat(SeatCategory category) payable external flightValid returns (string memory) {
        require(msg.value == model.getPrice(category), "Not enough Ether provided");

        if(bookedSeats == totalSeats) {
            revert FlightFull();
        }
        
        if(seats[category] == 0) {
            revert SeatNotAvailableInCategory();
        }
        
        string memory cfid = string(abi.encodePacked("CONFIRM", Strings.toString(bookedSeats)));

        Ticket tkt = new Ticket{value: msg.value}(cfid, owner, msg.sender, this, category);
        cfidToTicketMap[cfid] = tkt;

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
        
        uint256 refund = model.getPrice(category) - uint256(model.getPrice(category) * model.cancellationPenalty());
        
        return refund;
    }
    
    function updateStatus(FlightStatus status) external flightValid onlyAirline {
        if(status < flightStatus) {
            revert InvalidFlightStatusChange();
        }
        
        flightStatus = status;
        flightStatusUpdateTime = block.timestamp;
    }
    
    function flightCancelledClaim(string calldata cfid) public onlyTicket(cfid) {
        Ticket tkt = cfidToTicketMap[cfid];

        SeatCategory category = tkt.seatCategory();
        
        ++seats[category];
        --bookedSeats;
    }
    
    function delayClaim(string calldata cfid) public flightValid onlyTicket(cfid) returns (uint256) {
        Ticket tkt = cfidToTicketMap[cfid];

        SeatCategory category = tkt.seatCategory();
        
        ++seats[category];
        --bookedSeats;
        
        uint256 refund = model.getPrice(category) - uint256(model.getPrice(category) * model.delayPenalty());
        
        return refund;
    }
}

contract Ticket {
    string public confirmationID;
    address public airline;
    address public customer;
    Flight flightContract;
    SeatCategory public seatCategory;
    bool cancelled;
    
    modifier onlyCustomer {
        require(msg.sender == customer, "Only the ticket owner can do this");
        _;
    }
    
    modifier onlyAirline {
        require(msg.sender == airline, "Only the airlines can do this");
        _;
    }
    
    modifier notCancelled {
        require(!cancelled, "Ticket is already cancelled");
        _;
    }
    
    event Booked(address indexed, address indexed, string);
    event Refunded(address indexed, uint256);
    event Cancelled(address indexed, string);
    
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
    
    function cancel() external payable onlyCustomer notCancelled {
        require(flightContract.flightTime() - (2 hours) >= block.timestamp, "Ticket can only be cancelled two hours prior to departure");
        uint256 refund = flightContract.cancelTicket(confirmationID);
        uint256 balance = address(this).balance;
        
        payable(customer).transfer(refund);
        payable(airline).transfer(balance - refund);
        
        cancelled = true;
        
        emit Cancelled(customer, confirmationID);
        emit Refunded(customer, refund);
        emit Refunded(airline, balance - refund);
    }
    
    function claim() external onlyCustomer notCancelled {
        require(flightContract.flightTime() + (24 hours) >= block.timestamp, "Claim can be made 24 hours after departure");
        
        FlightStatus status = flightContract.flightStatus();
        if(status == FlightStatus.CANCELLED) {
            uint256 balance = address(this).balance;

            flightContract.flightCancelledClaim(confirmationID);

            payable(customer).transfer(balance);

            cancelled = true;

            emit Cancelled(customer, confirmationID);
            emit Refunded(customer, balance);
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
        }
        else if(status == FlightStatus.SCHEDULED) {
            if( ! ( ( flightContract.flightTime() - (24 hours)) <= flightContract.flightStatusUpdateTime()
                && flightContract.flightStatusUpdateTime() < flightContract.flightTime() ) ) {
                uint256 balance = address(this).balance;

                flightContract.flightCancelledClaim(confirmationID);

                payable(customer).transfer(balance);

                cancelled = true;
                
                emit Cancelled(customer, confirmationID);
                emit Refunded(customer, balance);
            }
        }
        else {
            // do nothing
        }
    }
}

