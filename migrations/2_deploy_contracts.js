var colors = require('colors/safe');

var Token = artifacts.require("EatMeCoin");
var Campaign = artifacts.require("TokenCampaign");
var TokenFactory = artifacts.require("MiniMeTokenFactory");

// addresses in our private test net
// CHANGE before deploy

var issuerAddr = 	'0x627306090abaB3A6e1400e9345bC60c78a8BEf57'; // test account 1
var dteamAddr1 = 	'0xf17f52151EbEF6C7334FAD080c5704D77216b732'; // test account 2
var dteamAddr2 = 	'0xf17f52151EbEF6C7334FAD080c5704D77216b732';
var dteamAddr3 = 	'0xf17f52151EbEF6C7334FAD080c5704D77216b732';
var dteamAddr4 = 	'0xf17f52151EbEF6C7334FAD080c5704D77216b732';
var rteamAddress = 	'0x2932b7A2355D6fecc4b5c0B6BD44cC31df247a2e'; // test account 6
var rjdgAddress = 	'0x0F4F2Ac550A1b4e2280d04c21cEa7EBD822934b5'; // test account 8
var mmAddress = 	'0x6330A553Fc93768F612722BB8c2eC78aC90B3bbc'; // test account 9
var trusteeAddr = 	'0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef'; // test account 3
var opAddr = 		'0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2'; // test account 5
var reserveAddr = 	'0x821aEa9a577a9b44299B9c15c88cf3087F3b5544'; // test account 4

// need them globaly
var tokenAddr;
var campaignAddr;

module.exports = function(deployer, network, accounts) {

	var controller = issuerAddr;
	var token_version = 1;

	console.log(colors.black.bgYellow("The network is " + network));
	console.log("The token contract will be issued from address " + issuerAddr);
	
	// deploy Token Factory contract
	deployer.deploy(TokenFactory)
		.then(
			function(){
				var tokenFactoryAddr = TokenFactory.address;
				console.log(colors.yellow.bold("##! Token factory contract deployed at " + tokenFactoryAddr));
				// deploy Token contract
				return deployer.deploy(Token, 
					tokenFactoryAddr);})
		.then(
			function(){
				tokenAddr = Token.address;
				console.log(colors.yellow.bold("##! Token  contract deployed at " + tokenAddr));
				// deploy Token Factory contract
				return deployer.deploy(Campaign, 
					tokenAddr,
					dteamAddr1,
					dteamAddr2,
					dteamAddr3,
					dteamAddr4,
					rteamAddress,
					rjdgAddress,
					mmAddress,
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

