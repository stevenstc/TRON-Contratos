// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;
import "./SafeMath.sol";

contract TRXVault_State{
    using SafeMath for uint256;

    uint256[3]  internal REFERRAL_PERCENTS = [50, 20, 10];
	uint256 constant internal INVEST_MIN_AMOUNT = 50 trx;
	uint256 constant internal BASE_PERCENT = 70;
	uint256 constant internal MARKETING_FEE = 45;
	uint256 constant internal DEV_FEE = 45;
	uint256 constant internal REINVESTMENT_PERCENTS = 90;
	uint256 constant internal PROJECT_FEE = 30;
	uint256 constant internal PERCENTS_DIVIDER = 1000;
	uint256 constant internal MAX_HOLD_PERCENT = 30;
    uint256 constant internal HOLD_PERCENT = 10;
    uint256 constant internal MAX_PROFIT = 2;
    uint256 constant internal TIME_STEP = 1 days;

	uint256 public totalUsers;
	uint256 public totalInvested;
	uint256 public totalWithdrawn;
	uint256 public totalDeposits;
	uint256 public totalReinvested;

	address payable public marketingAddress;
	address payable public projectAddress;
	address payable public devAddress;

	bool public paused;

	struct Deposit {
		uint256 amount;
		uint256 withdrawn;
		uint256 initAmount;
		uint256 start;
	}

	struct User {
		Deposit[] deposits;
		uint256 reinvested;
		uint256 checkpoint;
		address referrer;
		uint256 bonus;
		uint256[3] referrerCount;
	}

	mapping (address => User) public users;

	event Paused(address account);
	event Unpaused(address account);

	modifier onlyOwner() {
        require(devAddress == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    function unpause() external whenPaused onlyOwner{
        paused = false;
        emit Unpaused(msg.sender);
    }

}
