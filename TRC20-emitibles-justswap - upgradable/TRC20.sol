pragma solidity >=0.7.0;
// SPDX-License-Identifier: Apache-2.0

import "./SafeMath.sol";
import "./BlackList.sol";

contract TRC20 is BlackList {
    using SafeMath for uint256;

    address anterior;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    event Issue(uint256 value);

    event Redeem(uint256 value);

    event DestroyedBlackFunds(address indexed _blackListedUser, uint _balance);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function issue(uint amount) public onlyOwner {
        _mint(msg.sender, amount);
        emit Issue(amount);
        emit Transfer(address(0), owner, amount);
    }
        
    function redeem(uint amount) public onlyOwner {
        _burn(msg.sender, amount);
        emit Redeem(amount);
        emit Transfer(owner, address(0), amount);
    }

    function destroyBlackFunds (address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser]);
        uint dirtyFunds = balanceOf(_blackListedUser);
        _burnFrom(_blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(!isBlackListed[sender]&&!isBlackListed[recipient]);
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }

    function setAnteriorContrato(address _old_contract) public {
        anterior = _old_contract;

    }
    
    function transferByLegacy(address from, address to, uint value) external returns (bool){
        _transfer(from, to, value);
        return true;
    }
    function transferFromByLegacy(address sender, address from, address spender, uint value) public returns (bool){
        _transfer(from, spender, value);
        _approve(from, sender, _allowances[from][sender].sub(value));
        return true;
    }
    function approveByLegacy(address from, address spender, uint value) public returns (bool){
        _approve(from, spender, value);
        return true;
    }
    function increaseApprovalByLegacy(address from, address spender, uint addedValue) public returns (bool){
        _approve(from, spender, _allowances[from][spender].add(addedValue));
        return true;
    }
    function decreaseApprovalByLegacy(address from, address spender, uint subtractedValue) public returns (bool){
        _approve(from, spender, _allowances[from][spender].sub(subtractedValue));
        return true;
    }
}