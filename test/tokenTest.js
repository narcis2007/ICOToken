/**
 * Created by Narcis2007 on 12.05.2018.
 */
'use strict';

const expectThrow = require('./expectThrow.js')
const timeTravel = require('./timeTravel');
const BigNumber = require('bignumber.js')
var ICOToken = artifacts.require("ICOToken");


async function deployTokenContract() {
    return await ICOToken.new("Test Token", "TST", 8, 100)
}

contract('ICOToken', async (accounts) => {

    const MAX_SUPPLY = new BigNumber('100').mul(new BigNumber('10').pow(8));

    describe('token', function () {

        it('should return the correct total supply after construction', async () => {
            let token = await deployTokenContract();
            let totalSupply = await token.totalSupply()
            assert.equal(totalSupply.toNumber(), MAX_SUPPLY)
        });

        it('should have the name TEST Token', async function () {
            let token = await deployTokenContract();
            let name = await token.name()
            assert.equal(name, "Test Token", "Test Token wasn't the name")
        });

        it('should have the symbol TST', async function () {
            let token = await deployTokenContract();
            let symbol = await token.symbol()
            assert.equal(symbol, "TST", "TST wasn't the symbol")
        });

        it('should have 8 decimals', async function () {
            let token = await deployTokenContract();
            let decimals = await token.decimals()
            assert.equal(decimals, 8, "8 wasn't the number of decimals")
        });
    });

    describe('transfers', function () {

        it('should allow transfer() 100 units from accounts[0] to accounts[1]', async function () {
            let token = await deployTokenContract();

            let amount = 100

            // initial account[0] and account[1] balance
            let account0StartingBalance = await token.balanceOf(accounts[0])
            let account1StartingBalance = await token.balanceOf(accounts[1])

            // transfer amount from account[0] to account[1]
            await token.transfer(accounts[1], amount, {from: accounts[0]})

            // final account[0] and account[1] balance
            let account0EndingBalance = await token.balanceOf(accounts[0])
            let account1EndingBalance = await token.balanceOf(accounts[1])

            assert.equal(account0EndingBalance.toNumber(), account0StartingBalance.toNumber() - amount, "Balance of account 0 incorrect")
            assert.equal(account1EndingBalance.toNumber(), account1StartingBalance.toNumber() + amount, "Balance of account 1 incorrect")
        });

        it('should throw an error when trying to transfer more than a balance', async function () {
            let token = await deployTokenContract();

            let accountStartingBalance = await token.balanceOf(accounts[0]);
            let amount = accountStartingBalance + 1;
            await expectThrow(token.transfer(accounts[2], amount, {from: accounts[0]}));
        });

    });

    describe('token distribution', function () {

        it('should give the owner the maximum supply cap after deploy', async function () {
            let token = await deployTokenContract();
            assert.equal(await token.totalSupply(), MAX_SUPPLY.toNumber())
            assert.equal(await token.balanceOf(accounts[0]), MAX_SUPPLY.toNumber())
        });
    });

    describe('allowance', function () {

        it('should return the correct allowance amount after approval', async function () {
            let token = await deployTokenContract();

            let amount = 100;

            //owner(account[0]) approves to account[1] to spend the amount
            await token.approve(accounts[1], amount);

            //checking the amount that an owner allowed to
            let allowance = await token.allowance(accounts[0], accounts[1]);
            assert.equal(allowance, amount, "The amount allowed is not equal!")

            //checking the amount to a not allowed account
            let non_allowance = await token.allowance(accounts[0], accounts[2]);
            assert.equal(non_allowance, 0, "The amount allowed is not equal!")
        });

        it('should allow transfer from allowed account', async function () {
            let token = await deployTokenContract();

            let amount = 100;

            let account0StartingBalance = await token.balanceOf(accounts[0]);
            let account1StartingBalance = await token.balanceOf(accounts[1]);
            let account2StartingBalance = await token.balanceOf(accounts[2]);
            assert.equal(account1StartingBalance, 0);
            assert.equal(account2StartingBalance, 0);

            //owner(account[0]) approves to account[1] to spend the amount
            await token.approve(accounts[1], amount);

            //account[1] orders a transfer from owner(account[0]) to account[1]
            await token.transferFrom(accounts[0], accounts[2], amount, {from: accounts[1]});
            let account0AfterTransferBalance = await token.balanceOf(accounts[0]);
            let account1AfterTransferBalance = await token.balanceOf(accounts[1]);
            let account2AfterTransferBalance = await token.balanceOf(accounts[2]);

            assert.equal(account0StartingBalance - amount, account0AfterTransferBalance);
            assert.equal(account1AfterTransferBalance, 0);
            assert.equal(amount, account2AfterTransferBalance)
        });

        it('should throw an error when trying to transfer more than allowed', async function () {
            let token = await deployTokenContract();
            let amount = 100;

            //owner(account[0]) approves to account[1] to spend the amount
            await token.approve(accounts[1], amount);

            let overflowed_amount = amount + 1;
            await expectThrow(token.transferFrom(accounts[0], accounts[2], overflowed_amount, {from: accounts[1]}));
        })

        it('should throw an error when trying to transfer from a not allowed account', async function () {
            let token = await deployTokenContract();
            let amount = 100;
            await expectThrow(token.transferFrom(accounts[0], accounts[2], amount, {from: accounts[1]}))
        })

        it('should be able to modify allowance', async function () {
            let token = await deployTokenContract();

            let amount = 100;

            //owner(account[0]) approves to account[1] to spend the amount
            await token.approve(accounts[1], amount);

            assert.equal(amount, await token.allowance(accounts[0], accounts[1]));

            await token.increaseApproval(accounts[1], 10);
            assert.equal(amount + 10, await token.allowance(accounts[0], accounts[1]));

            await token.decreaseApproval(accounts[1], 55);
            assert.equal(amount - 45, await token.allowance(accounts[0], accounts[1]));
            await token.decreaseApproval(accounts[1], 555);
            assert.equal(0, await token.allowance(accounts[0], accounts[1]));
        });

        it('should not approve twice', async function () {
            let token = await deployTokenContract();

            let amount = 100;

            //owner(account[0]) approves to account[1] to spend the amount
            await token.approve(accounts[1], amount);

            assert.equal(amount, await token.allowance(accounts[0], accounts[1]));

            await expectThrow(token.approve(accounts[1], amount + 1));
        });
    });

    describe('burnable', function () {

        it('owner should be able to burn tokens', async function () {
            let token = await deployTokenContract();
            let balance = await token.balanceOf(accounts[0]);
            let totalSupply = await token.totalSupply();
            let luckys_burned_amount = 100;
            let expectedTotalSupply = totalSupply - luckys_burned_amount;
            let expectedBalance = balance - luckys_burned_amount

            const {logs} = await token.burn(luckys_burned_amount);
            let final_supply = await token.totalSupply();
            let final_balance = await token.balanceOf(accounts[0]);
            assert.equal(expectedTotalSupply, final_supply, "Supply after burn do not fit.");
            assert.equal(expectedBalance, final_balance, "Supply after burn do not fit.");

            const event = logs.find(e => e.event === 'Burned');
            assert.notEqual(event, undefined, "Event Burned not fired!")
        });

        it('Can not burn more tokens than your balance', async function () {
            let token = await deployTokenContract();
            let totalSupply = await token.totalSupply();
            let luckys_burnable_amount = totalSupply + 1;
            await expectThrow(token.burn(luckys_burnable_amount));
        });
    });

    describe('anti theft', function () {

        it('should be able to freeze transfers for certain addresses', async function () {

            let token = await deployTokenContract();

            await token.transfer(accounts[1], 1000, {from: accounts[0]});
            let amount = 1000;

            //owner(account[1]) approves to account[0] to spend the amount
            await token.approve(accounts[0], amount, {from: accounts[1]});


            await expectThrow(token.freezeAddress(accounts[0], {from: accounts[1]}))

            await token.transfer(accounts[2], 1, {from: accounts[1]});

            await token.freezeAddress(accounts[1], {from: accounts[0]});

            await expectThrow(token.transfer(accounts[2], amount, {from: accounts[1]}))

            await expectThrow(token.transferFrom(accounts[1], accounts[3], amount, {from: accounts[0]}))

            await token.unfreezeAddress(accounts[1], {from: accounts[0]});

            await token.transfer(accounts[2], 1, {from: accounts[1]});

            await token.transferFrom(accounts[1], accounts[3], 1, {from: accounts[0]}); //acc1 transfers from acc0 to acc3

        });

        it('should be able to realocate tokens to a new address in an emergency case', async function () {
            let token = await deployTokenContract();
            await token.transfer(accounts[1], 1000, {from: accounts[0]});

            await token.freezeAddress(accounts[1], {from: accounts[0]});
            await token.restoreFunds(accounts[1], accounts[2], 1000)

            let account2Balance = await token.balanceOf(accounts[2]);

            assert.equal(account2Balance, 1000);

        });

        it('should let only the owner reallocate stolen tokens', async function () {
            let token = await deployTokenContract();
            await token.transfer(accounts[1], 1000, {from: accounts[0]});

            await token.freezeAddress(accounts[1], {from: accounts[0]});

            await expectThrow(token.restoreFunds(accounts[1], accounts[2], 1000, {from: accounts[1]}))

            let account1Balance = await token.balanceOf(accounts[1]);

            assert.equal(account1Balance, 1000);
        });
    });

    describe('pausable', function () {

        it('should not be able to transfer tokens when paused', async function () {
            let token = await deployTokenContract();
            let amount = 100;

            //owner(account[0]) approves to account[1] to spend the amount
            await token.approve(accounts[1], amount);

            await token.pause();

            await expectThrow(token.transfer(accounts[2], amount, {from: accounts[0]}));

            await expectThrow(token.transferFrom(accounts[0], accounts[2], amount, {from: accounts[1]}))

            await token.unpause();

            await token.transfer(accounts[2], amount, {from: accounts[0]});

            await token.transferFrom(accounts[0], accounts[2], amount, {from: accounts[1]}); //acc1 transfers from acc0 to acc2

        });
    });

    describe('ownable', function () {

        it('should be able to change the owner', async function () {
            let token = await deployTokenContract();

            assert.equal(accounts[0], await token.owner());

            await token.transferOwnership(accounts[1]);

            assert.equal(accounts[1], await token.owner());

            await expectThrow(token.pause({from: accounts[0]}));

        });
    });

    describe('lockable', function () {

        it('should be able to lock tokens for a year', async function () {
            let token = await deployTokenContract();
            await token.transfer(accounts[1], 1000, {from: accounts[0]});

            await token.transfer(accounts[2], 500, {from: accounts[1]});

            assert.equal(await token.balanceOf(accounts[1]), 500);
            assert.equal(await token.balanceOf(accounts[2]), 500);

            await expectThrow(token.lockAddressFor1Year(accounts[1], {from: accounts[1]}));

            await token.lockAddressFor1Year(accounts[1]);

            await expectThrow(token.approve(accounts[2], 1, {from: accounts[1]}));

            await token.transfer(accounts[1], 100, {from: accounts[2]});

            await expectThrow(token.transfer(accounts[2], 100, {from: accounts[1]}));

            assert.equal(await token.balanceOf(accounts[1]), 600);
            assert.equal(await token.balanceOf(accounts[2]), 400);

            await timeTravel(60 * 60 * 24 * 365 + 1);

            await token.transfer(accounts[2], 500, {from: accounts[1]});

            assert.equal((await token.balanceOf(accounts[1])).toNumber(), 100);
            assert.equal((await token.balanceOf(accounts[2])).toNumber(), 900);

            await token.stopLockingForever();
            await expectThrow(token.lockAddressFor1Year(accounts[1]));
            await expectThrow(token.lockAddressFor1Year(accounts[0], {from: accounts[2]}));

        });
    });

});