// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {FakeDSCV1} from "../mocks/FakeDSCV1.m.sol";

contract FakeDSCV1Test is Test {
    FakeDSCV1 fakeDscV1;

    function setUp() external {
        fakeDscV1 = new FakeDSCV1();
    }

    function testFakeDSCV1WorksWell() public {
        bool success = fakeDscV1.mint(address(1), 1);

        assertEq(success, false);
    }
}
