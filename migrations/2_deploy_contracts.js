var HelussToken = artifacts.require("HelussToken");

module.exports = function(deployer, network, accounts) {

    return deployer.deploy(HelussToken).then(() => {
            return HelussToken.deployed()
    })
};