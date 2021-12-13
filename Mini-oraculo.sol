pragma solidity >=0.8.0;

// SPDX-License-Identifier: Apache-2.0 
contract MiniOraculo{

    address public oracler;
    uint private p_TRX;
    uint private d_cimals = 6;
    uint private utimo_envio = 0;


    constructor(){
      oracler = msg.sender;
    }
 
    function setPrecio(uint _precio) public {
       if(oracler != msg.sender)revert("no oracler");
       utimo_envio = block.timestamp;
       p_TRX = _precio;
    }

    function setNewOwner(address _newOwner) public {
       if(oracler != msg.sender)revert("no oracler");
       oracler = _newOwner;
    }

    function precioTRX() public view returns(uint){
      return p_TRX;
    }

    function decimales() public view returns(uint){
      return d_cimals;
    }

    function last() public view returns(uint){
      return utimo_envio;
    }

    function consulta() public view returns( uint value, uint timestamp){

      return (p_TRX, utimo_envio);
    }
}