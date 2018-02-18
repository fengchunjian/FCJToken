var FCJToken = artifacts.require("./FCJToken.sol")
module.exports = function(deployer) {
  deployer.deploy(FCJToken);
};
