pragma solidity ^0.5.0;


/*
 * Ownable
 *
 * Base contract with an owner.
 * Provides onlyOwner modifier, which prevents function from running if it is called by anyone other than the owner.
 */
contract Ownable {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}


/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    uint public totalSupply;

    function balanceOf(address who) public view returns (uint);

    function allowance(address owner, address spender) public view returns (uint);

    function transfer(address to, uint value) public returns (bool ok);

    function transferFrom(address from, address to, uint value) public returns (bool ok);

    function approve(address spender, uint value) public returns (bool ok);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}



/**
 * Math operations with safety checks
 */
contract SafeMath {
    function safeMul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assertThat(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b) internal pure returns (uint) {
        assertThat(b > 0);
        uint c = a / b;
        assertThat(a == b * c + a % b);
        return c;
    }

    function safeSub(uint a, uint b) internal pure returns (uint) {
        assertThat(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assertThat(c >= a && c >= b);
        return c;
    }

    function max64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a < b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function assertThat(bool assertion) internal pure {
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
    mapping(address => mapping(address => uint)) allowed;

    /**
     *
     * Fix for the ERC20 short address attack
     *
     * http://vessenes.com/the-erc20-short-address-attack-explained/
     */
    modifier onlyPayloadSize(uint size) {
        if (msg.data.length < size + 4) {
            revert();
        }
        _;
    }

    function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) public returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool success) {
        uint _allowance = allowed[_from][msg.sender];

        balances[_to] = safeAdd(balances[_to], _value);
        balances[_from] = safeSub(balances[_from], _value);
        allowed[_from][msg.sender] = safeSub(_allowance, _value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) public returns (bool success) {

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) revert();

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint remaining) {
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
        allowed[msg.sender][_spender] = safeAdd(allowed[msg.sender][_spender], _addedValue);
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

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = false;
    mapping(address => bool) public transferWhitelisted;

    function whitelistForTransfer(address who, bool whitelisted) public onlyOwner {
        transferWhitelisted[who] = whitelisted;
    }


    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!(paused && transferWhitelisted[msg.sender] == false) );
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }
}

/**
 * @title Pausable token
 * @dev StandardToken modified with pausable transfers.
 **/
contract PausableToken is StandardToken, Pausable {

    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }
}


contract LockableToken is StandardToken, Ownable { // TODO: see if it's better to have a locking agent sepparated from the owner

    mapping(address => uint) lockedUntil;
    bool lockingActive = true;

    function lockAddressUntil(address who, uint timestamp) onlyOwner public {
        require(lockingActive, "Locking must be active!");

        lockedUntil[who] = timestamp;
    }

    modifier isNotLocked(){
        require(lockedUntil[msg.sender] < now);
        _;
    }

    function stopLockingForever() onlyOwner public {
        lockingActive = false;
    }

    function transfer(address _to, uint256 _value) public isNotLocked returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public isNotLocked returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public isNotLocked returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public isNotLocked returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public isNotLocked returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }

    function getLockedUntil(address who) public view returns(uint){
        return lockedUntil[who];
    }
}

/**
 * @title Freezable
 * @dev Base contract which allows children to freeze the operations from a certain address in case of an emergency.
 */
contract Freezable is Ownable {

    mapping(address => bool) internal frozenAddresses;

    modifier ifNotFrozen() {
        require(frozenAddresses[msg.sender] == false);
        _;
    }

    function freezeAddress(address addr) public onlyOwner {
        frozenAddresses[addr] = true;
    }

    function unfreezeAddress(address addr) public onlyOwner {
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

    function restoreFunds(address from, address to, uint amount) public onlyOwner {
        //can only restore stolen funds from a frozen address
        require(frozenAddresses[from] == true);
        require(to != address(0));
        require(amount <= balances[from]);

        balances[from] = safeSub(balances[from], amount);
        balances[to] = safeAdd(balances[to], amount);
        emit Transfer(from, to, amount);
    }
}

contract LohnToken is PausableToken, LockableToken, AntiTheftToken {

    bool distributedToTeam = false;

    constructor(string memory _name, string memory _symbol, uint _decimals, uint _max_supply) public {
        symbol = _symbol;
        name = _name;
        decimals = _decimals;

        totalSupply = _max_supply * (10 ** _decimals);
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0x0), msg.sender, totalSupply);
    }


    // TODO: function for lock and transfer
    function distributeTokens() public {
        require(distributedToTeam == false);

        uint tokensForTeamMember = (10 ** 6) * (10 ** decimals);
        transfer(0x841996929D83Acbb6F995B434625d7358a60e9ff, tokensForTeamMember); // Vasile Lupu
        transfer(0xfFe2Bf4AC5a63f3F4B49D5B7A2bA1a510A21fa25, tokensForTeamMember); // Catalin Iordache
        transfer(0x9608E4Af209FC56DF2383674C155E6A69Ff0D4E8, tokensForTeamMember); // Irina Masnita
        transfer(0xb89E031d991e1F891A62540cD8731d6a7478bb99, tokensForTeamMember); // Daniela Ghitoiu
        transfer(0xCf6f4181995A358478Fb0FFe9d34a59e0Cd7cD42, tokensForTeamMember); // Andrei Danciu
        transfer(0x371976aA9Ed7ca3216Ff1e4C6047cd0FB97d7D16, tokensForTeamMember); // Raphael
        transfer(0x257c190A914b4194bbE9aCfEAdBafb7012c643f6, tokensForTeamMember); // Ovidiu Stancalie
        transfer(0x03749Becb794AA3791ED0f4F87db6651E1D37F8b, tokensForTeamMember); // Oana Taroiu
        transfer(0xB229b7384c8569c1d39E0eD6ec7020F7b118fd66, tokensForTeamMember); // Sorin
        transfer(0x6Ca8cc722Cc7478c90B1765C6a080c3206931668, tokensForTeamMember); // Hakan
        transfer(0xA5B0dBdD4a25a017d4A18B0d9223f9a6e655bB75, tokensForTeamMember); // Popa Laurentiu
        transfer(0x6A11e851ab9b75AdfF092a540718BDE0Cf81c7cD, tokensForTeamMember / 2); // Sean Brizendine - advisor
        transfer(0x61b0615e69a713c846A58bDA249b6fcD0ceA565f, tokensForTeamMember / 2); // Hamza Khan - advisor




        distributedToTeam = true;
    }

}