//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IWETH9} from "./interfaces/IWETH9.sol";
import {TransferHelper} from "./library/TransferHelper.sol";

contract Payments {
    address public immutable WETH9;

    constructor(address _weth9) {
        WETH9 = _weth9;
    }

    //unwrap _amount
    function unwrapWETH9(uint _minimumAmount, address _recipient) internal {
        uint balance = IWETH9(WETH9).balanceOf(address(this));
        require(_minimumAmount <= balance, "not enough WETH9");
        if (balance > 0) {
            IWETH9(WETH9).withdraw(balance);
            TransferHelper.safeTransferETH(_recipient, balance);
        }
    }

    function refundETH() internal {
        if (address(this).balance > 0)
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{value: value}(); // wrap only what is needed to pay
            require(
                IWETH9(WETH9).transfer(recipient, value),
                "transfer failed"
            );
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
}
