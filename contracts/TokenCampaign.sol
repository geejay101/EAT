// This is the code fot the smart contract 
// used for the EatMeCoin Crowdsale 
//
// @author: Pavel Metelitsyn, Geejay101
// September 2017


pragma solidity ^0.4.15;

import "./library.sol";
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

  uint256 public constant hardcap = 1000000 * scale;

  ///////////////////////////////////
  //
  // constants related to token sale

  // after slae ends, additional tokens will be generated
  // according to the following rules,
  // where 100% correspond to the number of sold tokens

  // percent of reward tokens to be generated for the D-team
  uint256 public constant PRCT100_D_TEAM = 63; // % * 100
  uint256 public constant PRCT100_R_TEAM = 250; // % * 100
 
  uint256 public constant FIXEDREWARD_MM = 1000; // fixed
  uint256 public constant FIXEDREWARD_RJDG = 15000; // fixed

  // we keep some of the ETH in the contract until the sale is finalized
  // percent of ETH going to operational account
  uint256 public constant PRCT100_ETH_OP = 8000;

  // preCrowd structure, Wei
  uint256 public constant preCrowdMinContribution = (10 ether);

  // minmal contribution, Wei
  uint256 public constant minContribution = (5 ether) / 100;

  // we want to limit the number of available tokens during the preCrowd stage 
  // payments during the preCrowd stage will not be accepted after the TokenTreshold is reached or exceeded
  // we may adjust this number before deployment based on the market conditions

  uint256 public constant preCrowdTokenThreshold = 200000 * scale ; //<--- new 
  uint256 public constant crowdTokenThreshold = 700000 * scale ; //<--- new 

  // how many tokens for one ETH
  // we may adjust this number before deployment based on the market conditions
  uint256 public constant preCrowd_stage_tokens_scaled = 71428571428571400000; // 30% discount
  uint256 public constant stage_1_tokens_scaled =     62500000000000000000; // 20% discount
  uint256 public constant stage_2_tokens_scaled =     55555555555555600000; // 10% discount
  uint256 public constant stage_3_tokens_scaled =     50000000000000000000; //<-- scaled


  // If necessary we can cap the maximum amount 
  // of individual contributions in case contributions have exceeded the hardcap
  // this avoids to cap the contributions already when funds flow in
  uint256 public maxPreCrowdStageContribution =  200000 * scale ; // Tokens
  uint256 public maxStage1Contribution =      150000 * scale ; // Tokens
  uint256 public maxStage2Contribution =      150000 *  scale ; // Tokens
  uint256 public maxStage3Contribution =      200000 * scale ; // Tokens

  // keeps track of tokens generated so far, scaled value
  uint256 public tokensGenerated = 0;

  uint256 public investorCount = 0;

    // keeps track of tokens sold so far, scaled value
  uint256 public tokensSoldPreCrowd = 0;
  uint256 public tokensSoldStage1 = 0;
  uint256 public tokensSoldStage2 = 0;
  uint256 public tokensSoldStage3 = 0;

  // total Ether raised (= Ether paid into the contract)
  uint256 public amountRaised= 0; 

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
  address public rjdgVaultAddr;

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
  // 4 - passive, not accepting funds
  // 3 - is not used
  // 2 - active main sale, accepting funds
  // 1 - closed, not accepting funds 
  // 0 - finalized, not accepting funds
  uint8 public campaignState = 4; 
  bool public paused = false;

  // time in seconds since epoch 
  // set to midnight of saturday January 1st, 4000
  uint256 public tCampaignStart = 64060588800;
  uint256 public tPreCrowdStageEnd = 7 * (1 days);
  uint256 public t_1st_StageEnd = 15 * (1 days);
  uint256 public t_2nd_StageEnd = 22* (1 days);
  uint256 public tCampaignEnd = 38 * (1 days);
  uint256 public tFinalized = 64060588800;

  /** How much ETH each address has invested to this crowdsale */
  mapping (address => uint256) public investedAmountOf;

  /** How much tokens this crowdsale has credited for each investor address */
  mapping (address => uint256) public tokenAmountOf;

  address[] public joinedCrowdsales;
  uint256 public joinedCrowdsalesLen = 0;

  bool public isWhiteListed = true;

  struct WhiteListData {
    bool status;
    uint256 minCap;
    uint256 maxCap;
  }

  /** Whitelisted addresses */
  mapping (address => WhiteListData) public participantWhitelist;


  // participant data
  struct ParticipantListData {
    uint256 contributedAmountPreCrowd;
    uint256 calculatedTokensPreCrowd;

    uint256 contributedAmountStage1;
    uint256 calculatedTokensStage1;

    uint256 contributedAmountStage2;
    uint256 calculatedTokensStage2;

    uint256 contributedAmountStage3;
    uint256 calculatedTokensStage3;
  }

  /** participant addresses */
  mapping (address => ParticipantListData) public participantList;

  //////////////////////////////////////////////
  //
  // Events
 
  event CampaignOpen(uint256);
  event CampaignClosed(uint256);
  event CampaignPaused(uint256);
  event CampaignResumed(uint256);


  event TotalRaisedPreCrowd(address indexed backer, uint256 raised, uint256 amount);
  event TotalRaisedStage1(address indexed backer, uint256 raised, uint256 amount);
  event TotalRaisedStage2(address indexed backer, uint256 raised, uint256 amount);
  event TotalRaisedStage3(address indexed backer, uint256 raised, uint256 amount);

  event Finalized(uint256);

  event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);

  // Address early participation whitelist status changed
  event Whitelisted(address addr, bool status);

  // Refund was processed for a contributor
  event Refund(address investor, uint256 weiAmount);

  // Address whitelist status changed
  event Whitelisted(address addr, bool status);

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
    address _rjdgAddress,
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
    rjdgVaultAddr = _rjdgAddress;
    mmVaultAddr = _mmAddress;

    trusteeVaultAddr = _trusteeAddress; 
    opVaultAddr = _opAddress;
    reserveVaultAddr = _reserveAddress;

    /// reference our token
    token = eat_token_interface(tokenAddr);
   
    // adjust 'constants' for decimals used
    // decimals = token.decimals(); // should be 18
   
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
    tPreCrowdStageEnd += tNow;
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


  function setParticipantWhitelist(address addr, bool status, uint256 minCap, uint256 maxCap) public onlyController {
    if (!isWhiteListed) revert();
    participantWhitelist[addr] = WhiteListData({status:status, minCap:minCap, maxCap:maxCap});
    Whitelisted(addr, status);
  }

  function setMultipleParticipantWhitelist(address[] addrs, bool[] statuses, uint[] minCaps, uint[] maxCaps) public onlyController {
    if (!isWhiteListed) revert();
    for (uint256 iterator = 0; iterator < addrs.length; iterator++) {
      setParticipantWhitelist(addrs[iterator], statuses[iterator], minCaps[iterator], maxCaps[iterator]);
    }
  }

  function updateParticipantWhitelist(address addr, address contractAddr, uint256 amountBought) internal {
    if (amountBought < participantWhitelist[addr].minCap) revert();
    if (!isWhiteListed) revert();
    if (addr != msg.sender && contractAddr != msg.sender) revert();
    uint256 newMaxCap = participantWhitelist[addr].maxCap;
    newMaxCap = newMaxCap.sub(amountBought);
    participantWhitelist[addr] = WhiteListData({status:participantWhitelist[addr].status, minCap:0, maxCap:newMaxCap});
  }

  function isBreakingInvestorCap(address addr, uint256 amountBought) constant returns (bool limitBroken) {
    if (!isWhiteListed) revert();
    uint256 maxCap = participantWhitelist[addr].maxCap;
    return (tokenAmountOf[addr].add(amountBought)) > maxCap;
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

    if (weiValue == 0) revert();

    participantList[msg.sender] = WhiteListData({
      contributedAmountPreCrowd: 0,
      calculatedTokensPreCrowd: 0,

      contributedAmountStage1: 0,
      calculatedTokensStage1: 0,

      contributedAmountStage2: 0,
      calculatedTokensStage2: 0,

      contributedAmountStage3: 0,
      calculatedTokensStage3: 0
    });

    amountRefunded = amountRefunded.add(weiValue);

    // announce to world
    Refund(msg.sender, weiValue);
 
    // send it
    if (!msg.sender.send(weiValue)) revert();
  }

  /// @notice Finalizes the campaign
  ///   Get funds out, generates team, reserve and reserve tokens
  function finalizeCampaign() public onlyController {     
      
      /// only if sale was closed or 48 hours = 2880 minutes have passed since campaign end
      /// we leave this time to complete possibly pending orders from offchain contributions 
      
      require ( (campaignState == 1) ||
                ((campaignState != 0) && (now > tCampaignEnd + (2880 minutes))));
      
      campaignState = 0;

      // forward funds to the trustee 
      // since we forward a fraction of the incomming ether on every contribution
      // 'amountRaised' IS NOT equal to the contract's balance
      // we use 'this.balance' instead

      // trusteeVaultAddr.transfer(this.balance);

      // 
      if (isWhiteListed) {
        uint256 num = 0;
        for (var i = 0; i < joinedCrowdsalesLen; i++) {
          if (this == joinedCrowdsales[i]) 
            num = i;
        }

        if (num + 1 < joinedCrowdsalesLen) {
          for (var j = num + 1; j < joinedCrowdsalesLen; j++) {
            CrowdsaleExt crowdsale = CrowdsaleExt(joinedCrowdsales[j]);
            crowdsale.updateParticipantWhitelist(msg.sender, this, tokenAmount);
          }
        }
      }


      // generate reserve tokens 
      // uint256 reserveTokens = rest of tokens under hardcap
      uint256 reserveTokens = hardcap.sub(tokensGenerated);
      assert( do_grant_tokens(reserveVaultAddr, reserveTokens) );

      // dteam tokens
      uint256 dteamTokens = (tokensGenerated.mul(PRCT100_D_TEAM)).div(10000);
      assert( do_grant_tokens(dteamVaultAddr1, dteamTokens) );
      assert( do_grant_tokens(dteamVaultAddr2, dteamTokens) );
      assert( do_grant_tokens(dteamVaultAddr3, dteamTokens) );
      assert( do_grant_tokens(dteamVaultAddr4, dteamTokens) );     

      // rteam tokens
      uint256 rteamTokens = (tokensGenerated.mul(PRCT100_R_TEAM)).div(10000);
      assert( do_grant_tokens(rteamVaultAddr, rteamTokens) );
      
      // rjdg tokens
      assert( do_grant_tokens(rjdgVaultAddr, FIXEDREWARD_RJDG) );

      // mm tokens
      assert( do_grant_tokens(mmVaultAddr, FIXEDREWARD_MM) );


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


  /// @notice triggers token generaton for the recipient
  ///  can be called only from the token sale contract itself
  ///  side effect: increases the generated tokens counter 
  ///  CAUTION: we do not check campaign state and parameters assuming that's callee's task
  function do_grant_tokens(address _to, uint256 _nTokens) internal returns (bool){
    
    require( token.generate_token_for(_to, _nTokens) );
    
    tokensGenerated = tokensGenerated.add(_nTokens);
    
    return true;
  }



function investInternal(address receiver, uint128 customerId)  private {

    // Determine if it's a good time to accept investment from this participant
    if(getState() == State.PreFunding) {
      // Are we whitelisted for early deposit
      revert();
    } else if(getState() == State.Funding) {
      // Retail participants can only come in when the crowdsale is running
      // pass
      if(isWhiteListed) {
        if(!participantWhitelist[receiver].status) {
          revert();
        }
      }
    } else {
      // Unwanted state
      revert();
    }

    uint256 weiAmount = msg.value;

    // Account presale sales separately, so that they do not count against pricing tranches
    uint256 tokenAmount = pricingStrategy.calculatePrice(weiAmount, weiRaised - presaleWeiRaised, tokensSold, msg.sender, token.decimals());

    if(tokenAmount == 0) {
      // Dust transaction
      revert();
    }

    if(isWhiteListed) {
      if(tokenAmount < participantWhitelist[receiver].minCap && tokenAmountOf[receiver] == 0) {
        // tokenAmount < minCap for investor
        revert();
      }
      if(tokenAmount > participantWhitelist[receiver].maxCap) {
        // tokenAmount > maxCap for investor
        revert();
      }

      // Check that we did not bust the investor's cap
      if (isBreakingInvestorCap(receiver, tokenAmount)) {
        revert();
      }
    } else {
      if(tokenAmount < token.minCap() && tokenAmountOf[receiver] == 0) {
        revert();
      }
    }

    if(investedAmountOf[receiver] == 0) {
       // A new investor
       investorCount++;
    }

    // Update investor
    investedAmountOf[receiver] = investedAmountOf[receiver].add(weiAmount);
    tokenAmountOf[receiver] = tokenAmountOf[receiver].add(tokenAmount);

    // Update totals
    weiRaised = weiRaised.add(weiAmount);
    tokensSold = tokensSold.add(tokenAmount);

    if(pricingStrategy.isPresalePurchase(receiver)) {
        presaleWeiRaised = presaleWeiRaised.add(weiAmount);
    }

    // Check that we did not bust the cap
    if(isBreakingCap(weiAmount, tokenAmount, weiRaised, tokensSold)) {
      revert();
    }

    assignTokens(receiver, tokenAmount);

    // Pocket the money
    if(!multisigWallet.send(weiAmount)) revert();

    if (isWhiteListed) {
      uint256 num = 0;
      for (var i = 0; i < joinedCrowdsalesLen; i++) {
        if (this == joinedCrowdsales[i]) 
          num = i;
      }

      if (num + 1 < joinedCrowdsalesLen) {
        for (var j = num + 1; j < joinedCrowdsalesLen; j++) {
          CrowdsaleExt crowdsale = CrowdsaleExt(joinedCrowdsales[j]);
          crowdsale.updateEarlyParicipantWhitelist(msg.sender, this, tokenAmount);
        }
      }
    }

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

    uint256 nTokens = 0;
    uint256 rate = 0;

    amountRaised = amountRaised.add(msg.value);

    if (now <= tPreCrowdStageEnd) {

      // during the preCrowd stage we require a minimal eth contribution 
      if ( msg.value < preCrowdMinContribution )
      {
        revert();
      }

      participantList[_toAddr].contributedAmountPreCrowd = participantList[_toAddr].contributedAmountPreCrowd.add(msg.value);

      rate = preCrowd_stage_tokens_scaled;
      nTokens = (rate.mul(msg.value)).div(1 ether);
      participantList[_toAddr].calculatedTokensPreCrowd = participantList[_toAddr].calculatedTokensPreCrowd.add(nTokens);

      // Update totals
      tokensSoldPreCrowd = tokensSoldPreCrowd.add(nTokens);
      
      // notify the world
      TotalRaisedPreCrowd(_toAddr, amountRaised, tokensSoldPreCrowd);


    } else if (now <= t_1st_StageEnd) {

      participantList[_toAddr].contributedAmountStage1 = participantList[_toAddr].contributedAmountStage1.add(msg.value);

      rate = stage_1_tokens_scaled;
      nTokens = (rate.mul(msg.value)).div(1 ether);
      participantList[_toAddr].calculatedTokensStage1 = participantList[_toAddr].calculatedTokensStage1.add(nTokens);

      // Update totals
      tokensSoldStage1 = tokensSoldStage1.add(nTokens);
      
      // notify the world
      TotalRaisedStage1(_toAddr, amountRaised, tokensSoldStage1);

    } else if (now <= t_2nd_StageEnd) {

      participantList[_toAddr].contributedAmountStage2 = participantList[_toAddr].contributedAmountStage2.add(msg.value);

      rate = stage_2_tokens_scaled;
      nTokens = (rate.mul(msg.value)).div(1 ether);
      participantList[_toAddr].calculatedTokensStage2 = participantList[_toAddr].calculatedTokensStage2.add(nTokens);

      // Update totals
      tokensSoldStage2 = tokensSoldStage2.add(nTokens);
      
      // notify the world
      TotalRaisedStage2(_toAddr, amountRaised, tokensSoldStage2);

    } else {

      participantList[_toAddr].contributedAmountStage3 = participantList[_toAddr].contributedAmountStage3.add(msg.value);

      rate = stage_3_tokens_scaled;
      nTokens = (rate.mul(msg.value)).div(1 ether);
      participantList[_toAddr].calculatedTokensStage3 = participantList[_toAddr].calculatedTokensStage3.add(nTokens);

      // Update totals
      tokensSoldStage3 = tokensSoldStage3.add(nTokens);
      
      // notify the world
      TotalRaisedStage3(_toAddr, amountRaised, tokensSoldStage3);

    }

    // compute the fraction of ETH going to op account
    uint256 opEth = (PRCT100_ETH_OP.mul(msg.value)).div(10000);

    // transfer to op account 
    opVaultAddr.transfer(opEth);

    if(investedAmountOf[_toAddr] == 0) {
       // A new investor
       investorCount++;
    }

  }

  /**
   * Preallocate tokens for the early investors.
   *
   * Preallocated tokens have been sold before the actual crowdsale opens.
   * This function mints the tokens and moves the crowdsale needle.
   *
   * Investor count is not handled; it is assumed this goes for multiple investors
   * and the token distribution happens outside the smart contract flow.
   *
   * No money is exchanged, as the crowdsale team already have received the payment.
   *
   * @param fullTokens tokens as full tokens - decimal places added internally
   * @param weiPrice Price of a single full token in wei
   *
   */
  function preallocate(address receiver, uint fullTokens, uint weiPrice) public onlyController {

    uint tokenAmount = fullTokens * 10**scale;
    uint weiAmount = weiPrice * fullTokens; // This can be also 0, we give out tokens for free

    investedAmountOf[receiver] = investedAmountOf[receiver].add(weiAmount);
    tokenAmountOf[receiver] = tokenAmountOf[receiver].add(tokenAmount);

    // side effect: do_grant_tokens updates the "tokensGenerated" variable
    require( do_grant_tokens(receiver, tokenAmount) );

    // notify the world
    Allocated(receiver, weiAmount, tokenAmount);

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

  //////////
  // Safety Methods
  //////////

  /* inspired by MiniMeToken.sol */

  /// @notice This method can be used by the controller to extract mistakenly
  ///  sent tokens to this contract.
  function claimTokens(address _tokenAddr) public onlyController {

      ERC20Basic some_token = ERC20Basic(_tokenAddr);
      uint256 balance = some_token.balanceOf(this);
      some_token.transfer(controller, balance);
      ClaimedTokens(_tokenAddr, controller, balance);
  }
}
  