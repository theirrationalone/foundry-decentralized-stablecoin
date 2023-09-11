// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {FakeV2ERC20} from "../mocks/FakeV2ERC20.m.sol";

contract FakeV2ERC20Test is Test {
    FakeV2ERC20 fakeV2Erc20;

    function setUp() external {
        fakeV2Erc20 = new FakeV2ERC20();
    }

    function testV2FakeERC20WorksWell() public {
        bool successTransfer = fakeV2Erc20.transfer(address(1), 1);

        assertEq(successTransfer, false);
    }

    function testV2FakeERC20WorksWellPartTwo() public {
        bool successTransferFrom = fakeV2Erc20.transferFrom(address(1), address(2), 1);

        assertEq(successTransferFrom, true);
    }
}
