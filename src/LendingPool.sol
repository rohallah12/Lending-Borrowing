//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DataTypes} from "./library/DataTypes.sol";
import {rToken} from "./RToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReserveLogic} from "./library/ReserveLogic.sol";
import {Payments} from "./Payment.sol";

contract LendingPool is ReentrancyGuard, Payments {
    using SafeERC20 for ERC20;
    using ReserveLogic for DataTypes.Reserve;

    uint public debtIds;
    mapping(uint => DataTypes.DebtPosition) public debtPosition;
    mapping(uint => DataTypes.Reserve) public reserves;
    mapping(uint => mapping(address => uint)) public credit;
    mapping(address => bool) public isWhitelistedBorrower;

    modifier avoidUsingNativeEther() {
        require(msg.value == 0, "msg value must be zero");
        _;
    }

    event Redeemed(
        uint indexed reservedId,
        uint rTokenAmount,
        uint underlyingAmount,
        address indexed receiver,
        address indexed redemer
    );

    constructor(address _WETH9) Payments(_WETH9) {}

    //how to open a debtposition? we know that to be albe to borrow tokens we need a debtId, and we have to be
    //owner of that debt position, so before everything else, we have to open a debt position
    function newDebtPosition(
        uint _reserveId
    ) public nonReentrant returns (uint debtId) {
        DataTypes.Reserve memory reserve = reserves[_reserveId];

        //checking that reserve is active for borrowing and is also not freezed
        require(reserve.isEnabled, "Reserve is not enabled");
        require(!reserve.isFreezed, "Reserve is freezed");

        //update reserve state before creating a new positions here
        //TO-DO

        debtId = debtIds++;
        DataTypes.DebtPosition memory position = DataTypes.DebtPosition({
            owner: msg.sender,
            reserveId: _reserveId,
            borrowed: 0,
            borrowIndex: reserve.borrowingIndex
        });

        debtPosition[debtId] = position;
    }

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
        uint _amountToRedeem,
        address _to,
        bool _receiveNativeETH
    ) external payable nonReentrant avoidUsingNativeEther {
        DataTypes.Reserve storage reserve = reserves[_reserveId];

        if (_amountToRedeem == ~uint256(0)) {
            _amountToRedeem = ERC20(reserve.rToken).balanceOf(msg.sender);
        }

        ERC20(reserve.rToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amountToRedeem
        );

        uint underlyingAmount = _redeem(
            reserve,
            _amountToRedeem,
            _to,
            _receiveNativeETH
        );

        emit Redeemed(
            _reserveId,
            _amountToRedeem,
            underlyingAmount,
            _to,
            msg.sender
        );
    }

    function _redeem(
        DataTypes.Reserve storage reserve,
        uint _redeemAmount,
        address _to,
        bool _receiveNative
    ) internal returns (uint underlyingAmount) {
        //get the convertion and convert rToken amount to underlying amount
        //@audit-info rounds down
        underlyingAmount =
            (_redeemAmount * reserve.getRTokenExchangeRate()) /
            1e18;

        require(
            underlyingAmount <= reserve.availableLiquidity(),
            "not enough tokens available"
        );

        if (_receiveNative && reserve.underlyingAsset == WETH9) {
            rToken(reserve.rToken).burn(
                address(this), //burning from this address, since tokens are here now
                _redeemAmount,
                underlyingAmount
            );
            // unwrap WETH9 and send
            unwrapWETH9(underlyingAmount, _to);
        } else {
            rToken(reserve.rToken).burn(_to, _redeemAmount, underlyingAmount);
        }
    }

    //unstake from the stakingPool and then redeem the R tokens
    function unstakeAndWithdraw() external {}
}
