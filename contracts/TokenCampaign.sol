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
  function generate_token_for(address _addr,uint _amount) returns (bool);
  function finalize();
}


// Controlled is implemented in MiniMeToken.sol
contract TokenCampaign is Controlled{
  using SafeMath for uint256;

  // this is our token
  eat_token_interface public token;

  ///////////////////////////////////
  //
  // constants related to token sale

  // after slae ends, additional tokens will be generated
  // according to the following rules,
  // where 100% correspond to the number of sold tokens

  // percent of tokens to be generated for the team
  uint256 public constant PRCT_TEAM = 10;

  // we keep half of the ETH in the contract until the sale is finalized
  // percent of ETH going to operational account
  uint256 public constant PRCT_ETH_OP = 50;

  uint8 public constant decimals = 18;
  uint256 public constant scale = (uint256(10) ** decimals);


  // how many tokens for one ETH
  // we may adjust this number before deployment based on the market conditions
  uint256 public constant baseRate = 50; //<-- unscaled

  // we want to limit the number of available tokens during the bonus stage 
  // payments during the bonus stage will not be accepted after the TokenTreshold is reached or exceeded
  // we may adjust this number before deployment based on the market conditions

  uint256 public constant bonusTokenThreshold = 200000 * scale ; //<--- new 
  uint256 public constant crowdTokenThreshold = 800000 * scale ; //<--- new 

  uint256 public constant hardcap = 1000000 * scale ; //<--- new 


  // minmal contribution, Wei
  uint256 public constant minContribution = (5 ether) / 100;

  // maximal contribution, Wei
  // uint256 public constant maxContribution = (10 ether);

  // bonus structure, Wei
  uint256 public constant bonusMinContribution = (10 ether);

  // 
  uint256 public constant bonus_stage_tokens = 70; // 30% bonus
  uint256 public constant stage_1_tokens = 60;// 20% bonus
  uint256 public constant stage_2_tokens = 55;// 10% bonus
  
  ////////////////////////////////////////////////////////
  //
  // folowing addresses need to be set in the constructor
  // we also have setter functions which allow to change
  // an address if it is compromised or something happens

  // destination for team's share
  address public teamVaultAddr;
  
  // destination for reward tokens
  address public reserveVaultAddr;

  // destination for collected Ether
  address public trusteeVaultAddr;
  
  // destination for operational costs account
  address public opVaultAddr;
  

  // adress of our token
  address public tokenAddr;

  
  /////////////////////////////////
  // Realted to Campaign


  // @check ensure that state transitions are 
  // only in one direction
  // 4 - passive, not accepting funds
  // 3 - is not used
  // 2 - active main sale, accepting funds
  // 1 - closed, not accepting funds 
  // 0 - finalized, not accepting funds
  uint8 public campaignState = 4; 
  bool public paused = false;

  // keeps track of tokens generated so far, scaled value
  uint256 public tokensGenerated = 0;

  // total Ether raised (= Ether paid into the contract)
  uint256 public amountRaised = 0; 

  // time in seconds since epoch 
  // set to midnight of saturday January 1st, 4000
  uint256 public tCampaignStart = 64060588800;
  uint256 public tBonusStageEnd = 7 * (1 days);
  uint256 public tRegSaleStart = 8 * (1 days);
  uint256 public t_1st_StageEnd = 15 * (1 days);
  uint256 public t_2nd_StageEnd = 22* (1 days);
  uint256 public tCampaignEnd = 38 * (1 days);
  uint256 public tFinalized = 64060588800;


  bool public isWhiteListed;

  struct WhiteListData {
    bool status;
    uint minCap;
    uint maxCap;
  }

  /** Whitelisted addresses */
  mapping (address => WhiteListData) public participantWhitelist;

  //////////////////////////////////////////////
  //
  // Events
 
  event CampaignOpen(uint256);
  event CampaignClosed(uint256);
  event CampaignPausd(uint256);
  event CampaignResumed(uint256);
  event TokenGranted(address indexed backer, uint amount, string ref);
  event TokenGranted(address indexed backer, uint amount);
  event TotalRaised(uint raised);
  event Finalized(uint256);
  event ClaimedTokens(address indexed _token, address indexed _controller, uint _amount);

  // Address early participation whitelist status changed
  event Whitelisted(address addr, bool status);



  /// @notice Constructor
  /// @param _tokenAddress Our token's address
  /// @param  _trusteeAddress Trustee address
  /// @param  _opAddress Operational expenses address 
  /// @param  _reserveAddress Project Token Reserve
  function TokenCampaign(
    address _tokenAddress,
    address _teamAddress,
    address _trusteeAddress,
    address _opAddress,
    address _reserveAddress)
  {

    controller = msg.sender;
    
    /// set addresses     
    tokenAddr = _tokenAddress;
    teamVaultAddr = _teamAddress;
    trusteeVaultAddr = _trusteeAddress; 
    opVaultAddr = _opAddress;
    reserveVaultAddr = _reserveAddress;

    /// reference our token
    token = eat_token_interface(tokenAddr);
   
    // adjust 'constants' for decimals used
    // decimals = token.decimals(); // should be 18
   
  }


  //////////////////////////////////////////////////
  ///
  /// Functions that do not change contract state
  function get_presale_goal() constant returns (bool){
    if ((now <= tBonusStageEnd) && (tokensGenerated >= bonusTokenThreshold)){
      return true;
    } else {
      return false;
    }
  }

  /// @notice computes the current rate
  ///  according to time passed since the start
  /// @return amount of tokens per ETH
  function get_rate() constant returns (uint256){
    
    // obviously one gets 0 tokens
    // if campaign not yet started
    // or is already over
    if (now < tCampaignStart) return 0;
    if (now > tCampaignEnd) return 0;
    
    // compute rate per ETH based on time
    // assumes that time marks are increasing
    // from tBonusStageEnd through t_2nd_StageEnd
    // adjust by factor 'scale' depending on token's decimals
    // NOTE: can't cause overflow since all numbers are known at compile time
    if (now <= tBonusStageEnd)
      return scale * (bonus_stage_tokens);

    if (now <= t_1st_StageEnd)
      return scale * (stage_1_tokens);
    
    else if (now <= t_2nd_StageEnd)
      return scale * (stage_2_tokens);

    else 
      return baseRate * scale; 
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
    tBonusStageEnd += tNow;
    tRegSaleStart += tNow;
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
    CampaignPausd(now);
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


  function setParticipantWhitelist(address addr, bool status, uint minCap, uint maxCap) onlyOwner {
    if (!isWhiteListed) throw;
    participantWhitelist[addr] = WhiteListData({status:status, minCap:minCap, maxCap:maxCap});
    Whitelisted(addr, status);
  }

  function setMultipleParticipantWhitelist(address[] addrs, bool[] statuses, uint[] minCaps, uint[] maxCaps) onlyOwner {
    if (!isWhiteListed) throw;
    for (uint iterator = 0; iterator < addrs.length; iterator++) {
      setParticipantWhitelist(addrs[iterator], statuses[iterator], minCaps[iterator], maxCaps[iterator]);
    }
  }

  function updateParticipantWhitelist(address addr, address contractAddr, uint tokensBought) {
    if (tokensBought < participantWhitelist[addr].minCap) throw;
    if (!isWhiteListed) throw;
    if (addr != msg.sender && contractAddr != msg.sender) throw;
    uint newMaxCap = participantWhitelist[addr].maxCap;
    newMaxCap = newMaxCap.minus(tokensBought);
    participantWhitelist[addr] = WhiteListData({status:participantWhitelist[addr].status, minCap:0, maxCap:newMaxCap});
  }

  /// @notice Finalizes the campaign
  ///   Get funds out, generates team, reserve and reserve tokens
  function finalizeCampaign() public {     
      
      /// only if sale was closed or 48 hours = 2880 minutes have passed since campaign end
      /// we leave this time to complete possibly pending orders
      /// from offchain contributions 
      
      require ( (campaignState == 1) ||
                ((campaignState != 0) && (now > tCampaignEnd + (2880 minutes))));
      
      campaignState = 0;

     

      // forward funds to the trustee 
      // since we forward a fraction of the incomming ether on every contribution
      // 'amountRaised' IS NOT equal to the contract's balance
      // we use 'this.balance' instead

      trusteeVaultAddr.transfer(this.balance);
      
      
      // uint256 reserveTokens = (tokensGenerated.mul(PRCT_RESERVE)).div(100);

      uint256 reserveTokens = hardcap.sub(tokensGenerated);
      
      uint256 teamTokens = (tokensGenerated.mul(PRCT_TEAM)).div(100);
      
      // generate reserve tokens 
      assert( do_grant_tokens(reserveVaultAddr, reserveTokens) );


      // generate team tokens
      tFinalized = now;

      // generate all the tokens
      assert( do_grant_tokens(teamVaultAddr, teamTokens) );
      
      // prevent further token generation
      token.finalize();


      // 
      if (isWhiteListed) {
        uint num = 0;
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

      // notify the world
      Finalized(tFinalized);
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
      

    // contributions are not possible before regular sale starts 
    if ( (now > tBonusStageEnd) && //<--- new
         (now < tRegSaleStart)){ //<--- new
      revert(); //<--- new
    }

    // during the bonus phase we require a minimal eth contribution 
    if ((now <= tBonusStageEnd) && 
        ((msg.value < bonusMinContribution ) ||
        (tokensGenerated >= bonusTokenThreshold))) //<--- new, revert if bonusThreshold is exceeded 
    {
      revert();
    }     

    if ((now <= tCampaignEnd) && 
        (tokensGenerated >= crowdTokenThreshold)) //<--- new, revert if crowdTokenThreshold is exceeded 
    {
      revert();
    }    
    
  
    // otherwise we check that Eth sent is sufficient to generate at least one token
    // though our token has decimals we don't want nanocontributions
    require ( msg.value >= minContribution );

    // we are capping the max contribution
    // require ( msg.value <= maxContribution );


    // compute the rate
    // NOTE: rate is scaled to account for token decimals
    uint256 rate = get_rate();
    
    // compute the amount of tokens to be generated
    uint256 nTokens = (rate.mul(msg.value)).div(1 ether);
    
    // compute the fraction of ETH going to op account
    uint256 opEth = (PRCT_ETH_OP.mul(msg.value)).div(100);

    // transfer to op account 
    opVaultAddr.transfer(opEth);
    
    // @todo check success (NOTE we have no cap now so success is assumed)
    // side effect: do_grant_tokens updates the "tokensGenerated" variable
    require( do_grant_tokens(_toAddr, nTokens) );

    amountRaised = amountRaised.add(msg.value);
    
    // notify the world
    TokenGranted(_toAddr, nTokens);
    TotalRaised(amountRaised);
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
     
     // if (_token == 0x0) {
     //     controller.transfer(this.balance);
     //     return;
     // }

      ERC20Basic some_token = ERC20Basic(_tokenAddr);
      uint balance = some_token.balanceOf(this);
      some_token.transfer(controller, balance);
      ClaimedTokens(_tokenAddr, controller, balance);
  }
}
  