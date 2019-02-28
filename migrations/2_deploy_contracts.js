var ADGZToken = artifacts.require("ADGZToken");

module.exports = function(deployer, network, accounts) {

    return deployer.deploy(ADGZToken).then(() => {
            return ADGZToken.deployed()
    })
};