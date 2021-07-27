pragma solidity >=0.7.0;
// SPDX-License-Identifier: Apache-2.0

import "./TRC20.sol";

contract TRC20Detailed is TRC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor (string memory _name, string memory _symbol, uint8 _decimals, uint initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _mint(msg.sender, initialSupply * 10 ** uint256(decimals));
    }

}
