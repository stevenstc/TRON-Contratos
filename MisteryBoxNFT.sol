pragma solidity >=0.8.0;

// SPDX-License-Identifier: Apache-2.0 

interface ITRC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
}

contract dinamicArray{
    
    function actualizarArray(address[] memory oldArray)public pure returns ( address[] memory) {

        //añade un espacio para un nuevo dato
        address[] memory newArray =   new address[](oldArray.length+1);
    
        for(uint i = 0; i < oldArray.length; i++){
            newArray[i] = oldArray[i];
        }
        
        return newArray;
    }

    function borrarArray(address[] memory oldArray)public pure returns ( address[] memory) {

        //borra los espacios que esten con address(0)
        address[] memory newArray;
        uint largo;

        for(uint i = 0; i < oldArray.length; i++){
            if(oldArray[i] != address(0)){
                newArray = actualizarArray(newArray);
                newArray[largo] = oldArray[i];
                largo++;
            }
        }
        
        return newArray;
    }
    
  
  function example() public pure returns(address[] memory){
      address[] memory network;
      
      network = actualizarArray(network);

      network[0] = address(1);

      network = actualizarArray(network);

      network[1] = address(2);
      
      return network;
  }

  function example2() public pure returns(address[] memory){
      address[] memory network = example();
      
      network = borrarArray(network);

      network[0] = address(0);
      
      return network;
  }
  
}

contract RandomNumber{
 
    // Initializing the state variable
    uint randNonce = 0;
     
    // Defining a function to generate
    // a random number
    function randMod(uint _modulus, uint _moreRandom) public view returns(uint){
       
       return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce, _moreRandom))) % _modulus;
    }

    function doneRandom() public {
      // increase nonce
       randNonce++; 

    }
}