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
			console.log(colors.blue("# Campaign at " + instance.address))
			campaign = instance;
		})
		.then(
			function(){
				return Promise.all([

					campaign.controller.call().then(
						(x)=>{issuer = x}),

					campaign.reserveVaultAddr.call().then(
						(x)=>{reserve = x}),

					campaign.opVaultAddr.call().then(
						(x)=>{operator = x}),

					campaign.trusteeVaultAddr.call().then(
						(x)=>{trustee = x}),

					campaign.tokenAddr.call().then(
						(x)=>{tokenAddr = x}),

					campaign.paused.call().then(
						(x)=>{isPaused = x}),

					campaign.t_1st_StageEnd.call().then(
						(x)=>{stage_1_End = x}),

					campaign.t_2nd_StageEnd.call().then(
						(x)=>{stage_2_End = x}),

					campaign.tCampaignEnd.call().then(
						(x)=>{tEnd = x}),

					campaign.decimals.call().then(
						(x)=>{decimals = x}),

					campaign.scale.call().then(
						(x)=>{scale = x}),

					campaign.tokensGenerated.call().then(
						(x)=>{generated = x}),

					campaign.amountRaised.call().then(
						(x)=>{raised = x/1000000000000000000}),

					campaign.contractBalance.call().then(
						(x)=>{balance = x/1000000000000000000}),

					campaign.campaignState.call().then(
						(x)=>{state = x}),

					campaign.investorCount.call().then(
						(x)=>{investors = x}),

					campaign.investorsBatchSize.call().then(
						(x)=>{batchsize = x}),

					campaign.investorsProcessed.call().then(
						(x)=>{investorsprocessed = x}),

					campaign.isWhiteListed.call().then(
						(x)=>{isWhiteListing = x})
					])
			})
		.then(
			function(){

				console.log(colors.white.bold("# Campaign State: " + state + " - (" + stateNames[state] +")"));
				console.log(" Paused: " + isPaused);
				console.log(" Whitelist enabled: " + isWhiteListing);
				console.log(" Parameters:")
				console.log("   Token: " + tokenAddr);
				console.log("      Decimals: " + decimals );
				console.log("      Scale:" + scale);
				console.log("   Issuer: " + issuer);
				console.log("   Trustee: " + trustee)	;	
				console.log("   Reserve: " + reserve);
				console.log("   Operator: " + operator);
				
				var secondsLeft = (stage_1_End - Date.now()/1000);
				var minutesLeft = secondsLeft/60;
				var hoursLeft = minutesLeft/60
				console.log(" Stage 1 ends: " + stage_1_End + "( in " + minutesLeft + " minutes)" );

				var secondsLeft = (stage_2_End - Date.now()/1000);
				var minutesLeft = secondsLeft/60;
				var hoursLeft = minutesLeft/60
				console.log(" Stage 2 ends: " + stage_2_End + "( in " + minutesLeft + " minutes)" );

				secondsLeft = (tEnd - Date.now()/1000);
				minutesLeft = secondsLeft/60;
				hoursLeft = minutesLeft/60
				console.log(" Ends : " + tEnd + " (" + (tEnd - Date.now()/1000) + " = " + minutesLeft + " minutes )" );

				console.log(" Generated Tokens: " + generated/scale );
				console.log(" Funds raised: " + raised);
				console.log(" Contract balance: " + balance);

				console.log(" Investors: " + investors);
				console.log(" Investors Batch Size: " + batchsize);
				console.log(" Investors processed: " + investorsprocessed);



			});  		
} 	



