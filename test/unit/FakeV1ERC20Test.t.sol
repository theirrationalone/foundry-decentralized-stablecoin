// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {FakeV1ERC20} from "../mocks/FakeV1ERC20.m.sol";

contract FakeV1ERC20Test is Test {
    FakeV1ERC20 fakeV1ERC20;

    function setUp() external {
        fakeV1ERC20 = new FakeV1ERC20();
    }

    function testFakeV1TransferFromFunctionWorksWell() public {
        bool successTransferFrom = fakeV1ERC20.transferFrom(address(1), address(2), 1);
        assertEq(successTransferFrom, false);
    }

    function testFakeV1TransferFunctionWorksWell() public {
        bool successTransfer = fakeV1ERC20.transfer(address(1), 1);
        assertEq(successTransfer, false);
    }
}
