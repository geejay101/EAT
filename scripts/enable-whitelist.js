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

	TokenCampaign.deployed().then(function(instance){
			console.log(colors.red("# Campaign at " + instance.address))
			console.log(colors.red("enabling whitelisting"))
			campaign = instance;
			return campaign.toggleWhitelist(true)
		})
		.then(function(returnCode) {
				console.log(colors.green(" Success: " + returnCode ));
		}).catch(function(e) {
				console.log(colors.red(" Error: " + returnCode ));
		}); 
}


