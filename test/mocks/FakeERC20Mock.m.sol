// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeERC20 is ERC20 {
    constructor() ERC20("FAKE ERC", "FERC20M") {}

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}
