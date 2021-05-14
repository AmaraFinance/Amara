let mainAddress = "";
let parseEther = require("ethers").utils.parseEther;


const Unitroller = artifacts.require("./Unitroller.sol");

module.exports = function (deployer,network, accounts) {
  mainAddress = accounts[0];
  console.log(mainAddress, network);
  deployer.deploy(Unitroller); 
};