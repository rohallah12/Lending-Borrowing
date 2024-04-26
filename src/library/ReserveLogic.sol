//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "./DataTypes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//a library for working with reserve data structur
library ReserveLogic {
    //total available liquidity
    function totalLiquidityAndBorrowed(
        DataTypes.Reserve storage reserve
    ) public view returns (uint total, uint borrowed) {
        borrowed = totalBorrow(reserve);
        total = totalAvailable(reserve) + borrowed;
    }

    function totalBorrow(
        DataTypes.Reserve storage reserve
    ) public view returns (uint) {
        return reserve.totalBorrowed; //+ interest
    }

    function totalAvailable(
        DataTypes.Reserve storage reserve
    ) public view returns (uint) {
        return ERC20(reserve.underlyingAsset).balanceOf(reserve.rToken);
    }

    //get price of the rToken
    function getRTokenExchangeRate(
        DataTypes.Reserve storage reserve
    ) public view returns (uint) {
        //total underlying = total available + total borrowed + total interests
        (uint totalAsset, ) = totalLiquidityAndBorrowed(reserve);
        uint totalR = ERC20(reserve.rToken).totalSupply();

        return (totalR * 1e18) / totalAsset;
    }
}
