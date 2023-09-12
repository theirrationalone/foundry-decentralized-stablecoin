// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {FakeDSCV2} from "../mocks/FakeDSCV2.m.sol";

contract FakeDSCV2Test is Test {
    FakeDSCV2 fakeDscV2;

    function setUp() external {
        fakeDscV2 = new FakeDSCV2();
    }

    function testFakeDSCV2MintFunctionIsWorkingWell() public {
        bool successMint = fakeDscV2.mint(address(1), 1);
        assertEq(successMint, true);
    }

    function testFakeDSCV2TransferFromFunctionIsWorkingWell() public {
        bool successTransferFrom = fakeDscV2.transferFrom(address(1), address(2), 1);
        assertEq(successTransferFrom, false);
    }
}
