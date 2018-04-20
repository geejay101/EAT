// Print info
var colors = require('colors/safe');

var TokenCampaign = artifacts.require("TokenCampaign");	

var stateNames = ["finalized, not accepting funds",
				  "closed, not accepting funds", 
				  "active, main sale, accepting funds",
				  "active, pre-sale ?",
				  "passive, not accepting funds"]; 


module.exports = function(callback){
	var campaign;
	
	TokenCampaign.deployed().then(
		function(instance){
			console.log(colors.red("# Campaign at " + instance.address))
			campaign = instance;
			return campaign.startSale()})
		.then(
			function(returnCode){
				
				console.log(" return code: " + returnCode );

			});  		
} 	



