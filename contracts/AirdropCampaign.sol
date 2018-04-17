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

  uint256 public constant hardcap = 100000000 * scale;

  ///////////////////////////////////
  //
  // constants related to token sale

  // after slae ends, additional tokens will be generated
  // according to the following rules,
  // where 100% correspond to the number of sold tokens

  // percent of reward tokens to be generated when campaign closes
  uint256 public constant PRCT100_D_TEAM = 250; // % * 100
  uint256 public constant PRCT100_R_TEAM = 250; // % * 100
  uint256 public constant PRCT100_CORP = 2000; // % * 100
  uint256 public constant PRCT100_MM = 10; // % * 100
  uint256 public constant PRCT100_RJDG = 150; // % * 100

  // minmal contribution, Wei
  uint256 public constant minContribution = (2 ether) / 1000; // 0.002 ETHER

  uint256 public constant minForChance = (2 ether) / 10; // 0.2 ETHER

  uint256 public constant maxTokensDrop = 1000000 * scale; // maximimum 1m Tokens per account

  // total Ether raised (= Ether paid into the contract)
  uint256 public amountRaised= 0; 

  // keeps track of tokens generated so far, scaled value
  uint256 public tokensIssued = 0;

  uint256 public investorCount = 0;


  ////////////////////////////////////////////////////////
  //
  // folowing addresses need to be set in the constructor
  // we also have setter functions which allow to change
  // an address if it is compromised or something happens

  // destination for D-team's share
  address public dteamVaultAddr;

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
  uint256 public tCampaignEnd = 33 * (1 days);
  uint256 public tFinalized = 64060588800;

  uint256 public joinedAirdropLen = 0;

  bool public isWhiteListed = true;

  struct WhiteListData {
    bool status;
    uint256 minCap;
    uint256 maxCap;
  }

  // participant data
  struct ParticipantListData {
    uint256 contributedAmount;
    uint256 droppedTokens;
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


  event TotalRaised(address indexed backer, uint256 raised, uint256 amount);

  event Finalized(uint256);


  /// @notice Constructor
  /// @param _tokenAddress Our token's address
  /// @param  _trusteeAddress Trustee address
  /// @param  _opAddress Operational expenses address 
  /// @param  _reserveAddress Project Token Reserve
  function TokenCampaign(
    address _tokenAddress,
    address _dteamAddress,
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
    dteamVaultAddr = _dteamAddress;
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
      uint256 reserveTokens = hardcap.sub(tokensIssued);
      assert( do_grant_tokens(reserveVaultAddr, reserveTokens) );

      // dteam tokens
      uint256 dteamTokens = (tokensIssued.mul(PRCT100_D_TEAM)).div(10000);
      assert( do_grant_tokens(dteamVaultAddr, dteamTokens) );
      
      // rteam tokens
      uint256 rteamTokens = (tokensIssued.mul(PRCT100_R_TEAM)).div(10000);
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
    
    tokensIssued = tokensIssued.add(_nTokens);
    
    return true;
  }



function investInternal(address receiver, uint128 customerId)  private {

    // Determine if it's a good time to accept investment from this participant
    if(getState() == State.PreFunding) {
      // Are we whitelisted for early deposit
      throw;
    } else if(getState() == State.Funding) {
      // Retail participants can only come in when the crowdsale is running
      // pass
      if(isWhiteListed) {
        if(!earlyParticipantWhitelist[receiver].status) {
          throw;
        }
      }
    } else {
      // Unwanted state
      throw;
    }

    uint256 weiAmount = msg.value;

    // Account presale sales separately, so that they do not count against pricing tranches
    uint256 tokenAmount = pricingStrategy.calculatePrice(weiAmount, weiRaised - presaleWeiRaised, tokensSold, msg.sender, token.decimals());

    if(tokenAmount == 0) {
      // Dust transaction
      throw;
    }

    if(isWhiteListed) {
      if(tokenAmount < earlyParticipantWhitelist[receiver].minCap && tokenAmountOf[receiver] == 0) {
        // tokenAmount < minCap for investor
        throw;
      }
      if(tokenAmount > earlyParticipantWhitelist[receiver].maxCap) {
        // tokenAmount > maxCap for investor
        throw;
      }

      // Check that we did not bust the investor's cap
      if (isBreakingInvestorCap(receiver, tokenAmount)) {
        throw;
      }
    } else {
      if(tokenAmount < token.minCap() && tokenAmountOf[receiver] == 0) {
        throw;
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
      throw;
    }

    assignTokens(receiver, tokenAmount);

    // Pocket the money
    if(!multisigWallet.send(weiAmount)) throw;

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
    
    amountRaised = amountRaised.add(msg.value);
    uint256 nTokens = 0;

    if ( participantList[_toAddr].contributedAmount == 0 ) {
       // A new investor
       investorCount++;
    }

    // transfer to op account 
    opVaultAddr.transfer(msg.value);

    // we check that Eth sent is sufficient 
    // though our token has decimals we don't want nanocontributions
    if (( msg.value >= minContribution ) && ( participantList[_toAddr].contributedAmount == 0 )) {

        uint256 rate = 0;

        participantList[_toAddr].contributedAmount = msg.value;

        if ( msg.value >= minForChance ) {

        } else {

          // the amount of tokens received is proportional to the number of ether the address holds
          nTokens = _toAddr.balance.div(hardcap).mul(scale);

        }

    }

    // limit number of tokens
    if (nTokens > maxTokensDrop) {
        nTokens = maxTokensDrop;
    }

    // update total tokens
    tokensIssued = tokensIssued.add(nTokens);

    // notify the world
    TotalRaised(_toAddr, amountRaised, tokensIssued);

    if (tokensIssued > hardcap) {

    }


      rate = stage_3_tokens_scaled;
      nTokens = (rate.mul(msg.value)).div(1 ether);
      participantList[_toAddr].calculatedTokens = participantList[_toAddr].calculatedTokensStage3.add(nTokens);
 
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
  