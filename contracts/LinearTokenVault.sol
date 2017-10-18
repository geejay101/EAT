pragma solidity ^0.4.13;




/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


/// Copyright 2017, Pavel Metelitsyn


import "./MiniMeToken.sol";
import "./library.sol";



// simple time locked vault allows controlled extraction of tokens during a period of time
// at construction we pass the duration and number of extractions
// 
//
//



// Controlled is implemented in MiniMeToken.sol
contract TokenVault is Controlled {
	using SafeMath for uint256;


	//struct benificiary{
//
//	}

	address campaignAddr;
	uint256 tUnlock = 0;
	uint256 tDuration;
	MiniMeToken token;

	uint256 extracted = 0;

	event Extract(address indexed _to, uint256 _amount);

	function TokenVault(
		address _tokenAddress,
	 	address _campaignAddress,
	 	uint256 _tDuration
	 	) {

			require( _tDuration > 0);
			tDuration = _tDuration;

			campaignAddr = _campaignAddress;
			token = MiniMeToken(_tokenAddress);
		}

	/// sale campaign calls this function to set the time lock
	/// @param _tUnlock - Unix timestamp of the first date 
	///							on which tokens become available
	function setTimeLock(uint256 _tUnlock){
		// prevent change of the timestamp by anybody other than token sale contract
		// once unlock time is set it cannot be changed
		require( (msg.sender == campaignAddr) &&
						 (tUnlock == 0));
		tUnlock = _tUnlock;
	}

	/// @notice Send all available tokens to a given address
	function extract(address _to) onlyController {
		
		require (_to != 0x0);

		uint256 available = availableNow();
	
		require( available > 0 );

		extracted = extracted.add(available);
		assert( token.transfer(_to, available) );
		

		Extract(_to, available);

	}

	// returns amount of tokens held in this vault
	function balance() returns (uint256){
		return token.balanceOf(address(this));
	}


	// returns amount of tokens available for extraction now
	function availableNow() returns (uint256){

		uint256 tNow = now;

		// if before unlock time or unlock time is not set  => 0 is available 
		if (tNow < tUnlock && tUnlock == 0) { return 0; }

		uint256 remaining = balance();

		// if after longer than tDuration since unlock time => everything that is left is available
		if (tNow > tUnlock + tDuration) { return remaining; }

		// otherwise:
		// compute how many extractions remaining based on time 



		uint256 dt = (tNow.sub(tUnlock)).div(tDuration);
		return (remaining.add(extracted)).mul(dt).sub(extracted);
	}

}