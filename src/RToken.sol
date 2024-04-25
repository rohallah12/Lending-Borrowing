//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//rToken will be minted to borrowers
contract rToken is ReentrancyGuard, ERC20("rsam debt Token", "rToken") {
    using SafeERC20 for ERC20;

    ERC20 public immutable underlyingAsset;
    address public immutable lendingPool;

    modifier OnlyLendingPool() {
        require(msg.sender == lendingPool, "only lending pool can call this");
        _;
    }

    constructor(address _lendingPool, ERC20 _underlying) {
        underlyingAsset = _underlying;
        lendingPool = _lendingPool;
    }

    function mint(
        address _receiver,
        uint _amount
    ) external OnlyLendingPool nonReentrant {
        _mint(_receiver, _amount);
    }

    function burn(
        address _receiver,
        uint _rTokenAmount,
        uint _underlyingAmount
    ) external OnlyLendingPool nonReentrant {
        _burn(msg.sender, _rTokenAmount);
        underlyingAsset.safeTransfer(_receiver, _underlyingAmount);
    }

    function mintToTreasury(
        address _treasury,
        uint _amount
    ) external OnlyLendingPool nonReentrant {
        _mint(_treasury, _amount);
    }

    function transferUnderlying(
        uint _amount,
        address _to
    ) external OnlyLendingPool nonReentrant {
        underlyingAsset.safeTransfer(_to, _amount);
    }
}
