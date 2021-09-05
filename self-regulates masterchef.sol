// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/*

Basically this is supposed to be a smart contract that self-regulates masterchef
Inflation is pre-determined with this contract...
It can also be modified "on-chain" by "voting"


1.)WE START AT reward of 25/block
2.) After 22september anyone can call a function that increases rewards(updates masterchef rewards) to 100
called "rapid adoption boost/phase"
3.) Then there are events which anyone can call, on each function call, the reward per block reduces by Golden Ratio(updates to masterchef)
	Function can be called:
	First every 4 hours (x18)
	Then every 6hours (12x)
	Then every 8hours (9x)
	Then every 12hours (7x)
	Then set inflation back to 25/block
	
	Basically what it does is it gives an initial boost to 100/block and reduces it each time period towards 25
	
4.) on 23rd of November, print like 23.6% of whole supply in 48hours ("big fibonaci payout")
Need to calculate average block time for this.

5.) reduce inflation to 25/block and from there on we are going down per golden ratio on each one
6.) Start "automatic governance"
7.) 3 functions
Initiate and Veto should require an amount of tokens to be "deposited" as a cost for calling the contract and those funds should be burned
//either burned, or just kept by the contract is okay too i guess

Initiate: proposal is pushed into array
Veto: proposal can be voted against(negated)
Execute; if it's not voted against in a period of time, it can be enforced

8.) there are also 3 functions that regulate the rewards for XVMC-USDC, XVMC-WMATIC and DOGE2 pool(poolID 0,1 and 11)
max for doge2 is 5%, and 4% for pool 0 and 1 collectively
has to also be proposed... for each.

8.)  When block reward goes to roughly 1.6(it will have to reduce like 15-16times by 1.6 each time from 25 to 1.618),
 "The grand fibonaccenning" happens, where supply inflates up to a 1,000,000X
in that time period (creates a total supply of a quadrillion 1,000,000,000,000,000) and sets the
 inflation to a golden ratio(in % on annual basis)So basically 1.618% annual inflation.

I think the best way would be to just do a basic exponent function. Basically multiply supply by 1.618X on each event and you 
need around 25-30 events. The inflation boost should happen in a period of 7-14 days.
There should be long breaks, and then BIG inflation, rapidly, and then break again(you don't want constant rewards over that period
because if people bought, they would get diluted badly on inflation very quickly).
During those 7-14days, set rewards to 0 for 12hours, then print for 30minutes(until supplies goes x1.618), rest 12hours, repeat,
or something similar...

9.) DO WE NEED TO CREATE PAUSABLE FUNCTION(in autocompounding pool - prevent autocompounding during that period?) 
when grand fibonaccening and second is how does 130% work over the long term compounded ??

*/




//how will auto-compounding effect during "Grand Fibonaccening" if one pool receives 1,3x, how does this
// play out during those events where massive amount is printed?
//do we need to add stop auto-compounding durnig those events?


// i don't know solidity, this is just a concept... for the explanation above


  /// @notice Owner address
address  owner;

int immutable goldenRatio = 1.6180339887 * 1e18; //The golden ratio, the sacred number, do we need e18 or no? WHEN??
int EVMnumberFormat = 1e18;
address immutable ourERCtokenAddress = "0x....."; //our ERC20 token contract address
address immutable deadAddress = "0x000000000000000000000000000000000000dead"; //dead address

int immutable minimum = 1000; //unchangeable, forever min 1000

//can be changed, but not less than minimum. This is the tokens that must be sacrificed in order to "vote"
//voting should be affordable, but a minimum is required to prevent spam
int costToVote = 1000; 

//proposals to change costToVote, stored in 2-dimensiona array
proposalMinDeposit[id][[boolean], [firstCallTimestamp], [valueSacrificedForVote], [value]]; 

//should we set immutable delaybefore enforce like 1day? gives minimum 1 day before proposals can be activated?? HMH idk!
int delayBeforeEnforce = 44000; //minimum number of blocks between when costToVote is proposed and executed


struct proposeDelayBeforeEnforce {
    bool valid;
    int firstCallTimestamp;
    int proposedValue;
}
proposeDelayBeforeEnforcel[] public delayProposals;


boolean gracePeriodActivation = false; //if grace period has been requested
int timestampGracePeriod; //timestamp of grace period

int immutable minThresholdFibonaccening = 1000000;
int thresholdFibonnacening = 5000000; 

struct proposalThresholdFibonnacening {
    bool valid;
    int proposedValue;
    int proposedDuration;
    int firstCallTimestamp;
    
}
proposalThresholdFibonnacening[] public proposalThresholdFibonnaceningList; //i don't know syntax for this, is it right?



//delays for Fibonnaccenning Events
int immutable minDelay = 1days; // has to be called minimum 1 day in advance
int immutable maxDelay = 31 days; //1month.. is that good? i think yes
int currentDelay = 3days;

//remember the reward prior to updating so it can be reverted
int rewardPerBlockPriorFibonaccening;
bool eventFibonacceningActive = false; // prevent some functions if event is active ..threshold and durations for fibonaccening

bool expiredGrandFibonaccenning = false;

//fibonacci proposals. When enough penalties are collected, inflation is reduced by golden ratio.
struct fibonaccenningProposal {
    bool valid;
    int firstCallTimestamp;
    int valueSacrificedForVote;
    int multiplier;
    int currentDelay;
    int duration;
}
fibonaccenningProposal[] public fibonaccenningProposalList;


bool handsOff = false; 
//by default paused/handsoff is turned on. The inflation should run according to schedule, until after the Big Fibonnaci day
//functions and voting is turned on during that period, immutable

int preProgrammedCounter = 46; //we reduce inflation by golden ratio 35 time
int preProgrammedCounterTimestamp = 0;

bool rapidAdoptionBoost = false; //can only be called once, after 22 september

bool bigFibonaciActivated = false;
bool bigFibonaciStopped = false;

int blocksPerSecond = 2.5;
int durationForCalculation= 12hours; //make this changeable(voteable) BUT NOT WEN COUNTING BLOCKS active!
int lastBlockHeight = 0;
int recordTimeStart;
bool countingBlocks = false;



struct proposalDurationForCalculation {
    bool valid;
    int duration;
    int tokensSacrificedForVoting;
    int firstCallTimestamp;
}
proposalDurationForCalculation[] public proposeDurationCalculation;


//need this or not IDK?
int circulatingSupply;
int maximumVoteTokens;


//in case block times change over the long run, this function can be used to rebalance
//only start counting them
int totalFibonaciEventsAfterGrand = 0; 

struct proposalRebalanceInflation {
    bool valid; //if it remains true, it can be called
    int tokensSacrificedForVoting;
    int firstCallTimestamp;
}
proposalRebalanceInflation[] public rebalanceProposals;

function initiateRebalanceProposal(int depositingTokensn) { 
	if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
	if(depositingTokens < costToVote) {"there is a minimum cost to vote"}

	transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
	rebalanceProposals.push("true", depositingTokens, firstCallTimestamp);  //submit new proposal
}
	//reject if proposal is invalid(false), and if the required delay since last call and first call have not been met
function executeRebalanceProposal(int proposalID) {
	if(rebalanceProposals[proposalID][0] == false || proposeDurationCalculation[proposalID][2] < (block.timestamp + delayBeforeEnforce)) { reject }
    rebalanceInflation(proposalID);
	rebalanceProposals[proposalID][0] = false;
}
function vetoRebalanceProposal(int proposalID, int depositingTokens) {
	if (rebalanceProposals[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != rebalanceProposals[proposalID][1]) { reject "must match amount to veto"; }
	
	rebalanceProposals[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}

//there should be valid proposalID to do so tbh
//this rebalances inflation to Golden ratio(and number of fibonacennings afterward)
function rebalanceInflation(int proposalID) {
    if(totalFibonaciEventsAfterGrand == 0) {  reject "only works after grand fibonaccening" }
    if(!rebalanceProposals[proposalID][0]) { reject "proposal is invalid" }
    //rebalance inflation to
    setInflation(getTotalSupply() * (((100 - goldenRatio)/100)exponent totalFibonaciEventsAfterGrand));
}

//can't use more than 0.1% of circulating supply to vote, making sure to prevent tyranny and always potentially veto
//US presidentials cost approximately 0.0133% of total US worth. This is crypto so let's give little more space
//in all proposals you can't deposit more than this amount of tokens
function updateMaximumVoteTokens {
    maximumVoteTokens = getTotalSupply() * 0.0005;
}

function updateCirculatingSupply(){
    circulatingSupply = getTotalSupply();
}

//after counting is done, updated into database the numberino
function calculateAverageBlockTime() {
    if(countingBlocks && (recordTimeStart + durationForCalculation) >= block.timestamp) {
        blocksPerSecond = (block.height - lastBlockHeight) / durationForCalculation(must be in seconds); //gets number of blocks per second
        countingBlocks = false;
    }
}

//can be called by anybody because it doesn't have any real impact
function startCountingBlocks(){
    require(!countingBlocks) { "already counting blocks" }
    countingBlocks = true;
    lastBlockHeight = block.height; //remember block number height
    recordTimeStart = block.time; //remember time
} 

//shit doesn't really matter cuz after big fibonnaci daz we go down to  25-golden ratio, so need not to remember until then
function rapidAdoptionBoost() public {
    if(rapidAdoptionBoost) { reject "already been activated"; }
    if(block.timestamp < 22.september) { reject "rapidAdoptionBoost can only be activated after this period" }
    rapidAdoptionBoost = true;
}

function updatePreProgrammedRewards() public anyone1 can call {
    if(!rapidAdoptionBoost) { reject "programIsOff"; } //not sure which one is the right one now
    if(preProgrammedCounter == 46) {
        setInflation(100 * EVMnumberFormat);
        preProgrammedCounter--; //deduct by 1
        preProgrammedCounterTimestamp = time.block;
    }
    if(lastPreProgrammedCounter < 46 && lastPreProgrammedCounter > 27) {
        if(preProgrammedCounterTimestamp + 5760 < block.timestamp) { reject "delay not met, must wait 4hrs"; }
        rewardPerBlockPriorFibonaccening -= goldenRatio;
        setInflation(rewardPerBlockPriorFibonaccening);
        preProgrammedCounter--; //deduct by 1
        preProgrammedCounterTimestamp = time.block;
    }
    if(lastPreProgrammedCounter < 28 && lastPreProgrammedCounter > 14) {
        if(preProgrammedCounterTimestamp + 8640 < block.timestamp) { reject "delay not met, must wait 6hrs"; }
        rewardPerBlockPriorFibonaccening -= goldenRatio;
        setInflation(rewardPerBlockPriorFibonaccening);
        preProgrammedCounter--; //deduct by 1
        preProgrammedCounterTimestamp = time.block;
    }
    if(lastPreProgrammedCounter < 15 && lastPreProgrammedCounter > 4) {
        if(preProgrammedCounterTimestamp + 11520 < block.timestamp) { reject "delay not met, must wait 8hrs"; }
        rewardPerBlockPriorFibonaccening -= goldenRatio;
        setInflation(rewardPerBlockPriorFibonaccening);
        preProgrammedCounter--; //deduct by 1
        preProgrammedCounterTimestamp = time.block;
    }
    if(lastPreProgrammedCounter < 5 && lastPreProgrammedCounter > 1) {
        if(preProgrammedCounterTimestamp + 8640 < block.timestamp) { reject "delay not met, must wait 12hrs"; }
        rewardPerBlockPriorFibonaccening -= goldenRatio;
        setInflation(rewardPerBlockPriorFibonaccening);
        preProgrammedCounter--; //deduct by 1
        preProgrammedCounterTimestamp = time.block;
    }
    if(lastPreProgrammedCounter == 1) {
        if(preProgrammedCounterTimestamp + 17280 < block.timestamp) { reject "delay not met, must wait 1day"; }
        rewardPerBlockPriorFibonaccening -= goldenRatio;
        setInflation(25000000000000000000); // set to 25XVMC/block
        preProgrammedCounter--; //deduct by 1
        preProgrammedCounterTimestamp = time.block;

        //inflation goes to 25XVMC block, rapidadoption boost can't be activated ever again and the counter can't go above 0 again either
    }
}

//Big fibonnaci day, 23.8% of supply printed in a period of 48hours, then revert to 25XVMC/block and on-chain governance
//anyone can call this
function bigFibonaciPayout() {
    //function can be called 12hours prior to the day UTC, and expires 12hours after, total 48hours duration
    if(!bigFibonaciActivated && block.timestamp >(12hourspprior23november)) { //activate big fibonaci day
        bigFibonaciActivated = true;
        //calculate rewards, need a function that gets blocks
        setInflation((getTotalSupply()*0.236) / (48 * 3600 / blocksPerSecond)); 
        // 23.6% of total supply must be printed in 48hours,s o reward per second should be totalsupply*0.236 / 48hoursinseconds
        //halt other functions as to not mess up? IDK!!
    }

}

bool endBigFibonaciDay = false;

function endBigFibonaciPayout() {
    require(bigFibonaciActivated && !endBigFibonaciDay) { "can't activated if not ongoing" })
    require(block.timestamp > 12hoursafter23november) { "must last 24hours" }
    //must be active and must expire and must not be callable again function
    setInflation(25000000000000000000); // set to 25tokens/block
    rewardPerBlockPriorFibonaccening = 25000000000000000000;
    endBigFibonaciDay = true;
}


struct proposalFarm {
    bool valid;
    int poolid;
    int newAllocation;
    int tokensSacrificedForVoting;
    int firstCallTimestamp;
}
proposalFarm[] public proposalFarmUpdate;

function initiateFarmProposal(int depositingTokens, int poolid, int newAllocation[]) { 
	if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
	if(depositingTokens < costToVote) {"there is a minimum cost to vote"}
	if(poolid !(in_array([0,1,11]))) { "reject, only allowed for these pools" }
	if(poolid == 11 && newAllocation > 5000) { reject "max 5k" }
	
	//you can propose any amount but it will not get accepted by updateFarms anyways

	transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
	proposalFarmUpdate.push("true", poolid, newAllocation, depositingTokens, firstCallTimestamp);  //submit new proposal
}

function vetoFarmProposal(int proposalID, int depositingTokens) {
	if (proposalMinDeposit[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != proposalFarmUpdate[proposalID][3]) { reject "must match amount to veto"; }
	
	proposalFarmUpdate[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}

//updateFarms actually acts akin to the execute Proposal in this case

//this is to update farm and pool allocations,which can be proposed
int allocationPool1 = XX; //SET THIS AT BEGINNING
int allocationPool2 = XX;
int immutable maxFarmRewards = 1000; //idk the actual number, set this shit broski..but this is not locked so welp fuck

function updateFarm0(int proposalID, int massUpdate) {
    if(proposalFarmUpdate[proposalID][0] = "false"( { reject "not valid proposal"})
    if(proposalFarmUpdate[proposalID][3] + delayBeforeEnforce > block.timestamp) {reject " not valid yet"}
        if(allocationPool2 + proposalFarmUpdate[proposalID][2] > maxFarmRewards) { reject "exceeding max" }
    updatePool(0, newAllocationPool1, massUpdate);;
}
function updateFarm1(int proposalID, int massUpdate) {
    if(proposalFarmUpdate[proposalID][0] = "false"( { reject "not valid proposal"})
    if(proposalFarmUpdate[proposalID][3] + delayBeforeEnforce > block.timestamp) {reject " not valid yet"}
    if(allocationPool1 + proposalFarmUpdate[proposalID][2] > maxFarmRewards) { reject "exceeding max" }
    updatePool(1, newAllocationPool2, massUpdate);
}

//poolid preset to 11
function updateFarm11(int massUpdate, int proposalID) {
    if(proposalFarmUpdate[proposalID][0] = "false"( { rject "not valid proposal"})
    if(proposalFarmUpdate[proposalID][3] + delayBeforeEnforce > block.timestamp) {reject " not valid yet"}
   //need proposal
    updatePool(11, newAllocation, massUpdate);
}



function initiateDelayProposal(int depositingTokens, int duration) { 
	if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
	if(depositingTokens < costToVote) {"there is a minimum cost to vote"}

	transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
	proposeDurationCalculation.push("true", duration, depositingTokens, firstCallTimestamp);  //submit new proposal
}
	//reject if proposal is invalid(false), and if the required delay since last call and first call have not been met
function executeDelayProposal(int proposalID) {
	if(proposeDurationCalculation[proposalID][0] == false || proposeDurationCalculation[proposalID][3] < (block.timestamp + delayBeforeEnforce)) { reject }
    durationForCalculation = proposeDurationCalculation[proposalID][1]; // enforce new rule
	proposeDurationCalculation[proposalID][0] = false; //expire the proposal, can't call it again.. no way to make it true again, however it can be resubmitted(and vettod too)
}
function vetoDelayProposal(int proposalID, int depositingTokens) {
	if (proposalMinDeposit[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != proposeDurationCalculation[proposalID][2]) { reject "must match amount to veto"; }
	
	proposeDurationCalculation[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}


function initiateProposalDurationForCalculation(int depositingTokens, int duration) { 
	if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
	if(depositingTokens < costToVote) {"there is a minimum cost to vote"}

	transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
	proposeDurationCalculation.push("true", duration, depositingTokens, firstCallTimestamp);  //submit new proposal
}
	//reject if proposal is invalid(false), and if the required delay since last call and first call have not been met
function executeProposalDurationForCalculation(int proposalID) {
	if(proposeDurationCalculation[proposalID][0] == false || proposeDurationCalculation[proposalID][3] < (block.timestamp + delayBeforeEnforce)) { reject }
    durationForCalculation = proposeDurationCalculation[proposalID][1]; // enforce new rule
	proposeDurationCalculation[proposalID][0] = false; //expire the proposal, can't call it again.. no way to make it true again, however it can be resubmitted(and vettod too)
}
function vetoProposalDurationForCalculation(int proposalID, int depositingTokens) {
	if (proposalMinDeposit[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != proposeDurationCalculation[proposalID][2]) { reject "must match amount to veto"; }
	
	proposeDurationCalculation[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}



//fibonaccenning function determines by how much the reward per block is reduced
//prior to the "grand fibonaccenning" event, the reward per block is deducted by the golden ratio
//on the big event, reward per block is set to the golden ratio (totalsupply * 0.01618) AKA 1.6180%/ANNUALLY
//after the big event, reward per block is reduced by a golden number in percentage = (previous * ((100-1.6180)/100))
function calculateFibonaccenningNewRewardPerBlock() {
    if(expiredGrandFibonaccenning == false) {
        return rewardPerBlockPriorFibonaccening - goldenRatio; //reduce reward by golden ratio(subtract)
    } else {
        return rewardPerBlockPriorFibonaccening * ((100 * EVMnumberFormat - goldenRatio)/100 * EVMnumberFormat); //reduce by a goldenth ratio of a percenth (multiply by) ....
    }
}

//gets total(circulating) supply for XVMC token(deducting from dead address and thhis smart contract that holds penalties)
function getTotalSupply() {
    return IERC20(ourERCtokenAddress).totalSupply() - ERC20(ourERCtokenAddress).balanceOf(this) - ERC20(ourERCtokenAddress).balanceOf(deadAddress);
}

//TO-DO PREVENT CALLING OF MOST FUNCTIONS WHEN GRAND FIBONNACENING IS ACTIVE!!! (freeze funciton..perhaps should be during several things)
function InitiateSetMinDeposit(int depositingTokens, int number) { 
	if(number < minimum) { reject "immutable minimum 1000tokens" }
	if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
	
	if (number < costToVote) {
		if (depositingTokens != costToVote) { reject "costs to vote" }
		transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
		proposalMinDeposit.push("true", block.timestamp, depositingTokens, number);  //submit new proposal
	} else {
		if (depositingTokens != number) { reject "must deposit as many tokens as new minimum will be" }
		transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
		proposalMinDeposit.push("true", block.timestamp, 0, number); //submit new proposal
	}
}

	//reject if proposal is invalid(false), and if the required delay since last call and first call have not been met
function executeSetMinDeposit(int proposalID) {
	if(proposalMinDeposit[proposalID][0] == false || proposalMinDeposit[proposalID][1] < (block.timestamp + delayBeforeEnforce) || proposalMinDeposit[proposalID][2] < (block.timestamp + delayBeforeLastCall)) { reject }
	costToVote = proposalMinDeposit[proposalID][3]; //update the costToVote according to proposed value
	proposalMinDeposit[proposalID][0] = false; //expire the proposal, can't call it again.. no way to make it true again, however it can be resubmitted(and vettod too)
}

function vetoSetMinDeposit(int proposalID, int depositingTokens) {
	if (proposalMinDeposit[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != proposalMinDeposit[proposalID][2]) { reject "must match amount to veto"; }
	
	proposalMinDeposit[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}



function getCurrentInflation() {
	return get value From Another Contract("XVMCPerBlock", contractAddress) // get value for reward per block from masterchef contract
}

//this can only be called by this smart contract(the rebalancePools function)
function updatePool(int poolID, int allocation, bool massUpdate) {
	//call the set contract in masterchef
	if(poolID != in_array(1,2,3,4,5)) { reject "only can update pre-set poolIDs" } //can only modify pools with certain ID
	//if only contract can call then it doesn't really matter, can call them all
	
	{outsidecontractCall-Masterchef} set(poolID, allocation, 0, massUpdate); //set parameters - call function set in Masterchef
}


//can be called anybody, calls maddupdatepools funciton in masterchef
function massUpdatePools() {
	{outsidecontractCall-Masterchef} massUpdatePools(); //call massUpdatePools in masterchef
}

//autocompounding pool addresses...
address public pool1 = "0x...";
address public pool2 = "";
address public pool3 = "";
address public pool4 = "";
address public pool5 = "";
address public pool6 = "";


//called by this smart contract only
function calculateShare(int total, int poolshare, int multiplier) {
	return ((total /poolshare) * multiplier); //calculate 
}

//can be called by anybody, basically re-calculate all the amounts in pools and update pool shares into masterchef
function rebalancePools() {
	//get balance for each pool
	int balancePool1 = IERC20(pool1).totalSupply();
	int balancePool2 = IERC20(pool2).totalSupply();
	int balancePool3 = IERC20(pool3).totalSupply();
	int balancePool4 = IERC20(pool4).totalSupply();
	int balancePool5 = IERC20(pool5).totalSupply();
	int balancePool6 = IERC20(pool6).totalSupply();
	int total = balancePool1 + balancePool2 + balancePool3 + balancePool4 + balancePool5 + balancePool6;
	
	//have to change first value(replace 0 with pool ID)...find pool ids in masterchef once you deploy autocompounding pools
	//call update function that calls the masterchef and updates values
	updatePool(0, calculateShare(total, balancePool1, 10), 0);
	updatePool(0, calculateShare(total, balancePool2, 30), 0);
	updatePool(0, calculateShare(total, balancePool3, 45), 0);
	updatePool(0, calculateShare(total, balancePool4, 100), 0);
	updatePool(0, calculateShare(total, balancePool5, 115), 0);
	updatePool(0, calculateShare(total, balancePool6, 130), 1); //mass update pools on the last one? i think
}

//can only be called by the contract itself IMPORTANT.. only functions of hte smart contract can call this!!
function setInflation(int rewardPerBlock) {

    {outsidecontractCall-Masterchef} updateEmissionRate(rewardPerBlock);
    //do we need to remember previous reward? IDK!
    //add here if needed (not needed??)
    rewardPerBlockPriorFibonaccening = rewardPerBlock; //remember new reward as current ?? IDK
}



//call proposal for minimum amount collected for fibonacenning event
//can be called by anbody
function proposeSetMinThresholdFibonaccenning(int depositingTokens, int newMinimum) {
    if(newMinimum < minThresholdFibonaccening) { rejecc "cant go lower than 0.1"}
    if(depositingTokens < costToVote) { reject "minimum threshold to vote not met";}
    if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
    
    transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
	proposalThresholdFibonnacening.push("true", block.timestamp, newMinimum);  //submit new proposal
}

function vetoSetMinThresholdFibonaccenning(int proposalID, int depositingTokens) {
	if (proposalThresholdFibonnacening[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != costToVote) { reject "it costs to vote"; }
	
	proposalThresholdFibonnacening[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}

//enforce function
function executeSetMinThresholdFibonaccenning(int proposalID) {
	if(proposalThresholdFibonnacening[proposalID][0] == false || proposalThresholdFibonnacening[proposalID][1] < (block.timestamp + delayBeforeEnforce)) { reject }
	thresholdFibonnacening = proposalThresholdFibonnacening[proposalID][2]; //update the threshold to the proposed value
	proposalThresholdFibonnacening[proposalID][0] = false; //expire the proposal - prevent it from being called again
}


//should this be vettoable? IDK
//do we even need this... i don't think so because it is included in the fibonacci proposal itself..i think this function below is useless
function setDelay (int depositing tokens, int delay) {
 if(delay > maxDelay || delay < minDelay) { reject "not allowed" }   
 if(depositingTokens != costToVote) { reject "it costs to vote"; }
 
 currentDelay = delay; //make sure as not to confuse days, hours, blocks,... idk how
 transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}


//basically this is a "compensation" for re-distributing the penalties
//period of boosted inflation, and after it ends, global inflation reduces
function proposeFibonaccenning(int depositingTokens, int multiplier, int delay, int duration) {
    if(depositingTokens != costToVote || ) { reject "costs to submit decisions" }
    if(ERC20(putiheretokenaddress).balanceOf(this) < thresholdFibonnacening) { reject "need to collect penalties before calling"; }
    if(delay != currentDelay) { reject "respect current delay setting" }
    if(eventFibonacceningActive == true) { reject "fibonaccening already activated" }
    if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
    //after it's approved, changing some things should be PAUSED..add this
	//this has to be vettoable for sure
	
	//propose new fibonaccening event
    fibonaccenningProposal.push(true, block.timestamp, depositingTokens, multiplier, delay, duration)
    transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
    
  
    
    //need to add safeguard so that multiplier*duration does not exceed XXX of amount or something
    //must also be able to prevent multiple fibonaccis to be done... perhaps can't submit new proposal IF last one is true
    //this might be a global problem though(need to do this on all functions..prevent proposals if one is active already??)
    //safeguard is that you need to burn the tokens to execute fibonaccening
}

function vetoFibonaccenning(int proposalID, int depositingTokens) {
    if(depositingTokens != costToVote) { reject "costs to vote" }
    if(fibonaccenningProposal[proposalID][0] == false) { reject "proposal already vettod" }
    
    fibonaccenningProposal[proposalID][0] = false; //negates proposal
    transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}


//there is fibonacenning PRIOR to grandFibonacenningEvent and after it
//the only difference is prior it reduces inflation(subtracts) and afterwards it multiplies by ((100-1.618)/100)
//this is included in the function to setInflation already??
function leverPullFibonaccenningLFG(proposalID) {
    //not sure if this is neccessary since the lever should never be pulled if this condition not met
    if(ERC20(putiheretokenaddress).balanceOf(this) < thresholdFibonnacening) { reject "need to collect penalties before calling"; }
	if(fibonaccenningProposal[proposalID][0] == false { reject "proposal has been rejected"; }
	if(block.timestamp < fibonaccenningProposal[proposalID][1] + delayBeforeEnforce) { reject "delay must expire before proposal valid"; }
	if( eventFibonacceningActive = true ) { reject "already active" }
	
    
    {outsidecontractCall-Masterchef} setRewardPerBlockInMasterchef(currentInflation * fibonaccenningProposal[proposalID][3]);
	
	//WAITWAIT: HOW TO PREVENT MULTIPLE CALLS FOR LEVER PULLZ? IDK
	//what happens if there are multiple pulls?

    fibonacenningActiveID = proposalID;
    fibonacenningActivatedTimestamp = block.timestamp;
    
	eventFibonacceningActive = true;
    transfer(thresholdFibonnacening, deadAddress); //send the coins from .this wallet to deadaddress(burn them to perform fibonaccening)
}

//ends inflation boost, reduces inflation
//anyone can call 
function endFibonaccening() {
    if(eventFibonacceningActive == false) { reject "fibonaccenning not activated" }
    if(block.timestamp < fibonacenningActivatedTimestamp + fibonaccenningProposal[fibonacenningActiveID][5]) { reject "not yet expired" 
    
    int newamount = calculateFibonaccenningNewRewardPerBlock();
    
    //set new inflation with fibonacci reduction
    {outsidecontractCall-Masterchef} setRewardPerBlockInMasterchef(newamount);
    eventFibonacceningActive = false;
    
    //does solidity go line by line when executing? Will first line get executed first? If not, then this could be a problem
    //update current inflation in global setting to that amount
    rewardPerBlockPriorFibonaccening = newamount;
}


struct proposeGrandFibonacenning{
    bool valid;
    int eventDate; 
    int proposalTimestamp;
    int amountSacrificedForVote;
}
proposeGrandFibonacenning[] public grandFibonacceningProposals;

function initiateProposeGrandFibonacenning(int depositingTokens, int delayFromNow) { 
	if(depositingTokens > maximumVoteTokens) { "preventing tyranny, maximum 0.05% of tokens" }
	if(depositingTokens < costToVote) {"there is a minimum cost to vote"}
	if(eligibleGrandFibonacenning ) // WHEN ARE WE ELIGIBLE FOR THIS EVENT?? hmh need to set still
	if(delayFromNow < 3days) { reject }

	transfer(depositingTokens, deadAddress); //burn senders tokens as "transaction cost"
	grandFibonacceningProposals.push("true", block.timestamp + delayFromNow, block.timestamp, depositingTokens);  //submit new proposal
}

function vetoProposeGrandFibonacenning(int proposalID, int depositingTokens) {
	if (grandFibonacceningProposals[proposalID][0] == "false") { reject "already invalid" } 
	if(depositingTokens != grandFibonacceningProposals[proposalID][3]) { reject "must match amount to veto"; }
	
	grandFibonacceningProposals[proposalID][0] = "false";  //negate the proposal
	transfer(depositingTokens, deadAddress); //burn it as "transaction cost to vote"
}





//the grand fibonnacenning where massive supply is printed in a period of X days
//the duration should be preset to last for 10days roughly
//27 events: 1 hour of boosted rewards where supply goes x1.618 every 12hours or so
bool grandFibonacenningActivated = false;
function theGrandFibonacenningEnforce(proposalID) {
    //prepare blockcounters in advance, it will be important
    if(expiredGrandFibonaccening) { "already called gtfo"; } 
    if(!grandFibonacceningProposals[proposalID][0] || grandFibonacceningProposals[proposalID][1] + grandFibonacceningProposals[proposalID][2] < block.timestamp) //not valid
    //need to add another function if it has already happened and has been called too
    //after event expires set the inflation reduction to become another function!!
    
    grandFibonacenningActivated = true;
    	//if you multiply by golden ratio whole supply roughly 27times you will get a 1,000,000X coins
	//it will look better(higher upside potential), there will be no ceiling(resistances)
	//you will be earning more tokens, they will be cheaper,...
	//inflation will be lower
	

    int newInflationRate = getTotalSupply() * goldenRatio;
    rewardPerBlockPriorFibonaccening = newInflationRate;
    
    
    /*
    
    MISSING HERE, and grandfibonacenningRunning function.. (need to set somehow for the function to work basically)
    
    
    */

}


//function that is executing rewards for grand fibonacenning
int eventCounter = 0;
int lastEventTimestamp;
function grandFibonacenningRunning() {
    if(!grandFibonacenningActivated) { reject }
    if(getTotalSupply() > 1quadrillion) { grandFibonacenningRunning = false } // expire it somehow and make sure it can't be called no more
    //print around 9:00UTC and then do it again around 17:00 UTC every day
    //aka make function callable at that time
    //also need ot make sure it can't be called again if running
    
    //should we include the tokens in this contract(penalties) or no?
    int amountToPrint = getTotalSupply() * 0.6183; // we multiply supply x1.6183(golden raito)
    
    int newRewardPerBlock = amountToPrint / (3600/blocksPerSecond);
    {outsidecontractCall-Masterchef} setRewardPerBlockInMasterchef(newRewardPerBlock);
    
    eventCounter++;
}

function gracePeriodTransferOwner() priv admin only {
	//reject call after October 15
	if(block.timestamp > xxx) { reject "Contract is immutable. Grace period only available in the first month for potentital improvements") }
    if(gracePeriodActivation == true) { reject "already activated" }
    gracePeriodActivation = true;
    timestampGracePeriod = block.timestamp;
}
//works as a time-lock. Transfer owner is called and can only be fulfilled after
function afterDelayOwnership(addres newOwnerAddress) priv admin only{
    if(gracePeriodActivation == false) { reject "grace period not request"; }
    if(timestampGracePeriod + 9999 < block.timestamp) { rejecc "minimum 10k blocks before initiation"; } // effectively roughly 6hour timelock i think
    
    //checks passed, safe to change ownerships
    {outsidecontractCall-Masterchef} transferOwnership(newOwnerAddress); //call masterchef function to transfer ownership

}
//do we need this. i mean does it really matter if there is no function for owner? IDK
//CAN BE CALLED BY ANYBODY, basically make it immutable/controlled by nobody
function renounceOwnership() public anybody(idksyntax) {
    if(block.timestamp < 15october) { "grace period expires after 30september" }
    emit OwnershipTransferred(owner, address(0));
    owner = address(0);
}
