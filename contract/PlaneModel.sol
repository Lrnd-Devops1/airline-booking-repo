// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

error InvalidPlaneModel(string name);

function getPlaneModel(string memory modelName, address airline) returns (PlaneModel) {
    bytes32 modelBytes = keccak256(abi.encodePacked(modelName));
    
    if(modelBytes == keccak256(abi.encodePacked("A320NEO")))
        return new AirbusA320Neo(airline);
    else if(modelBytes == keccak256(abi.encodePacked("B737MAX")))
        return new BoeingB737Max(airline);
    else
        revert InvalidPlaneModel(modelName);
}

enum SeatCategory {
    ECONOMY,
    PREMIUM_ECONOMY,
    BUSINESS,
    FIRST_CLASS
}

enum CancellationPenaltyRange {
    GT_FOUR_DAYS,
    ONE_TO_FOUR_DAYS,
    LT_ONE_DAY
}

enum DelayPenaltyRange {
    GT_EIGHT_HOURS,
    FOUR_TO_EIGHT_HOURS,
    ONE_TO_FOUR_HOURS,
    LT_ONE_HOUR
}

abstract contract PlaneModel {
    address airline;
    mapping(SeatCategory => uint256) public prices;
    mapping(SeatCategory => uint256) public layout;
    SeatCategory[] categories;
    mapping(CancellationPenaltyRange => uint256) cancellationPenalty;
    mapping(DelayPenaltyRange => uint256) delayPenalty;

    function initLayout() internal virtual;
    function initPrices() internal virtual;
    function initCategories() internal virtual;
    function initCancellationPenalty() internal virtual;
    function initDelayPenalty() internal virtual;

    constructor(address _airline) {
        airline = _airline;
        
        initCategories();
        initLayout();
        initPrices();
    }
    
    modifier onlyAirline() {
        require(msg.sender == airline, "Only the airline can do this");
        _;
    }
    
    function getCancellationPenaltyRange(uint256 timeDiff) pure private returns (CancellationPenaltyRange) {
        if(timeDiff > 4 days)
            return CancellationPenaltyRange.GT_FOUR_DAYS;
        else if(timeDiff < 4 days && timeDiff > 1 days)
            return CancellationPenaltyRange.ONE_TO_FOUR_DAYS;
        else
            return CancellationPenaltyRange.LT_ONE_DAY;
    }

    function getDelayPenaltyRange(uint256 timeDiff) pure private returns (DelayPenaltyRange) {
        if(timeDiff > 8 hours)
            return DelayPenaltyRange.GT_EIGHT_HOURS;
        else if(timeDiff < 8 hours && timeDiff > 4 hours)
            return DelayPenaltyRange.FOUR_TO_EIGHT_HOURS;
        else if(timeDiff < 4 hours && timeDiff > 1 hours)
            return DelayPenaltyRange.ONE_TO_FOUR_HOURS;
        else
            return DelayPenaltyRange.LT_ONE_HOUR;
    }

    function getCancellationPenalty(uint256 departure) view public returns (uint256) {
        uint256 timeDiff = block.timestamp - departure;
        CancellationPenaltyRange index = getCancellationPenaltyRange(timeDiff);
        
        return cancellationPenalty[index];
    }

    function getDelayPenalty(uint256 newDeparture, uint256 origDeparture) view public returns (uint256) {
        uint256 timeDiff = newDeparture - origDeparture;
        DelayPenaltyRange index = getDelayPenaltyRange(timeDiff);
        
        return delayPenalty[index];
    }

    function getCategories() view public returns (SeatCategory[] memory) {
        return categories;
    }
    
    function updatePrice(SeatCategory cat, uint256 newPrice) public onlyAirline {
        prices[cat] = newPrice;
    }
}

contract AirbusA320Neo is PlaneModel {
    
    constructor(address airline) PlaneModel(airline) {
    }
    
    function initLayout() internal override {
        layout[SeatCategory.ECONOMY] = 30;
        layout[SeatCategory.PREMIUM_ECONOMY] = 20;
        layout[SeatCategory.BUSINESS] = 10;
        layout[SeatCategory.FIRST_CLASS] = 5;
    }
    
    function initPrices() internal override {
        prices[SeatCategory.ECONOMY] = 100 gwei;
        prices[SeatCategory.PREMIUM_ECONOMY] = 200 gwei;
        prices[SeatCategory.BUSINESS] = 300 gwei;
        prices[SeatCategory.FIRST_CLASS] = 400 gwei;
    }
    
    function initCategories() internal override {
        categories.push(SeatCategory.ECONOMY);
        categories.push(SeatCategory.PREMIUM_ECONOMY);
        categories.push(SeatCategory.BUSINESS);
        categories.push(SeatCategory.FIRST_CLASS);
    }
    
    function initCancellationPenalty() internal override {
        // This is percentage, calculated by the consumer
        cancellationPenalty[CancellationPenaltyRange.GT_FOUR_DAYS] = 20;
        cancellationPenalty[CancellationPenaltyRange.ONE_TO_FOUR_DAYS] = 50;
        cancellationPenalty[CancellationPenaltyRange.LT_ONE_DAY] = 100;
    }
    
    function initDelayPenalty() internal override {
        // This is percentage, calculated by the consumer

        delayPenalty[DelayPenaltyRange.GT_EIGHT_HOURS] = 0;
        delayPenalty[DelayPenaltyRange.FOUR_TO_EIGHT_HOURS] = 30;
        delayPenalty[DelayPenaltyRange.ONE_TO_FOUR_HOURS] = 70;
        delayPenalty[DelayPenaltyRange.LT_ONE_HOUR] = 100;
    }
}

contract BoeingB737Max is PlaneModel {

    constructor(address airline) PlaneModel(airline) {
    }
    
    function initLayout() internal override {
        layout[SeatCategory.ECONOMY] = 35;
        layout[SeatCategory.PREMIUM_ECONOMY] = 25;
        layout[SeatCategory.BUSINESS] = 15;
        layout[SeatCategory.FIRST_CLASS] = 10;
    }
    
    function initPrices() internal override {
        prices[SeatCategory.ECONOMY] = 120 gwei;
        prices[SeatCategory.PREMIUM_ECONOMY] = 220 gwei;
        prices[SeatCategory.BUSINESS] = 320 gwei;
        prices[SeatCategory.FIRST_CLASS] = 420 gwei;
    }
    
    function initCategories() internal override {
        categories.push(SeatCategory.ECONOMY);
        categories.push(SeatCategory.PREMIUM_ECONOMY);
        categories.push(SeatCategory.BUSINESS);
        categories.push(SeatCategory.FIRST_CLASS);
    }

    function initCancellationPenalty() internal override {
        // This is percentage, calculated by the consumer
        cancellationPenalty[CancellationPenaltyRange.GT_FOUR_DAYS] = 25;
        cancellationPenalty[CancellationPenaltyRange.ONE_TO_FOUR_DAYS] = 55;
        cancellationPenalty[CancellationPenaltyRange.LT_ONE_DAY] = 100;
    }
    
    function initDelayPenalty() internal override {
        // This is percentage, calculated by the consumer

        delayPenalty[DelayPenaltyRange.GT_EIGHT_HOURS] = 0;
        delayPenalty[DelayPenaltyRange.FOUR_TO_EIGHT_HOURS] = 35;
        delayPenalty[DelayPenaltyRange.ONE_TO_FOUR_HOURS] = 75;
        delayPenalty[DelayPenaltyRange.LT_ONE_HOUR] = 100;
    }
}
