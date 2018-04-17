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
	var preCrowdThreshold,goal;
	var trustee, op, reserve, team;
	var tokenAddr;
	var raised, available, generated;
	var rate;
	var state;
	var minc;
	var isPaused;
	var tEnd, presaleEnd;

	
	TokenCampaign.deployed().then(
		function(instance){
			console.log(colors.blue("# Campaign at " + instance.address))
			campaign = instance;
		})
		.then(
			function(){
				return Promise.all([

					campaign.preCrowdTokenThreshold.call().then(
						(x)=>{preCrowdThreshold = x}),

					campaign.reserveVaultAddr.call().then(
						(x)=>{reserve = x}),

					campaign.opVaultAddr.call().then(
						(x)=>{op = x}),

					campaign.trusteeVaultAddr.call().then(
						(x)=>{trustee = x}),

					campaign.tokenAddr.call().then(
						(x)=>{tokenAddr = x}),

					campaign.paused.call().then(
						(x)=>{isPaused = x}),

					campaign.tPreCrowdStageEnd.call().then(
						(x)=>{presaleEnd = x}),

					campaign.teamVaultAddr.call().then(
						(x)=>{team = x}),

					campaign.decimals.call().then(
						(x)=>{decimals = x}),

					campaign.scale.call().then(
						(x)=>{scale = x}),

					campaign.minContribution.call().then(
						(x)=>{minc = x/1000000000000000000}),

					campaign.get_rate.call().then(
						(x)=>{rate = x}),

					campaign.tCampaignEnd.call().then(
						(x)=>{tEnd = x}),

					campaign.tokensGenerated.call().then(
						(x)=>{generated = x}),

					campaign.amountRaised.call().then(
						(x)=>{raised = x/1000000000000000000}),

					campaign.campaignState.call().then(
						(x)=>{state = x})])
			})
		.then(
			function(){

				console.log(colors.white.bold("# Campaign State: " + state + " - (" + stateNames[state] +")"));
				console.log(" Paused: " + isPaused);
				console.log(" Parameters:")
				console.log("   Token: " + tokenAddr);
				console.log("      Decimals: " + decimals );
				console.log("      Scale:" + scale);
				console.log("   Trustee: " + trustee)	;	
				console.log("   Bounty: " + reserve);
				console.log("   Team: " + team);	
				console.log("   Bounty: " + reserve);
				
				console.log(" Presale threshold: " + preCrowdThreshold/scale );
				var secondsLeft = (presaleEnd - Date.now()/1000);
				var minutesLeft = secondsLeft/60;
				var hoursLeft = minutesLeft/60
				console.log(" Presale ends: " + presaleEnd + "( in " + minutesLeft + " minutes)" );
				console.log(" Presale goal reached: " + goal);

				console.log(" Min contribution: " + minc );
				console.log(" Generated Tokens: " + generated/scale );
				console.log(" Current rate:" + rate/scale);
				console.log(" Funds raised: " + raised);
				secondsLeft = (tEnd - Date.now()/1000);
				minutesLeft = secondsLeft/60;
				hoursLeft = minutesLeft/60
				console.log(" Ends : " + tEnd + " (" + (tEnd - Date.now()/1000) + " = " + minutesLeft + " minutes )" );

				//console.log("   Allow generate: " + allowGen);	
			});  		
} 	



