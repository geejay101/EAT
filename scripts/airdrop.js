// Print info
var colors = require('colors/safe');

//var args = process.argv.slice(2);
var args = require('minimist')(process.argv.slice(2),
{
  string: [ 'investor' ]
});

var investor = args['investor'];
var tokens = args['tokens'];

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
			console.log(colors.red("Airdrop Token"))
			console.log(colors.grey("Airdropping: " + investor + " - " + tokens ))

			campaign = instance;
			return campaign.airdrop(investor, tokens)
		})
		.then(function(returnCode) {
				console.log(colors.green(" Success: " + returnCode ));
				console.log(colors.green(" Airdropped: " + investor + " - " + tokens ));

		}).catch(function(e) {
				console.log(colors.red(" Error: " + returnCode ));
		}); 
}
