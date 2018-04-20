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
	
	TokenCampaign.deployed()
		.then(
			function(campaign){
				console.log(colors.red("# Campaign at " + campaign.address))
				return campaign.finalizeCampaign();})
		.then(
			function(res){

				console.log(" return code: " + res );

			});  		
} 	



