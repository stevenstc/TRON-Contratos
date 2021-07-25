pragma solidity >=0.5.15;

import "./TRC20.sol";

contract TRC20Detailed is TRC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals, uint initialSupply) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _mint(msg.sender, initialSupply * 10 ** uint256(decimals));
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}
