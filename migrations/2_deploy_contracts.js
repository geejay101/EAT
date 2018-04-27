var colors = require('colors/safe');

var Token = artifacts.require("EatMeCoin");
var Campaign = artifacts.require("TokenCampaign");
var TokenFactory = artifacts.require("MiniMeTokenFactory");

// addresses in our private test net
// CHANGE before deploy

var issuerAddr = 	'0x8c45cC725024DFDCc46E12afA364efabd266E648'; // test account 1
var dteamAddr1 = 	'0x02e5496C52a92C6086424418e3EC08997D01549D'; //x
var dteamAddr2 = 	'0x1d247AA35E722A25e1ac8210895f2BFCebD1f7Ce'; //x
var dteamAddr3 = 	'0xC6ce19A1690f4a949bc71bEEfcBd227A52b13987'; //x
var dteamAddr4 = 	'0xb80B6F95C7711caD4FA62a8C65891F58b25E6eA8'; //x
var rteamAddress = 	'0xeBe98C1d09EBd3e994f82fA72071f2604f4F9452'; //x
var r2Address = 	'0x18899838A2d38353fDa812E67c9b448777F16337'; //x
var mmAddress = 	'0x5cbb15e9fd72e6483ad61e7d692551019ff477c3'; //x
var trusteeAddr = 	'0x0aA973F3cBd41E97e4655b4A777A72956483bA0f'; //x
var opAddr = 		'0xEa73fa8249Cf85Ab0f0EbFBC18788Ef5fB155FFc'; //x
var reserveAddr = 	'0x0aA973F3cBd41E97e4655b4A777A72956483bA0f'; //x

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
					r2Address,
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

