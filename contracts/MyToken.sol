// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";



/**
 * @title 本地测试用的 erc20 token 合约
 * @author 
 * @notice 
 */
contract MyToken is ERC20{
    address public owner;

    constructor(string memory _symbol,string memory _name,uint256 maxSupply) ERC20(_symbol,_name){
        owner = msg.sender;
        _mint(owner,maxSupply * 10 ** 18);
    }
}