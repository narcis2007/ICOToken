pragma solidity ^0.4.20;
/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    uint public totalSupply;

    function balanceOf(address who) constant returns (uint);
    function allowance(address owner, address spender) constant returns (uint);

    function transfer(address to, uint value) returns (bool ok);
    function transferFrom(address from, address to, uint value) returns (bool ok);
    function approve(address spender, uint value) returns (bool ok);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}



/**
 * Math operations with safety checks
 */
contract SafeMath {
    function safeMul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b) internal returns (uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function safeSub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c>=a && c>=b);
        return c;
    }

    function max64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a < b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a < b ? a : b;
    }

    function assert(bool assertion) internal {
        if (!assertion) {
            revert();
        }
    }
}



/**
 * Standard ERC20 token with Short Hand Attack and approve() race condition mitigation.
 *
 * Based on code by FirstBlood:
 * https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, SafeMath {

    string public name;
    string public symbol;
    uint public decimals;

    /* Actual balances of token holders */
    mapping(address => uint) balances;

    /* approve() allowances */
    mapping (address => mapping (address => uint)) allowed;

    /**
     *
     * Fix for the ERC20 short address attack
     *
     * http://vessenes.com/the-erc20-short-address-attack-explained/
     */
    modifier onlyPayloadSize(uint size) {
        if(msg.data.length < size + 4) {
            revert();
        }
        _;
    }

    function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) returns (bool success) {
        uint _allowance = allowed[_from][msg.sender];

        balances[_to] = safeAdd(balances[_to], _value);
        balances[_from] = safeSub(balances[_from], _value);
        allowed[_from][msg.sender] = safeSub(_allowance, _value);
        Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant returns (uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) returns (bool success) {

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) revert();

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint remaining) {
        return allowed[_owner][_spender];
    }

    /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = safeAdd(allowed[msg.sender][_spender],_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = safeSub(oldValue, _subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

}

/*
 * Ownable
 *
 * Base contract with an owner.
 * Provides onlyOwner modifier, which prevents function from running if it is called by anyone other than the owner.
 */
contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}

/**
 * A token that can increase its supply by another contract.
 *
 * This allows uncapped crowdsale by dynamically increasing the supply when money pours in.
 * Only mint agents, contracts whitelisted by owner, can mint new tokens.
 *
 */
contract MintableToken is StandardToken, Ownable {

    /** List of agents that are allowed to create new tokens */
    mapping (address => bool) public mintAgents;
    bool public isMintingEnabled = true;

    event MintingAgentChanged(address addr, bool state  );


    /**
     * Create new tokens and allocate them to an address..
     *
     * Only callably by a crowdsale contract (mint agent).
     */
    function mint(address receiver, uint amount) onlyMintAgent canMint public {
        totalSupply = safeAdd(totalSupply, amount);
        balances[receiver] = safeAdd(balances[receiver], amount);

        // This will make the mint transaction apper in EtherScan.io
        // We can remove this after there is a standardized minting event
        Transfer(0, receiver, amount);
    }

    modifier canMint(){
        if(!isMintingEnabled) {
            revert();
        }
        _;
    }

    function stopMintingForever() onlyOwner {
        isMintingEnabled = false;
    }

    /**
     * Owner can allow a crowdsale contract to mint new tokens.
     */
    function setMintAgent(address addr, bool state) onlyOwner public {
        mintAgents[addr] = state;
        MintingAgentChanged(addr, state);
    }

    modifier onlyMintAgent() {
        // Only crowdsale contracts are allowed to mint new tokens
        if(!mintAgents[msg.sender]) {
            revert();
        }
        _;
    }

}

/**
 * @title Freezable
 * @dev Base contract which allows children to freeze the operations from a certain address in case of an emergency.
 */
contract Freezable  is Ownable {

    mapping (address => bool) internal frozenAddresses;

    modifier ifNotFrozen() {
        require(frozenAddresses[msg.sender] == false);
        _;
    }

    function freezeAddress(address addr) onlyOwner {
        frozenAddresses[addr] = true;
    }

    function unfreezeAddress(address addr) onlyOwner {
        frozenAddresses[addr] = false;
    }
}

/**
 * @title Freezable token
 * @dev StandardToken modified with freezable transfers.
 **/
contract FreezableToken is StandardToken, Freezable {

    function transfer(address _to, uint256 _value) public ifNotFrozen returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public ifNotFrozen returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public ifNotFrozen returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public ifNotFrozen returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public ifNotFrozen returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }
}

/**
 * A a standard token with an anti-theft mechanism.
 * Is able to restore stolen funds to a new address where the corresponding private key is safe.
 *
 */
contract AntiTheftToken is FreezableToken {

    function restoreFunds(address from, address to, uint amount) onlyOwner {
        //can only restore stolen funds from a frozen address
        require(frozenAddresses[from] == true);
        require(to != address(0));
        require(amount <= balances[from]);

        balances[from] = safeSub(balances[from], amount);
        balances[to] = safeAdd(balances[to], amount);
        emit Transfer(from, to, amount);
    }
}

/**
 * A token that can increase its supply by another contract up to a certain limit.
 *
 * This allows a capped crowdsale.
 * Only mint agents, contracts whitelisted by owner, can mint new tokens.
 *
 */
contract CappedMintableToken is MintableToken{
    /** The maximum number of tokens that can ever exist */
    uint256 public supplyCap;

    constructor(uint _supplyCap){
        supplyCap = _supplyCap;
    }

    function mint(address receiver, uint amount) onlyMintAgent public {
        // Check that the cap has not been reached before minting new tokens
        assert(safeAdd(totalSupply, amount) <= supplyCap);
        if(totalSupply == supplyCap)
            isMintingEnabled = false;
        MintableToken.mint(receiver, amount);
    }

    function getSupplyCap() constant returns (uint){
        return supplyCap;
    }
}

contract BurnableToken is StandardToken {

    /** How many tokens we burned */
    event Burned(address burner, uint burnedAmount);

    /**
     * Burn extra tokens from a balance.
     *
     */
    function burn(uint burnAmount) {
        address burner = msg.sender;
        balances[burner] = safeSub(balances[burner], burnAmount);
        totalSupply = safeSub(totalSupply, burnAmount);
        Burned(burner, burnAmount);
    }
}

contract ICOToken is CappedMintableToken, BurnableToken, AntiTheftToken {

    constructor(string _name, string _symbol, uint _decimals, uint _max_supply) CappedMintableToken(_max_supply * (10 ** _decimals)) {
        symbol = _symbol;
        name = _name;
        decimals = _decimals;

    }

}