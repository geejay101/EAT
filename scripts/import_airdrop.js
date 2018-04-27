var fs = require('fs');
var csv = require('fast-csv');
var BigNumber = require('bignumber.js');

let polyDistributionAddress = process.argv.slice(2)[0];
let BATCH_SIZE = process.argv.slice(2)[1];
if(!BATCH_SIZE) BATCH_SIZE = 80;
let distribData = new Array();
let allocData = new Array();

function readFile() {
  var stream = fs.createReadStream("scripts/data/airdrop.csv");

let index = 0;
let batch = 0;

console.log(`
    --------------------------------------------
    --------- Parsing distrib.csv file ---------
    --------------------------------------------

******** Removing beneficiaries without address data
  `);

var csvStream = csv()
      .on("data", function(data){
          let isAddress = web3.utils.isAddress(data[0]);
          if(isAddress && data[0]!=null && data[0]!='' ){
            allocData.push(data[0]);

index++;
            if(index >= BATCH_SIZE)
            {
              distribData.push(allocData);
              allocData = [];
              index = 0;
            }

}
      })
      .on("end", function(){
           //Add last remainder batch
           distribData.push(allocData);
           allocData = [];
           setAllocation();
      });

  stream.pipe(csvStream);
}

if(polyDistributionAddress){
  console.log("Processing airdrop. Batch size is",BATCH_SIZE, "accounts per transaction");
  readFile();
}else{
  console.log("Please run the script by providing the address of the PolyDistribution contract");
}