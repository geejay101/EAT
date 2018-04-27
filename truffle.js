var HDWalletProvider = require("truffle-hdwallet-provider");



module.exports = {
	networks: {

		development: {
		  host: "127.0.0.1",
		  port: 9545,
		  network_id: "*" // Match any network id
		},

		ropsten: {
		  provider: function() {
		    return new HDWalletProvider(mnemonic, "https://ropsten.infura.io/2hV3PJPq2W35VyIh61lf")
		  },
		  network_id: 3,
		  gas: 3141592,
		  gasPrice: 3000000000 // 3 Gwei
		},

		rinkeby: {
		  provider: function() {
		    return new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/2hV3PJPq2W35VyIh61lf")
		  },
		  network_id: 4,
		  gas: 7000000,
		  gasPrice: 3100000000 // 3 Gwei
		},

		ganache: {
		  host: "127.0.0.1",
		  port: 7545,
		  network_id: "*", // Match any network id,
		  gas: 4700000,
		  gasPrice: 3000000000 // 3 Gwei
		}   
	},
	solc: {
		optimizer: {
			enabled: true,
			runs: 200
		}
	},
};
