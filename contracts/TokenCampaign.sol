// Smart contract used for the EatMeCoin Crowdsale 
//
// @author: Geejay101
// April 2018


pragma solidity ^0.4.18;

import "./library.sol";
import "./MiniMeToken.sol";
import "./EatMeCoin.sol";

contract eat_token_interface{
  uint8 public decimals;
  function generate_token_for(address _addr,uint256 _amount) returns (bool);
  function finalize();
}

// Controlled is implemented in MiniMeToken.sol
contract TokenCampaign is Controlled {
  using SafeMath for uint256;

  // this is our token
  eat_token_interface public token;

  uint8 public constant decimals = 18;

  uint256 public constant scale = (uint256(10) ** decimals);

  uint256 public constant hardcap = 100000000 * scale;

  ///////////////////////////////////
  //
  // constants related to token sale

  // after sale ends, additional tokens will be generated
  // according to the following rules,
  // where 100% correspond to the number of sold tokens

  // percent of reward tokens to be generated
  uint256 public constant PRCT100_D_TEAM = 63; // % * 100 , 0.63%
  uint256 public constant PRCT100_R_TEAM = 250; // % * 100 , 2.5%
  uint256 public constant PRCT100_R2 = 150;  // % * 100 , 1.5%

  // fixed reward
  uint256 public constant FIXEDREWARD_MM = 100000 * scale; // fixed

  // we keep some of the ETH in the contract until the sale is finalized
  // percent of ETH going to operational and reserve account
  uint256 public constant PRCT100_ETH_OP = 4000; // % * 100 , 2x 40%

  // preCrowd structure, Wei
  uint256 public constant preCrowdMinContribution = (20 ether);

  // minmal contribution, Wei
  uint256 public constant minContribution = (1 ether) / 100;

  // how many tokens for one ETH
  uint256 public constant preCrowd_tokens_scaled = 7142857142857140000000; // 30% discount
  uint256 public constant stage_1_tokens_scaled =  6250000000000000000000; // 20% discount
  uint256 public constant stage_2_tokens_scaled =  5555555555555560000000; // 10% discount
  uint256 public constant stage_3_tokens_scaled =  5000000000000000000000; //<-- scaled

  // Tokens allocated for each stage
  uint256 public constant PreCrowdAllocation =  20000000 * scale ; // Tokens
  uint256 public constant Stage1Allocation =    15000000 * scale ; // Tokens
  uint256 public constant Stage2Allocation =    15000000 * scale ; // Tokens
  uint256 public constant Stage3Allocation =    20000000 * scale ; // Tokens

  // keeps track of tokens allocated, scaled value
  uint256 public tokensRemainingPreCrowd = PreCrowdAllocation;
  uint256 public tokensRemainingStage1 = Stage1Allocation;
  uint256 public tokensRemainingStage2 = Stage2Allocation;
  uint256 public tokensRemainingStage3 = Stage3Allocation;

  // If necessary we can cap the maximum amount 
  // of individual contributions in case contributions have exceeded the hardcap
  // this avoids to cap the contributions already when funds flow in
  uint256 public maxPreCrowdAllocationPerInvestor =  20000000 * scale ; // Tokens
  uint256 public maxStage1AllocationPerInvestor =    15000000 * scale ; // Tokens
  uint256 public maxStage2AllocationPerInvestor =    15000000 * scale ; // Tokens
  uint256 public maxStage3AllocationPerInvestor =    20000000 * scale ; // Tokens

  // keeps track of tokens generated so far, scaled value
  uint256 public tokensGenerated = 0;

  address[] public joinedCrowdsale;

  // total Ether raised (= Ether paid into the contract)
  uint256 public amountRaised = 0; 

  // How much wei we have given back to investors.
  uint256 public amountRefunded = 0;


  ////////////////////////////////////////////////////////
  //
  // folowing addresses need to be set in the constructor
  // we also have setter functions which allow to change
  // an address if it is compromised or something happens

  // destination for D-team's share
  address public dteamVaultAddr1;
  address public dteamVaultAddr2;
  address public dteamVaultAddr3;
  address public dteamVaultAddr4;

  // destination for R-team's share
  address public rteamVaultAddr;

  // advisor address
  address public r2VaultAddr;

  // adivisor address
  address public mmVaultAddr;
  
  // destination for reserve tokens
  address public reserveVaultAddr;

  // destination for collected Ether
  address public trusteeVaultAddr;
  
  // destination for operational costs account
  address public opVaultAddr;

  // adress of our token
  address public tokenAddr;
  
  // @check ensure that state transitions are 
  // only in one direction
  // 3 - passive, not accepting funds
  // 2 - active main sale, accepting funds
  // 1 - closed, not accepting funds 
  // 0 - finalized, not accepting funds
  uint8 public campaignState = 3; 
  bool public paused = false;

  // time in seconds since epoch 
  // set to midnight of saturday January 1st, 4000
  uint256 public tCampaignStart = 64060588800;

  uint256 public t_1st_StageEnd = 3 * (1 days); // Stage1 3 days open
  // for testing
  // uint256 public t_1st_StageEnd = 3 * (1 hours); // Stage1 3 days open

  uint256 public t_2nd_StageEnd = 2 * (1 days); // Stage2 2 days open
  // for testing
  // uint256 public t_2nd_StageEnd = 2 * (1 hours); // Stage2 2 days open

  uint256 public tCampaignEnd = 35 * (1 days); // Stage3 35 days open
  // for testing
  // uint256 public tCampaignEnd = 35 * (1 hours); // Stage3 35 days open

  uint256 public tFinalized = 64060588800;

  // participant data
  struct ParticipantListData {

    bool participatedFlag;

    uint256 contributedAmountPreAllocated;
    uint256 contributedAmountPreCrowd;
    uint256 contributedAmountStage1;
    uint256 contributedAmountStage2;
    uint256 contributedAmountStage3;

    uint256 preallocatedTokens;
    uint256 allocatedTokens;

    uint256 spentAmount;
  }

  /** participant addresses */
  mapping (address => ParticipantListData) public participantList;

  uint256 public investorsProcessed = 0;
  uint256 public investorsBatchSize = 100;

  bool public isWhiteListed = true;

  struct WhiteListData {
    bool status;
    uint256 maxCap;
  }

  /** Whitelisted addresses */
  mapping (address => WhiteListData) public participantWhitelist;


  //////////////////////////////////////////////
  //
  // Events
 
  event CampaignOpen(uint256 timenow);
  event CampaignClosed(uint256 timenow);
  event CampaignPaused(uint256 timenow);
  event CampaignResumed(uint256 timenow);

  event PreAllocated(address indexed backer, uint256 raised);
  event RaisedPreCrowd(address indexed backer, uint256 raised);
  event RaisedStage1(address indexed backer, uint256 raised);
  event RaisedStage2(address indexed backer, uint256 raised);
  event RaisedStage3(address indexed backer, uint256 raised);
  event Airdropped(address indexed backer, uint256 tokensairdropped);

  event Finalized(uint256 timenow);

  event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);

  // Address early participation whitelist status changed
  event Whitelisted(address addr, bool status);

  // Refund was processed for a contributor
  event Refund(address investor, uint256 weiAmount);

  /// @notice Constructor
  /// @param _tokenAddress Our token's address
  /// @param  _trusteeAddress Trustee address
  /// @param  _opAddress Operational expenses address 
  /// @param  _reserveAddress Project Token Reserve
  function TokenCampaign(
    address _tokenAddress,
    address _dteamAddress1,
    address _dteamAddress2,
    address _dteamAddress3,
    address _dteamAddress4,
    address _rteamAddress,
    address _r2Address,
    address _mmAddress,
    address _trusteeAddress,
    address _opAddress,
    address _reserveAddress)
  {

    controller = msg.sender;
    
    /// set addresses     
    tokenAddr = _tokenAddress;
    dteamVaultAddr1 = _dteamAddress1;
    dteamVaultAddr2 = _dteamAddress2;
    dteamVaultAddr3 = _dteamAddress3;
    dteamVaultAddr4 = _dteamAddress4;
    rteamVaultAddr = _rteamAddress;
    r2VaultAddr = _r2Address;
    mmVaultAddr = _mmAddress;
    trusteeVaultAddr = _trusteeAddress; 
    opVaultAddr = _opAddress;
    reserveVaultAddr = _reserveAddress;

    /// reference our token
    token = eat_token_interface(tokenAddr);
   
  }


  /////////////////////////////////////////////
  ///
  /// Functions that change contract state

  ///
  /// Setters
  ///

  /// @notice  Puts campaign into active state  
  ///  only controller can do that
  ///  only possible if team token Vault is set up
  ///  WARNING: usual caveats apply to the Ethereum's interpretation of time
  function startSale() public onlyController {
    require( campaignState > 2 );

    campaignState = 2;

    uint256 tNow = now;
    // assume timestamps will not cause overflow
    tCampaignStart = tNow;
    t_1st_StageEnd += tNow;
    t_2nd_StageEnd += tNow;
    tCampaignEnd += tNow;

    CampaignOpen(now);
  }


  /// @notice Pause sale
  ///   just in case we have some troubles 
  ///   Note that time marks are not updated
  function pauseSale() public onlyController {
    require( campaignState  == 2 );
    paused = true;
    CampaignPaused(now);
  }


  /// @notice Resume sale
  function resumeSale() public onlyController {
    require( campaignState  == 2 );
    paused = false;
    CampaignResumed(now);
  }



  /// @notice Puts the camapign into closed state
  ///   only controller can do so
  ///   only possible from the active state
  ///   we can call this function if we want to stop sale before end time 
  ///   and be able to perform 'finalizeCampaign()' immediately
  function closeSale() public onlyController {
    require( campaignState  == 2 );
    campaignState = 1;

    CampaignClosed(now);
  }   


  function setParticipantWhitelist(address addr, bool status, uint256 maxCap) public onlyController {
    participantWhitelist[addr] = WhiteListData({status:status, maxCap:maxCap});
    Whitelisted(addr, status);
  }

  function setMultipleParticipantWhitelist(address[] addrs, bool[] statuses, uint[] maxCaps) public onlyController {
    for (uint256 iterator = 0; iterator < addrs.length; iterator++) {
      setParticipantWhitelist(addrs[iterator], statuses[iterator], maxCaps[iterator]);
    }
  }

  function investorCount() public constant returns (uint256) {
    return joinedCrowdsale.length;
  }

  function contractBalance() public constant returns (uint256) {
    return this.balance;
  }

  /**
   * Investors can claim refund after finalisation.
   *
   * Note that any refunds from proxy buyers should be handled separately,
   * and not through this contract.
   */
  function refund() public {
    require (campaignState == 0);

    uint256 weiValue = participantList[msg.sender].contributedAmountPreCrowd;
    weiValue = weiValue.add(participantList[msg.sender].contributedAmountStage1);
    weiValue = weiValue.add(participantList[msg.sender].contributedAmountStage2);
    weiValue = weiValue.add(participantList[msg.sender].contributedAmountStage3);
    weiValue = weiValue.sub(participantList[msg.sender].spentAmount);

    if (weiValue <= 0) revert();

    participantList[msg.sender].contributedAmountPreCrowd = 0;
    participantList[msg.sender].contributedAmountStage1 = 0;
    participantList[msg.sender].contributedAmountStage2 = 0;
    participantList[msg.sender].contributedAmountStage3 = 0;

    amountRefunded = amountRefunded.add(weiValue);

    // send it
    if (!msg.sender.send(weiValue)) revert();

    // announce to world
    Refund(msg.sender, weiValue);

  }

  /// @notice Finalizes the campaign
  ///   Get funds out, generates team, reserve and reserve tokens
  function allocateInvestors() public onlyController {     
      
    /// only if sale was closed or 48 hours = 2880 minutes have passed since campaign end
    /// we leave this time to complete possibly pending orders from offchain contributions 

    require ( (campaignState == 1) || ((campaignState != 0) && (now > tCampaignEnd + (2880 minutes))));

    uint256 nTokens = 0;
    uint256 rate = 0;
    uint256 contributedAmount = 0; 

    uint256 investorsProcessedEnd = investorsProcessed + investorsBatchSize;

    if (investorsProcessedEnd > joinedCrowdsale.length) {
      investorsProcessedEnd = joinedCrowdsale.length;
    }

    for (uint256 i = investorsProcessed; i < investorsProcessedEnd; i++) {

        investorsProcessed++;

        address investorAddress = joinedCrowdsale[i];

        // PreCrowd stage
        contributedAmount = participantList[investorAddress].contributedAmountPreCrowd;

        if (isWhiteListed) {

            // is contributeAmount within whitelisted amount
            if (contributedAmount > participantWhitelist[investorAddress].maxCap) {
                contributedAmount = participantWhitelist[investorAddress].maxCap;
            }

            // calculate remaining whitelisted amount
            if (contributedAmount>0) {
                participantWhitelist[investorAddress].maxCap = participantWhitelist[investorAddress].maxCap.sub(contributedAmount);
            }

        }

        if (contributedAmount>0) {

            // calculate the number of tokens
            rate = preCrowd_tokens_scaled;
            nTokens = (rate.mul(contributedAmount)).div(1 ether);

            // check whether individual allocations are capped
            if (nTokens > maxPreCrowdAllocationPerInvestor) {
              nTokens = maxPreCrowdAllocationPerInvestor;
            }

            // If tokens are bigger than whats left in the stage, give the rest 
            if (tokensRemainingPreCrowd.sub(nTokens) < 0) {
                nTokens = tokensRemainingPreCrowd;
            }

            // update spent amount
            participantList[joinedCrowdsale[i]].spentAmount = participantList[joinedCrowdsale[i]].spentAmount.add(nTokens.div(rate).mul(1 ether));

            // calculate leftover tokens for the stage 
            tokensRemainingPreCrowd = tokensRemainingPreCrowd.sub(nTokens);

            // update the new token holding
            participantList[investorAddress].allocatedTokens = participantList[investorAddress].allocatedTokens.add(nTokens);

        }

        //  stage1
        contributedAmount = participantList[investorAddress].contributedAmountStage1;

        if (isWhiteListed) {

            // is contributeAmount within whitelisted amount
            if (contributedAmount > participantWhitelist[investorAddress].maxCap) {
                contributedAmount = participantWhitelist[investorAddress].maxCap;
            }

            // calculate remaining whitelisted amount
            if (contributedAmount>0) {
                participantWhitelist[investorAddress].maxCap = participantWhitelist[investorAddress].maxCap.sub(contributedAmount);
            }

        }

        if (contributedAmount>0) {

            // calculate the number of tokens
            rate = stage_1_tokens_scaled;
            nTokens = (rate.mul(contributedAmount)).div(1 ether);

            // check whether individual allocations are capped
            if (nTokens > maxStage1AllocationPerInvestor) {
              nTokens = maxStage1AllocationPerInvestor;
            }

            // If tokens are bigger than whats left in the stage, give the rest 
            if (tokensRemainingStage1.sub(nTokens) < 0) {
                nTokens = tokensRemainingStage1;
            }

            // update spent amount
            participantList[joinedCrowdsale[i]].spentAmount = participantList[joinedCrowdsale[i]].spentAmount.add(nTokens.div(rate).mul(1 ether));

            // calculate leftover tokens for the stage 
            tokensRemainingStage1 = tokensRemainingStage1.sub(nTokens);

            // update the new token holding
            participantList[investorAddress].allocatedTokens = participantList[investorAddress].allocatedTokens.add(nTokens);

        }

        //  stage2
        contributedAmount = participantList[investorAddress].contributedAmountStage2;

        if (isWhiteListed) {

            // is contributeAmount within whitelisted amount
            if (contributedAmount > participantWhitelist[investorAddress].maxCap) {
                contributedAmount = participantWhitelist[investorAddress].maxCap;
            }

            // calculate remaining whitelisted amount
            if (contributedAmount>0) {
                participantWhitelist[investorAddress].maxCap = participantWhitelist[investorAddress].maxCap.sub(contributedAmount);
            }

        }

        if (contributedAmount>0) {

            // calculate the number of tokens
            rate = stage_2_tokens_scaled;
            nTokens = (rate.mul(contributedAmount)).div(1 ether);

            // check whether individual allocations are capped
            if (nTokens > maxStage2AllocationPerInvestor) {
              nTokens = maxStage2AllocationPerInvestor;
            }

            // If tokens are bigger than whats left in the stage, give the rest 
            if (tokensRemainingStage2.sub(nTokens) < 0) {
                nTokens = tokensRemainingStage2;
            }

            // update spent amount
            participantList[joinedCrowdsale[i]].spentAmount = participantList[joinedCrowdsale[i]].spentAmount.add(nTokens.div(rate).mul(1 ether));

            // calculate leftover tokens for the stage 
            tokensRemainingStage2 = tokensRemainingStage2.sub(nTokens);

            // update the new token holding
            participantList[investorAddress].allocatedTokens = participantList[investorAddress].allocatedTokens.add(nTokens);

        }

        //  stage3
        contributedAmount = participantList[investorAddress].contributedAmountStage3;

        if (isWhiteListed) {

            // is contributeAmount within whitelisted amount
            if (contributedAmount > participantWhitelist[investorAddress].maxCap) {
                contributedAmount = participantWhitelist[investorAddress].maxCap;
            }

            // calculate remaining whitelisted amount
            if (contributedAmount>0) {
                participantWhitelist[investorAddress].maxCap = participantWhitelist[investorAddress].maxCap.sub(contributedAmount);
            }

        }

        if (contributedAmount>0) {

            // calculate the number of tokens
            rate = stage_3_tokens_scaled;
            nTokens = (rate.mul(contributedAmount)).div(1 ether);

            // check whether individual allocations are capped
            if (nTokens > maxStage3AllocationPerInvestor) {
              nTokens = maxStage3AllocationPerInvestor;
            }

            // If tokens are bigger than whats left in the stage, give the rest 
            if (tokensRemainingStage3.sub(nTokens) < 0) {
                nTokens = tokensRemainingStage3;
            }

            // update spent amount
            participantList[joinedCrowdsale[i]].spentAmount = participantList[joinedCrowdsale[i]].spentAmount.add(nTokens.div(rate).mul(1 ether));

            // calculate leftover tokens for the stage 
            tokensRemainingStage3 = tokensRemainingStage3.sub(nTokens);

            // update the new token holding
            participantList[investorAddress].allocatedTokens = participantList[investorAddress].allocatedTokens.add(nTokens);

        }

        do_grant_tokens(investorAddress, participantList[investorAddress].allocatedTokens);

    }

  }

  /// @notice Finalizes the campaign
  ///   Get funds out, generates team, reserve and reserve tokens
  function finalizeCampaign() public onlyController {     
      
    /// only if sale was closed or 48 hours = 2880 minutes have passed since campaign end
    /// we leave this time to complete possibly pending orders from offchain contributions 

    require ( (campaignState == 1) || ((campaignState != 0) && (now > tCampaignEnd + (2880 minutes))));

    campaignState = 0;

    // dteam tokens
    uint256 drewardTokens = (tokensGenerated.mul(PRCT100_D_TEAM)).div(10000);

    // rteam tokens
    uint256 rrewardTokens = (tokensGenerated.mul(PRCT100_R_TEAM)).div(10000);

    // r2 tokens
    uint256 r2rewardTokens = (tokensGenerated.mul(PRCT100_R2)).div(10000);

    // mm tokens
    uint256 mmrewardTokens = FIXEDREWARD_MM;

    do_grant_tokens(dteamVaultAddr1, drewardTokens);
    do_grant_tokens(dteamVaultAddr2, drewardTokens);
    do_grant_tokens(dteamVaultAddr3, drewardTokens);
    do_grant_tokens(dteamVaultAddr4, drewardTokens);     
    do_grant_tokens(rteamVaultAddr, rrewardTokens);
    do_grant_tokens(r2VaultAddr, r2rewardTokens);
    do_grant_tokens(mmVaultAddr, mmrewardTokens);

    // generate reserve tokens 
    // uint256 reserveTokens = rest of tokens under hardcap
    uint256 reserveTokens = hardcap.sub(tokensGenerated);
    do_grant_tokens(reserveVaultAddr, reserveTokens);

    // prevent further token generation
    token.finalize();

    tFinalized = now;
    
    // notify the world
    Finalized(tFinalized);
  }


  ///   Get funds out
  function retrieveFunds() public onlyController {     

      require (campaignState == 0);
      
      // forward funds to the trustee 
      // since we forward a fraction of the incomming ether on every contribution
      // 'amountRaised' IS NOT equal to the contract's balance
      // we use 'this.balance' instead

      // we do this manually to give people the chance to claim refunds in case of overpayments

      trusteeVaultAddr.transfer(this.balance);

  }

     ///   Get funds out
  function emergencyFinalize() public onlyController {     

    campaignState = 0;

    // prevent further token generation
    token.finalize();

  }


  /// @notice triggers token generaton for the recipient
  ///  can be called only from the token sale contract itself
  ///  side effect: increases the generated tokens counter 
  ///  CAUTION: we do not check campaign state and parameters assuming that's callee's task
  function do_grant_tokens(address _to, uint256 _nTokens) internal returns (bool){
    
    require( token.generate_token_for(_to, _nTokens) );
    
    tokensGenerated = tokensGenerated.add(_nTokens);
    
    return true;
  }


  ///  @notice processes the contribution
  ///   checks campaign state, time window and minimal contribution
  ///   throws if one of the conditions fails
  function process_contribution(address _toAddr) internal {

    require ((campaignState == 2)   // active main sale
         && (now <= tCampaignEnd)   // within time window
         && (paused == false));     // not on hold
    
    // we check that Eth sent is sufficient 
    // though our token has decimals we don't want nanocontributions
    require ( msg.value >= minContribution );

    amountRaised = amountRaised.add(msg.value);

    // check whether we know this investor, if not add him to list
    if (!participantList[_toAddr].participatedFlag) {

       // A new investor
       participantList[_toAddr].participatedFlag = true;
       joinedCrowdsale.push(_toAddr);
    }

    if ( msg.value >= preCrowdMinContribution ) {

      participantList[_toAddr].contributedAmountPreCrowd = participantList[_toAddr].contributedAmountPreCrowd.add(msg.value);
      
      // notify the world
      RaisedPreCrowd(_toAddr, msg.value);

    } else {

      if (now <= t_1st_StageEnd) {

        participantList[_toAddr].contributedAmountStage1 = participantList[_toAddr].contributedAmountStage1.add(msg.value);

        // notify the world
        RaisedStage1(_toAddr, msg.value);

      } else if (now <= t_2nd_StageEnd) {

        participantList[_toAddr].contributedAmountStage2 = participantList[_toAddr].contributedAmountStage2.add(msg.value);

        // notify the world
        RaisedStage2(_toAddr, msg.value);

      } else {

        participantList[_toAddr].contributedAmountStage3 = participantList[_toAddr].contributedAmountStage3.add(msg.value);
        
        // notify the world
        RaisedStage3(_toAddr, msg.value);

      }

    }

    // compute the fraction of ETH going to op account
    uint256 opEth = (PRCT100_ETH_OP.mul(msg.value)).div(10000);

    // transfer to op account 
    opVaultAddr.transfer(opEth);

    // transfer to reserve account 
    reserveVaultAddr.transfer(opEth);

  }

  /**
  * Preallocated tokens have been sold or given in airdrop before the actual crowdsale opens. 
  * This function mints the tokens and moves the crowdsale needle.
  *
  */
  function preallocate(address _toAddr, uint fullTokens, uint weiPaid) public onlyController {

    require (campaignState != 0);

    uint tokenAmount = fullTokens * scale;
    uint weiAmount = weiPaid ; // This can be also 0, we give out tokens for free

    if (!participantList[_toAddr].participatedFlag) {

       // A new investor
       participantList[_toAddr].participatedFlag = true;
       joinedCrowdsale.push(_toAddr);

    }

    participantList[_toAddr].contributedAmountPreAllocated = participantList[_toAddr].contributedAmountPreAllocated.add(weiAmount);
    participantList[_toAddr].preallocatedTokens = participantList[_toAddr].preallocatedTokens.add(tokenAmount);

    amountRaised = amountRaised.add(weiAmount);

    // side effect: do_grant_tokens updates the "tokensGenerated" variable
    require( do_grant_tokens(_toAddr, tokenAmount) );

    // notify the world
    PreAllocated(_toAddr, weiAmount);

  }

  function airdrop(address _toAddr, uint fullTokens) public onlyController {

    require (campaignState != 0);

    uint tokenAmount = fullTokens * scale;

    if (!participantList[_toAddr].participatedFlag) {

       // A new investor
       participantList[_toAddr].participatedFlag = true;
       joinedCrowdsale.push(_toAddr);

    }

    participantList[_toAddr].preallocatedTokens = participantList[_toAddr].allocatedTokens.add(tokenAmount);

    // side effect: do_grant_tokens updates the "tokensGenerated" variable
    require( do_grant_tokens(_toAddr, tokenAmount) );

    // notify the world
    Airdropped(_toAddr, fullTokens);

  }

  function multiAirdrop(address[] addrs, uint[] fullTokens) public onlyController {

    require (campaignState != 0);

    for (uint256 iterator = 0; iterator < addrs.length; iterator++) {
      airdrop(addrs[iterator], fullTokens[iterator]);
    }
  }

  // set individual preCrowd cap
  function setInvestorsBatchSize(uint256 _batchsize) public onlyController {
      investorsBatchSize = _batchsize;
  }

  // set individual preCrowd cap
  function setMaxPreCrowdAllocationPerInvestor(uint256 _cap) public onlyController {
      maxPreCrowdAllocationPerInvestor = _cap;
  }

  // set individual stage1Crowd cap
  function setMaxStage1AllocationPerInvestor(uint256 _cap) public onlyController {
      maxStage1AllocationPerInvestor = _cap;
  }

  // set individual stage2Crowd cap
  function setMaxStage2AllocationPerInvestor(uint256 _cap) public onlyController {
      maxStage2AllocationPerInvestor = _cap;
  }

  // set individual stage3Crowd cap
  function setMaxStage3AllocationPerInvestor(uint256 _cap) public onlyController {
      maxStage3AllocationPerInvestor = _cap;
  }

  function setdteamVaultAddr1(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    dteamVaultAddr1 = _newAddr;
  }

  function setdteamVaultAddr2(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    dteamVaultAddr2 = _newAddr;
  }

  function setdteamVaultAddr3(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    dteamVaultAddr3 = _newAddr;
  }

  function setdteamVaultAddr4(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    dteamVaultAddr4 = _newAddr;
  }

  function setrteamVaultAddr(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    rteamVaultAddr = _newAddr;
  }

  function setr2VaultAddr(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    r2VaultAddr = _newAddr;
  }

  function setmmVaultAddr(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    mmVaultAddr = _newAddr;
  }

  function settrusteeVaultAddr(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    trusteeVaultAddr = _newAddr;
  }

  function setopVaultAddr(address _newAddr) public onlyController {
    require( _newAddr != 0x0 );
    opVaultAddr = _newAddr;
  }

  function toggleWhitelist(bool _isWhitelisted) public onlyController {
    isWhiteListed = _isWhitelisted;
  }

  /// @notice This function handles receiving Ether in favor of a third party address
  ///   we can use this function for buying tokens on behalf
  /// @param _toAddr the address which will receive tokens
  function proxy_contribution(address _toAddr) public payable {
    require ( _toAddr != 0x0 );

    process_contribution(_toAddr);
  }


  /// @notice This function handles receiving Ether
  function () payable {
      process_contribution(msg.sender); 
  }

  /// This method can be used by the controller to extract mistakenly
  ///  sent tokens to this contract.
  function claimTokens(address _tokenAddr) public onlyController {

      ERC20Basic some_token = ERC20Basic(_tokenAddr);
      uint256 balance = some_token.balanceOf(this);
      some_token.transfer(controller, balance);
      ClaimedTokens(_tokenAddr, controller, balance);
  }
}
  