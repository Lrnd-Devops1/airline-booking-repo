// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

enum SeatCategory {
    ECONOMY,
    PREMIUM_ECONOMY,
    BUSINESS,
    FIRST_CLASS
}

abstract contract PlaneModel {
    function getLayout(SeatCategory cat) view public virtual returns (uint256);
    function getCategories() view public virtual returns (SeatCategory[] memory);
    function getPrice(SeatCategory cat) view public virtual returns (uint256);
    function cancellationPenalty() view external virtual returns (uint256);
    function delayPenalty() view external virtual returns (uint256);
}

contract AirbusA320Neo is PlaneModel {
    mapping(SeatCategory => uint256) prices;
    mapping(SeatCategory => uint256) layout;
    SeatCategory[] categories;
    uint256 public override cancellationPenalty;
    uint256 public override delayPenalty;
    
    constructor() {
        categories.push(SeatCategory.ECONOMY);
        categories.push(SeatCategory.PREMIUM_ECONOMY);
        categories.push(SeatCategory.BUSINESS);
        categories.push(SeatCategory.FIRST_CLASS);
        
        prices[SeatCategory.ECONOMY] = 1 ether;
        prices[SeatCategory.PREMIUM_ECONOMY] = 2 ether;
        prices[SeatCategory.BUSINESS] = 3 ether;
        prices[SeatCategory.FIRST_CLASS] = 4 ether;
        
        layout[SeatCategory.ECONOMY] = 30;
        layout[SeatCategory.PREMIUM_ECONOMY] = 20;
        layout[SeatCategory.BUSINESS] = 10;
        layout[SeatCategory.FIRST_CLASS] = 5;
        
        // This is percentage, calculated by the consumer
        cancellationPenalty = 2;
        delayPenalty = 1;
    }
    
    function getLayout(SeatCategory cat) view public override returns (uint256) {
        return layout[cat];
    }
    
    function getCategories() view public override returns (SeatCategory[] memory) {
        return categories;
    }
    
    function getPrice(SeatCategory cat) view public override returns (uint256) {
        return prices[cat];
    }
}
