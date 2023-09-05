// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStablecoin is ERC20Burnable, Ownable {
    error DecentralizedStablecoin__AddressCannotBeZero();
    error DecentralizedStablecoin__AmountMustBeMoreThanZero();
    error DecentralizedStablecoin__BurnAmountExceedBalance(uint256 balance);

    constructor() ERC20("Decentralized Stablecoin", "DSC") {}

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStablecoin__AddressCannotBeZero();
        }

        if (_amount <= 0) {
            revert DecentralizedStablecoin__AmountMustBeMoreThanZero();
        }

        _mint(_to, _amount);

        return true;
    }

    function burn(uint256 _amountToBurn) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amountToBurn <= 0) {
            revert DecentralizedStablecoin__AmountMustBeMoreThanZero();
        }

        if (balance < _amountToBurn) {
            revert DecentralizedStablecoin__BurnAmountExceedBalance(balance);
        }

        super.burn(_amountToBurn);
    }
}
