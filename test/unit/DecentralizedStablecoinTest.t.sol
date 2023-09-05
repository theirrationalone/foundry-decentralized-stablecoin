// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";

contract DecentralizedStablecoinTest is Test {
    DecentralizedStablecoin decentralizedStablecoin;

    ERC20Mock mockERC = new ERC20Mock("TEMPORARY TOKEN", "TMP_TK", address(1), 1000e8);

    address USER = makeAddr("user");

    function setUp() external {
        decentralizedStablecoin = new DecentralizedStablecoin();
        decentralizedStablecoin.transferOwnership(address(mockERC));
    }

    function testStableCoinNameAndSymbolAreAsSameAsGiven() public {
        string memory expectedStablecoinName = "Decentralized Stablecoin";
        string memory expectedStablecoinSymbol = "DSC";

        string memory actualStablecoinName = decentralizedStablecoin.name();
        string memory actualStablecoinSymbol = decentralizedStablecoin.symbol();

        assertEq(keccak256(abi.encodePacked(actualStablecoinName)), keccak256(abi.encodePacked(expectedStablecoinName)));
        assertEq(
            keccak256(abi.encodePacked(actualStablecoinSymbol)), keccak256(abi.encodePacked(expectedStablecoinSymbol))
        );
    }

    function testInitialBalanceOfAnyHolderMustBeZero(address _holder) public {
        uint256 expectedDSCBalance = 0;
        uint256 actualDSCBalance = decentralizedStablecoin.balanceOf(_holder);

        assertEq(actualDSCBalance, expectedDSCBalance);
    }

    function testInitialSupplyIsZeroBecauseIntiallyNoTokensExist() public {
        uint256 expectedInitialTokensSupply = 0;
        uint256 actualInitialTokensSupply = decentralizedStablecoin.totalSupply();

        assertEq(actualInitialTokensSupply, expectedInitialTokensSupply);
    }

    function testApprovesSpendersAllowanceOverCallersTokensCorrectly() public {
        // this means `USER` has `dummyToken` balance of `1000e8`.
        ERC20Mock dummyToken = new ERC20Mock("DUMMY_TOKEN", "DMYTK", USER, 1000e8);

        // Owner(USER) is performing tx.
        // owner(USER) gives approval to `mockERC`(spender) to spend tokens balance on his/her/its behalf.
        // if spencder tries to spend more token than error will occur and tell `spend amount exceeds balance`.abi
        vm.startPrank(USER);
        dummyToken.approve(address(mockERC), 1000e8);
        vm.stopPrank();
        // dummyToken.allowance(USER, address(mockERC));

        uint256 startingSpenderBalance = dummyToken.balanceOf(address(mockERC));
        // only approved spender can spend balance of owner.
        // `mockERC` is the spender
        // now spender recharging his/her/its account:
        // akin -> owner_account_balance -> to -> spender_account_balance --> Spender is Pulling.
        vm.startPrank(address(mockERC));
        dummyToken.transferFrom(USER, address(mockERC), 1000e8);
        vm.stopPrank();

        uint256 endingSpenderBalance = dummyToken.balanceOf(address(mockERC));

        assertEq(startingSpenderBalance, 0);
        assertLe(startingSpenderBalance, endingSpenderBalance);
        assert(endingSpenderBalance > startingSpenderBalance);
        assertEq(endingSpenderBalance, 1000e8);
    }

    function testDSCApprovesSpenderAllowanceOverCallerTokenCorrectly() public {
        uint256 startingBalance = decentralizedStablecoin.balanceOf(address(mockERC));

        vm.startPrank(decentralizedStablecoin.owner());
        decentralizedStablecoin.mint(address(mockERC), 1 ether);

        uint256 endingBalance = decentralizedStablecoin.balanceOf(address(mockERC));

        assertEq(startingBalance, 0);
        assertEq(endingBalance, 1 ether);

        vm.startPrank(decentralizedStablecoin.owner());
        decentralizedStablecoin.approve(USER, 1 ether);
        vm.stopPrank();

        uint256 startingSpenderBalance = decentralizedStablecoin.balanceOf(USER);

        vm.startPrank(USER);
        decentralizedStablecoin.transferFrom(decentralizedStablecoin.owner(), USER, 1 ether);
        vm.stopPrank();

        uint256 endingSpenderBalance = decentralizedStablecoin.balanceOf(USER);

        assertEq(startingSpenderBalance, 0);
        assertLe(startingSpenderBalance, endingSpenderBalance);
        assert(endingSpenderBalance > startingSpenderBalance);
        assertEq(endingSpenderBalance, 1 ether);
    }
}
