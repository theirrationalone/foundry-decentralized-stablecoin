// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {FakeERC20V1} from "../mocks/FakeERC20V1.m.sol";

contract FakeERC20V1Test is Test {
    FakeERC20V1 fakeErc20V1;

    function setUp() external {
        fakeErc20V1 = new FakeERC20V1();
    }

    function testFakeERC20V1WorksWell() public {
        bool successTransferFrom = fakeErc20V1.transferFrom(address(1), address(2), 1);
        bool successTransfer = fakeErc20V1.transfer(address(1), 1);

        assertEq(successTransferFrom, false);
        assertEq(successTransfer, false);
    }
}
