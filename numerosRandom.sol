pragma solidity >=0.8.0;

// SPDX-License-Identifier: Apache 2.0 
contract RandomNumber{
 
    // Initializing the state variable
    uint randNonce = 0;
     
    // Defining a function to generate
    // a random number
    function randMod(uint _modulus) public returns(uint){
       // increase nonce
       randNonce++; 
       return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _modulus;
     }
}