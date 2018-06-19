/**
 * Created by Narcis2007 on 12.05.2018.
 */
var ICOToken = artifacts.require("ICOToken");

module.exports = function(deployer, network, accounts) {

    return deployer.deploy(ICOToken, "Test Token", "TST", 8, 100, { from: accounts[0], gas: 4700000 }).then(() => {
            return ICOToken.deployed()
    })
};