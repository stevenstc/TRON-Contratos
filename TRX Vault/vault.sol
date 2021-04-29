// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;
import './TRXVault_state.sol';

contract TRXVault is TRXVault_State{

	event Newbie(address user);
	event NewDeposit(address indexed user, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event RefBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount);
	event FeePayed(address indexed user, uint256 totalAmount);
	event Reinvestment(address indexed user, uint amount);

	constructor(address payable marketingAddr,
	    address payable projectAddr,
	    address payable devAddr) public {
		require(!isContract(marketingAddr) &&
		    !isContract(projectAddr) &&
		    !isContract(devAddr));

		marketingAddress = marketingAddr;
		projectAddress = projectAddr;
		devAddress = devAddr;
		paused = true;
		emit Paused(msg.sender);
	}

	modifier checkUser_ () {
	    uint check = block.timestamp.sub(users[msg.sender].checkpoint);
	    require(check > TIME_STEP,'try again later');
	    _;
	}

	function checkUser() external view returns (bool){
	    uint check = block.timestamp.sub(users[msg.sender].checkpoint);
	    if(check > TIME_STEP)
	    return true;
	}

	function invest(address referrer) external payable whenNotPaused{
		require(msg.value >= INVEST_MIN_AMOUNT);
		marketingAddress.transfer(msg.value.mul(MARKETING_FEE).div(PERCENTS_DIVIDER));
		projectAddress.transfer(msg.value.mul(PROJECT_FEE).div(PERCENTS_DIVIDER));
		devAddress.transfer(msg.value.mul(DEV_FEE).div(PERCENTS_DIVIDER));
		emit FeePayed(msg.sender, msg.value.mul(MARKETING_FEE.add(PROJECT_FEE).add(DEV_FEE)).div(PERCENTS_DIVIDER));
		User storage user = users[msg.sender];

		if (user.referrer == address(0) && users[referrer].deposits.length > 0 && referrer != msg.sender) {
			user.referrer = referrer;
		}

		if (user.referrer != address(0)) {
			address upline = user.referrer;
			for (uint256 i = 0; i < REFERRAL_PERCENTS.length; i++) {
				if (upline != address(0)) {
					uint256 amount = msg.value.mul(REFERRAL_PERCENTS[i]).div(PERCENTS_DIVIDER);
					users[upline].bonus = users[upline].bonus.add(amount);
					if(user.deposits.length == 0)
					users[upline].referrerCount[i]=users[upline].referrerCount[i].add(1);
					emit RefBonus(upline, msg.sender, i, amount);
					upline = users[upline].referrer;
				} else break;
			}
		}

		if (user.deposits.length == 0) {
			user.checkpoint = block.timestamp;
			totalUsers = totalUsers.add(1);
			emit Newbie(msg.sender);
		}

        Deposit memory newDeposit;
        newDeposit.amount = msg.value;
        newDeposit.initAmount = msg.value;
		newDeposit.start = block.timestamp;
		user.deposits.push(newDeposit);

		totalInvested = totalInvested.add(msg.value);
		totalDeposits = totalDeposits.add(1);
		emit NewDeposit(msg.sender, msg.value);
	}

	function withdraw() external whenNotPaused checkUser_  returns(bool) {
		require(isActive(msg.sender), "Dont is User");
		User storage user = users[msg.sender];
		uint256 userPercentRate = getUserPercentRate(msg.sender);
		uint256 totalAmount;
		uint256 dividends;
		uint256 currentReinvestment;

		for (uint256 i = 0; i < user.deposits.length; i++) {

			if (user.deposits[i].withdrawn < user.deposits[i].initAmount.mul(MAX_PROFIT)) {

				if (user.deposits[i].start > user.checkpoint) {
				    dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.deposits[i].start))
						.div(TIME_STEP);

				} else {

					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.checkpoint))
						.div(TIME_STEP);
				}

				if (user.deposits[i].withdrawn.add(dividends) > user.deposits[i].initAmount.mul(MAX_PROFIT)) {
					dividends = (user.deposits[i].initAmount.mul(MAX_PROFIT)).sub(user.deposits[i].withdrawn);
				}
				else{
		        // reinvestment start
		        uint reinvestment = dividends.mul( REINVESTMENT_PERCENTS ).div( PERCENTS_DIVIDER );
				// add reinvestment
		        user.deposits[i].amount = user.deposits[i].amount.add(reinvestment);
		        user.reinvested = user.reinvested.add(reinvestment);
				totalReinvested = totalReinvested.add(reinvestment);
				currentReinvestment = currentReinvestment.add(reinvestment);
		        dividends = dividends.sub(reinvestment);
				}
		        // reinvestment end
				user.deposits[i].withdrawn = user.deposits[i].withdrawn.add(dividends); /// changing of storage data
				totalAmount = totalAmount.add(dividends);
			}
		}

		//reinvestment fee
		if(currentReinvestment > 0 ){
		    uint fee = currentReinvestment.div(2);
		    marketingAddress.transfer(fee);
            devAddress.transfer(fee);
		    emit FeePayed(msg.sender, currentReinvestment);
		    emit Reinvestment(msg.sender, currentReinvestment);
		}

		uint256 referralBonus = user.bonus;
		if (referralBonus > 0) {
			totalAmount = totalAmount.add(referralBonus);
			user.bonus = 0;
		}

		require(totalAmount > 0, "User has no dividends");


		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount) {
			totalAmount = contractBalance;
		}

		user.checkpoint = block.timestamp;

		msg.sender.transfer(totalAmount);

		totalWithdrawn = totalWithdrawn.add(totalAmount);

		emit Withdrawn(msg.sender, totalAmount);
		return true;

	}

	function reinvestment() external whenNotPaused checkUser_ returns(bool) {
	    require(isActive(msg.sender), "Dont is User");
	    User storage user = users[msg.sender];
	    uint256 totalDividends;
		uint dividends;

		uint userPercentRate = getUserPercentRate(msg.sender);
	    for (uint i = 0; i < user.deposits.length; i++) {

			if (user.deposits[i].withdrawn < user.deposits[i].initAmount.mul(MAX_PROFIT)) {

				if (user.deposits[i].start > user.checkpoint) {

					dividends = user.deposits[i].amount
					    .mul( userPercentRate )
					    .div( PERCENTS_DIVIDER )
						.mul( block.timestamp.sub( user.deposits[i].start ) )
						.div( TIME_STEP );
				}
				else {
				    dividends = user.deposits[i].amount
				        .mul( userPercentRate )
				        .div( PERCENTS_DIVIDER )
						.mul( block.timestamp.sub(user.checkpoint) )
						.div( TIME_STEP );
				}

				if ( user.deposits[i].withdrawn.add(dividends) > user.deposits[i].initAmount.mul(MAX_PROFIT)) {
					dividends = user.deposits[i].initAmount
					    .mul(MAX_PROFIT)
					    .sub(user.deposits[i].withdrawn);
				}
		        user.deposits[i].amount = user.deposits[i].amount.add(dividends);
		        totalDividends = totalDividends.add(dividends);
			}
		}

		marketingAddress.transfer(totalDividends.mul(MARKETING_FEE).div(PERCENTS_DIVIDER));
		devAddress.transfer(totalDividends.mul(DEV_FEE).div(PERCENTS_DIVIDER));
		emit FeePayed(msg.sender, totalDividends.mul( MARKETING_FEE.add(DEV_FEE) ).div(PERCENTS_DIVIDER));
		user.reinvested = user.reinvested.add(totalDividends);
		totalReinvested = totalReinvested.add(totalDividends);
		user.checkpoint = block.timestamp;
		emit Reinvestment(msg.sender, totalDividends);
		return true;
	}

	function getNextUserAssignment(address userAddress) external view returns (uint) {
            uint check = users[userAddress].checkpoint.add(TIME_STEP);
            return check;
    }

	function getUserholdRate(address userAddress) public view returns (uint) {
    	User memory user = users[userAddress];
		if (isActive(userAddress)) {
				uint holdProfit =block.timestamp.sub(user.checkpoint).div(TIME_STEP).mul(HOLD_PERCENT);
				if( holdProfit > MAX_HOLD_PERCENT)
				   holdProfit = MAX_HOLD_PERCENT;
				return holdProfit;
		}
    }

    function getUserPercentRate(address userAddress) public view returns (uint) {
		uint holdProfit = getUserholdRate(userAddress);
		return BASE_PERCENT.add(holdProfit);
	}

	function getPublicData() external view returns(uint  totalUsers_,
	    uint  totalInvested_,
	    uint  totalReinvested_,
	    uint  totalWithdrawn_,
	    uint totalDeposits_,
	    uint balance_) {
	    totalUsers_ =totalUsers;
        totalInvested_ = totalInvested;
	    totalReinvested_ =totalReinvested;
	    totalWithdrawn_ = totalWithdrawn;
	    totalDeposits_ =totalDeposits;
	    balance_ = getContractBalance();
	}

	function getUserData(address userAddress) external view returns(uint totalWithdrawn_,
	    uint totalDeposits_,
	    uint totalBonus_,
	    uint totalreinvest_,
	    uint hold_,
	    uint balance_,
	    uint nextAssignment_,
	    uint amountOfDeposits,
	    uint checkpoint,
	    bool isUser_,
	    address referrer_,
	    uint[3] memory referrerCount_
	){
	    User memory user = users[userAddress];
	    totalWithdrawn_ =getUserTotalWithdrawn(userAddress);
	    totalDeposits_ =getUserTotalDeposits(userAddress);
	    nextAssignment_ = this.getNextUserAssignment(userAddress);
	    balance_ = getUserDividends(userAddress);
	    hold_ = getUserholdRate(userAddress);
	    totalreinvest_ = user.reinvested;
	    totalBonus_ = users[userAddress].bonus;
	    amountOfDeposits =user.deposits.length;
	    checkpoint = user.checkpoint;
	    isUser_ =  user.deposits.length>0;
	    referrer_ = user.referrer;
	    referrerCount_ =user.referrerCount;

	}

	function getContractBalance() public view returns (uint256) {
		return address(this).balance;
	}

	function getUserDividends(address userAddress) internal view returns (uint256) {
		User memory user = users[userAddress];
		uint256 userPercentRate = getUserPercentRate(userAddress);

		uint256 totalDividends;
		uint256 dividends;

		for (uint256 i = 0; i < user.deposits.length; i++) {

			if (user.deposits[i].withdrawn < user.deposits[i].initAmount.mul(MAX_PROFIT)) {

				if (user.deposits[i].start > user.checkpoint) {

					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.deposits[i].start))
						.div(TIME_STEP);

				} else {
					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.checkpoint))
						.div(TIME_STEP);
				}
				if (user.deposits[i].withdrawn.add(dividends) > user.deposits[i].initAmount.mul(MAX_PROFIT)) {
					dividends = user.deposits[i].initAmount
					    .mul(MAX_PROFIT)
					    .sub(user.deposits[i].withdrawn);
				}
				totalDividends = totalDividends.add(dividends);
			}

		}

		return totalDividends;
	}

	function isActive(address userAddress) public view returns (bool) {
		User memory user = users[userAddress];

		if (user.deposits.length > 0) {
			if (user.deposits[user.deposits.length-1].withdrawn < user.deposits[user.deposits.length-1].initAmount.mul(2)) {
				return true;
			}
		}
	}

	function getUserDepositInfo(address userAddress, uint256 index) external view returns(
	    uint256 initAmount_,
	    uint256 amount_,
	    uint256 withdrawn_,
	    uint256 timeStart_,
	    uint256 reinvested_
	   ) {
	    User memory user = users[userAddress];
        initAmount_ =user.deposits[index].initAmount;
		amount_ = user.deposits[index].amount;
		withdrawn_ = user.deposits[index].withdrawn;
		timeStart_= user.deposits[index].start;
		reinvested_ = user.reinvested;
	}


	function getUserTotalDeposits(address userAddress) internal view returns(uint256) {
	    User memory user = users[userAddress];
		uint256 amount;
		for (uint256 i = 0; i < user.deposits.length; i++) {
			amount = amount.add(user.deposits[i].amount);
		}
		return amount;
	}

	function getUserTotalWithdrawn(address userAddress) internal view returns(uint256) {
	    User memory user = users[userAddress];

		uint256 amount;

		for (uint256 i = 0; i < user.deposits.length; i++) {
			amount = amount.add(user.deposits[i].withdrawn);
		}
		return amount;
	}

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}
