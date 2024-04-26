//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library DataTypes {
    struct DebtPosition {
        address owner;
        uint reserveId;
        uint borrowed;
        uint borrowIndex;
    }

    struct Reserve {
        uint reserveId;
        uint borrowingIndex;
        uint totalBorrowed;
        uint maxBorrow;
        address rToken;
        address underlyingAsset;
        bool isEnabled;
        bool isFreezed;
    }
}
