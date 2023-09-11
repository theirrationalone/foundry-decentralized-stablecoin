// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {FakeERC20V2} from "../mocks/FakeERC20V2.m.sol";

contract FakeERC20V2Test is Test {
    FakeERC20V2 fakeErc20V2;

    function setUp() external {
        fakeErc20V2 = new FakeERC20V2();
    }

    function testFakeERC20V2WorksWell() public {
        bool successTransfer = fakeErc20V2.transfer(address(1), 1);

        assertEq(successTransfer, false);
    }

    function testFakeERC20V2WorksWellPartTwo() public {
        bool successTransferFrom = fakeErc20V2.transferFrom(address(1), address(2), 1);

        assertEq(successTransferFrom, true);
    }
}
