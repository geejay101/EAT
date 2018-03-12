var colors = require('colors/safe');

var Token = artifacts.require("EatMeCoin");
var Campaign = artifacts.require("TokenCampaign");
var TokenFactory = artifacts.require("MiniMeTokenFactory");

// addresses in our private test net
// CHANGE before deploy

var issuerAddr = '0x627306090abaB3A6e1400e9345bC60c78a8BEf57';
var teamAddr = '0xf17f52151EbEF6C7334FAD080c5704D77216b732';
var trusteeAddr = '0xc5fdf4076b8f3a5357c5e395ab970b5b54098fef';
var reserveAddr = '0x821aea9a577a9b44299b9c15c88cf3087f3b5544';
var opAddr = '0x0d1d4e623d10f9fba5db95830f7d3839406c6af2';

// in seconds        s    m    h    d   m 
var tLockDuration = 60 * 60 * 24 * 30 * 1; //1 month
//var tLockDuration = 60 * 30; // 30 minutes for testing


// need them globaly
var tokenAddr;
var campaignAddr;

module.exports = function(deployer, network, accounts) {
	var issuer = issuerAddr;
	var team = teamAddr;
	var trustee = trusteeAddr;
	var controller = issuer;
	var token_version = 1;

	console.log(colors.black.bgYellow("The network is " + network));
	

	console.log("The token contract will be issued from address " + issuer);
	console.log("Setting team address to " + team);
	console.log("Setting trustee address to " + trustee);
	console.log("Setting campaign controller to " + controller);
	
	// deploy Token Factory contract
	deployer.deploy(TokenFactory)
		.then(
			function(){
				var tokenFactoryAddr = TokenFactory.address;
				console.log(colors.yellow.bold("##! Token factory contract deployed at " + tokenFactoryAddr));
				// deploy Token contract
				return deployer.deploy(Token, tokenFactoryAddr);})
		.then(
			function(){
				tokenAddr = Token.address;
				console.log(colors.yellow.bold("##! Token  contract deployed at " + tokenAddr));
				// deploy Token Factory contract
				return deployer.deploy(Campaign, 
					tokenAddr,
					teamAddr,
					trusteeAddr,
					opAddr,
					reserveAddr);})
		.then(
			function(){
				campaignAddr = Campaign.address;
				console.log(colors.yellow.bold("##! Campaign contract deployed at \n    " + campaignAddr));
				console.log("Performing post deploy actions...")
			  
			  Token.at(tokenAddr).then(
						function(instance){
							instance.setGenerateAddr(campaignAddr);})});};

