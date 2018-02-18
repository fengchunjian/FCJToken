/*

  Copyright 2017 FCJ Foundation.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/
pragma solidity ^0.4.11;

import "./StandardToken.sol";


/// @title FCJ Protocol Token.
/// For more information about this token sale, please visit https://github.com/fengchunjian/FCJToken
/// @author fengchunjian - <chunjian@2008.sina.com>.
contract FCJToken is StandardToken {
    string public constant NAME = "FCJCoin";
    string public constant SYMBOL = "FCJ";
    uint public constant DECIMALS = 18;

    /// During token sale, we use one consistent price: 1000 FCJ/ETH.
    /// We split the entire token sale period into 3 phases, each
    /// phase has a different bonus setting as specified in `bonusPercentages`.
    /// The real price for phase i is `(1 + bonusPercentages[i]/100.0) * BASE_RATE`.
    /// The first phase or early-bird phase has a much higher bonus.
    uint8[10] public bonusPercentages = [
        20,
        10,
        0
    ];

    uint public constant NUM_OF_PHASE = 3;
  
    /// Each phase contains exactly 29000 Ethereum blocks, which is roughly 7 days,
    /// which makes this 3-phase sale period roughly 21 days.
    /// See https://www.ethereum.org/crowdsale#scheduling-a-call
    uint16 public constant BLOCKS_PER_PHASE = 29000;

    /// This is where we hold ETH during this token sale. We will not transfer any Ether
    /// out of this address before we invocate the `close` function to finalize the sale. 
    /// This promise is not guanranteed by smart contract by can be verified with public
    /// Ethereum transactions data available on several blockchain browsers.
    /// This is the only address from which `start` and `close` can be invocated.
    ///
    /// Note: this will be initialized during the contract deployment.
    address public target;

    /// `firstblock` specifies from which block our token sale starts.
    /// This can only be modified once by the owner of `target` address.
    uint public firstblock = 0;

    /// Indicates whether unsold token have been issued. This part of FCJ token
    /// is managed by the project team and is issued directly to `target`.
    bool public unsoldTokenIssued = false;

    /// Minimum amount of funds to be raised for the sale to succeed. 
    uint256 public constant GOAL = 3000 ether;

    /// Maximum amount of fund to be raised, the sale ends on reaching this amount.
    uint256 public constant HARD_CAP = 4500 ether;

    /// Base exchange rate is set to 1 ETH = 1050 FCJ.
    uint256 public constant BASE_RATE = 1050;

    /// A simple stat for emitting events.
    uint public totalEthReceived = 0;

    /// Issue event index starting from 0.
    uint public issueIndex = 0;

    /* 
     * EVENTS
     */

    /// Emitted only once after token sale starts.
    event SaleStarted();

    /// Emitted only once after token sale ended (all token issued).
    event SaleEnded();

    /// Emitted when a function is invocated by unauthorized addresses.
    event InvalidCaller(address caller);

    /// Emitted when a function is invocated without the specified preconditions.
    /// This event will not come alone with an exception.
    event InvalidState(bytes msg);

    /// Emitted for each sucuessful token purchase.
    event Issue(uint issueIndex, address addr, uint ethAmount, uint tokenAmount);

    /// Emitted if the token sale succeeded.
    event SaleSucceeded();

    /// Emitted if the token sale failed.
    /// When token sale failed, all Ether will be return to the original purchasing
    /// address with a minor deduction of transaction fee（gas)
    event SaleFailed();

    /*
     * MODIFIERS
     */

    modifier onlyOwner {
        if (target == msg.sender) {
            _;
        } else {
            InvalidCaller(msg.sender);
            throw;
        }
    }

    modifier beforeStart {
        if (!saleStarted()) {
            _;
        } else {
            InvalidState("Sale has not started yet");
            throw;
        }
    }

    modifier inProgress {
        if (saleStarted() && !saleEnded()) {
            _;
        } else {
            InvalidState("Sale is not in progress");
            throw;
        }
    }

    modifier afterEnd {
        if (saleEnded()) {
            _;
        } else {
            InvalidState("Sale is not ended yet");
            throw;
        }
    }

    /**
     * CONSTRUCTOR 
     * 
     * @dev Initialize the FCJ Token
     * @param _target The escrow account address, all ethers will
     * be sent to this address.
     * This address will be : 0x43542027528431b6f5d6acb8a9b809f198392471
     */
    function FCJToken(address _target) {
        target = _target;
        totalSupply = 10 ** 26;
        balances[target] = totalSupply;
    }

    /*
     * PUBLIC FUNCTIONS
     */

    /// @dev Start the token sale.
    /// @param _firstblock The block from which the sale will start.
    function start(uint _firstblock) public onlyOwner beforeStart {
        if (_firstblock <= block.number) {
            // Must specify a block in the future.
            throw;
        }

        firstblock = _firstblock;
        SaleStarted();
    }

    /// @dev Triggers unsold tokens to be issued to `target` address.
    function close() public onlyOwner afterEnd {
        if (totalEthReceived < GOAL) {
            SaleFailed();
        } else {
            SaleSucceeded();
        }
    }

    /// @dev Returns the current price.
    function price() public constant returns (uint tokens) {
        return computeTokenAmount(1 ether);
    }

    /// @dev This default function allows token to be purchased by directly
    /// sending ether to this smart contract.
    function () payable {
        issueToken(msg.sender);
    }

    /// @dev Issue token based on Ether received.
    /// @param recipient Address that newly issued token will be sent to.
    function issueToken(address recipient) payable inProgress {
        // We only accept minimum purchase of 0.01 ETH.
        assert(msg.value >= 0.01 ether);

        // We only accept maximum purchase of 35 ETH.
        assert(msg.value <= 35 ether);

        // We only accept totalEthReceived < HARD_CAP
        uint ethReceived = totalEthReceived + msg.value;
        assert(ethReceived <= HARD_CAP);

        uint tokens = computeTokenAmount(msg.value);
        totalEthReceived = totalEthReceived.add(msg.value);
        
        balances[msg.sender] = balances[msg.sender].add(tokens);
        balances[target] = balances[target].sub(tokens);

        Issue(
            issueIndex++,
            recipient,
            msg.value,
            tokens
        );

        if (!target.send(msg.value)) {
            throw;
        }
    }

    /*
     * INTERNAL FUNCTIONS
     */
  
    /// @dev Compute the amount of FCJ token that can be purchased.
    /// @param ethAmount Amount of Ether to purchase FCJ.
    /// @return Amount of FCJ token to purchase
    function computeTokenAmount(uint ethAmount) internal constant returns (uint tokens) {
        uint phase = (block.number - firstblock).div(BLOCKS_PER_PHASE);

        // A safe check
        if (phase >= bonusPercentages.length) {
            phase = bonusPercentages.length - 1;
        }

        uint tokenBase = ethAmount.mul(BASE_RATE);
        uint tokenBonus = tokenBase.mul(bonusPercentages[phase]).div(100);

        tokens = tokenBase.add(tokenBonus);
    }

    /// @return true if sale has started, false otherwise.
    function saleStarted() constant returns (bool) {
        return (firstblock > 0 && block.number >= firstblock);
    }

    /// @return true if sale has ended, false otherwise.
    function saleEnded() constant returns (bool) {
        return firstblock > 0 && (saleDue() || hardCapReached());
    }

    /// @return true if sale is due when the last phase is finished.
    function saleDue() constant returns (bool) {
        return block.number >= firstblock + BLOCKS_PER_PHASE * NUM_OF_PHASE;
    }

    /// @return true if the hard cap is reached.
    function hardCapReached() constant returns (bool) {
        return totalEthReceived >= HARD_CAP;
    }
}
