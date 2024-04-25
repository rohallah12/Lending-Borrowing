//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "./library/DataTypes.sol";
import {rToken} from "./RToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is ReentrancyGuard {
    using SafeERC20 for ERC20;

    mapping(uint => DataTypes.DebtPosition) public debtPosition;
    mapping(uint => DataTypes.Reserve) public reserves;
    mapping(uint => mapping(address => uint)) public credit;
    mapping(address => bool) public isWhitelistedBorrower;

    /**
     * msg.sender in this function is a vault */
    function borrow(
        address _onBehalfOf,
        uint _debtId,
        uint _amount
    ) external nonReentrant {
        require(
            isWhitelistedBorrower[msg.sender],
            "borrower is not whitelisetd"
        );

        //validate that position is open and not disabled
        DataTypes.DebtPosition storage position = debtPosition[_debtId];
        DataTypes.Reserve storage reserve = reserves[position.reserveId];

        require(!reserve.isFreezed && reserve.isEnabled, "Debt is not active");
        require(position.owner == msg.sender, "only position owner can change");
        require(
            credit[position.reserveId][msg.sender] >= _amount,
            "not enough credit"
        );
        require(
            _amount + reserve.totalBorrowed <= reserve.maxBorrow,
            "Can't borrow more than maximum from this reserve"
        );

        credit[position.reserveId][msg.sender] -= _amount;
        position.borrowed += _amount;
        reserve.totalBorrowed += _amount;

        //transfer reserve token to msg.sender
        rToken(reserve.rToken).transferUnderlying(_amount, msg.sender);
    }

    function repay(uint _debtId, uint _repayAmount) external nonReentrant {
        require(
            isWhitelistedBorrower[msg.sender],
            "borrower is not whitelisetd"
        );
        DataTypes.DebtPosition storage position = debtPosition[_debtId];
        DataTypes.Reserve storage reserve = reserves[position.reserveId];

        require(msg.sender == position.owner, "msg.sender must be the owner");

        if (_repayAmount > position.borrowed) {
            _repayAmount = position.borrowed;
        }

        position.borrowed -= _repayAmount;
        reserve.totalBorrowed -= _repayAmount;
        credit[position.reserveId][msg.sender] += _repayAmount;

        ERC20(reserve.underlyingAsset).safeTransferFrom(
            msg.sender,
            address(reserve.rToken),
            _repayAmount
        );
    }

    function redeem(
        uint _reserveId,
        uint _amountToRedeem
    ) external nonReentrant {
        DataTypes.Reserve storage reserve = reserves[_reserveId];
        ERC20(reserve.rToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amountToRedeem
        );

        _redeem(msg.sender, reserve.rToken, _amountToRedeem);
    }

    function _redeem(
        address _receiver,
        address _rToken,
        uint _redeemAmount
    ) internal {
        //get the convertion and convert rToken amount to underlying amount
        
    }

    //unstake from the stakingPool and then redeem the R tokens
    function unstakeAndWithdraw() external {}
}
