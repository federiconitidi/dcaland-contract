pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/token/ERC20/SafeERC20.sol";

contract IUniswapExchange {
    // Address of ERC20 token sold on this exchange
    function tokenAddress() external view returns (address token);
    // Address of Uniswap Factory
    function factoryAddress() external view returns (address factory);
    // Provide Liquidity
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable returns (uint256);
    function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_tokens, uint256 deadline) external returns (uint256, uint256);
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
    // Trade ETH to ERC20
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256  tokens_bought);
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable returns (uint256  tokens_bought);
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external payable returns (uint256  eth_sold);
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) external payable returns (uint256  eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256  eth_bought);
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_tokens, uint256 deadline, address recipient) external returns (uint256  eth_bought);
    function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) external returns (uint256  tokens_sold);
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient) external returns (uint256  tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address token_addr) external returns (uint256  tokens_sold);
    function tokenToTokenTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_sold);
    // Trade ERC20 to Custom Pool
    function tokenToExchangeSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address exchange_addr) external returns (uint256  tokens_bought);
    function tokenToExchangeTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_bought);
    function tokenToExchangeSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address exchange_addr) external returns (uint256  tokens_sold);
    function tokenToExchangeTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_sold);
    // ERC20 comaptibility for liquidity tokens
    bytes32 public name;
    bytes32 public symbol;
    uint256 public decimals;
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256);
    function totalSupply() public view returns (uint256);
    // Never use
    function setup(address token_addr) external;
}


contract DCAcontract {
    IERC20 dai;
    address payable public creator;
    uint public fee_numerator;
    uint public fee_denominator;
    uint public gas_consumption;

    uint public streamsCount = 0;
    mapping(uint => address) public all_users;
    
    mapping(address => Stream) public streams;
    struct Stream {
        uint _id;
        uint parcel;    // parcel in DAI
        uint interval;  // interval in seconds
        uint startTime;
        uint lastSwap;
        uint isactive;
        uint created;
        uint dai_swapped;
        uint eth_received;
    }
    
    uint public relayersCount = 0;
    mapping(uint => address) public relayers;
    

    // at creation, define who is the contract creator
    // the creator does not have specific powers, but will receive 50% of the fees collected by the relayers
    // this will allow the creator to sustain development and marketing of the frontend app to the users
    constructor(address payable _creator) public {
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        creator = _creator;
        fee_numerator = 2;
        fee_denominator = 1000;
        gas_consumption = 200000;
        SafeERC20.safeApprove(dai, 0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667, uint(-1));
    }


    // allow the user to activate the dca stream
    // by default, a stream is set to active (isactive =1) when it is originally created
    function activate(uint _parcel, uint _interval) external {
        Stream storage s = streams[msg.sender];
        if (s.created == 1) {
            s.parcel = _parcel;
            s.interval = _interval;
        } else {
            // then create the stream
            streams[msg.sender] = Stream(streamsCount, _parcel, _interval, block.timestamp, 0, 1, 1, 0, 0);
            all_users[streamsCount] = msg.sender;
            streamsCount ++;
        }
    }   
    
    // allow the user to stop the dca stream
    function stop() external {
        Stream storage s = streams[msg.sender];
        require(s.created == 1);
        s.isactive = 0;
    } 

    // allow the user to re-start the dca stream
    function start() external {
        Stream storage s = streams[msg.sender];
        require(s.created == 1);
        s.isactive = 1;
    } 

    // allow the user to edit the individual parcel amount that is regularly purchased
    function editParcel(uint _parcel) external {
        Stream storage s = streams[msg.sender];
        require(s.created == 1);
        s.parcel = _parcel;
    }   

    // allow the user to edit the interval between purchases
    function editInterval(uint _interval) external {
        Stream storage s = streams[msg.sender];
        require(s.created == 1);
        s.interval = _interval;
    }  

    // allow an address to register as a relayer
    function registerAsRelayer() external{
        // this function adds the msg.sender to the list of relayers
        // this is a FIFO list which will assign to each relayer a "time window" of 240 seconds to execute the DCA transaction.
        // the reason for this architecture is to allow everyone to be a relayer, but at the same time discourage gas bidding competition
        // which would ultimately damage the end user (who is paying for the gas)
        relayers[relayersCount] = msg.sender;
        relayersCount ++;
    }
    

    // allow a relayer to execute the transaction for a user and convert his DAI parcel into ETH
    function convertParcel(address payable _user) external{
        Stream storage s = streams[_user];
        uint256 ready_since = now - (s.lastSwap + s.interval);
        uint256 gasPrice = tx.gasprice;
        uint256 eth_bought = IUniswapExchange(0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667).getTokenToEthInputPrice(s.parcel);
        
        // the contract execution requires several conditions:
        //    a) that a stream was created for the user in the past (s.created == 1)
        //    b) that the stream is active (s.isactive == 1)
        //    c) that enough time has passed since the last swap (ready_since>=0)
        //    d) that the estimated gas cost is below 2% of the returned amount from Uniswap; otherwise don't let  transaction take place
        //    e) that the current time window is open for this relayer
        //
        // starting from the top relayer in the list, each relayer will have a "time windows" of 240 seconds assigned to make the transaction
        // if that relayer does not respond, the time window will open for the second in the list, and so on
        // the first relayer that sends the transaction will move up in the list by one position.
        // this will allow anyone to be a relayer, while discouraging bidding with a high gas price which would ultimately damage the end user
        
        uint relayer_allowed_index = ready_since / 240;
        if (relayer_allowed_index > relayersCount - 1){
            relayer_allowed_index = 0;
        }
        address relayer_allowed = relayers[relayer_allowed_index];
        
        require(s.created == 1 && 
                s.isactive == 1 &&
                ready_since >= 0 &&
                gasPrice * gas_consumption < eth_bought * 2 / 100 &&
                relayer_allowed == msg.sender);
        
        // if all the conditions are satisfied, proceed with the swap
        // first move the parcel of DAI from the owner wallet to this contract, then return the ETH obtained to the contract
        dai.transferFrom(_user, address(this), s.parcel);
        uint256 ether_returned = IUniswapExchange(0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667).tokenToEthSwapInput(s.parcel, 1, now+120);
        
        // now distribute the ether_returned between the owner, the relayer and the creator
        // in particular:
        //    a) the owner gets the ETH received from uniswap, net of the gas cost and the fee
        //    b) the relayer gets 50% of the fee, plus a reimbursement for the gas cost
        //    c) the creator gets 50% of the fee
        
        _user.transfer(ether_returned * (fee_denominator - fee_numerator)/fee_denominator - gas_consumption * gasPrice); // to the user
        msg.sender.transfer(gas_consumption * gasPrice + (ether_returned * fee_numerator / 2) / fee_denominator); // to the relayer
        creator.transfer((ether_returned * fee_numerator / 2) / fee_denominator);  // to the creator
        
        // record in the contract the amount of DAI swapped and ETH received
        // also, update the timestamp of the last swap
        s.dai_swapped = s.dai_swapped + s.parcel;
        s.eth_received = s.eth_received + ether_returned - gas_consumption * gasPrice - (ether_returned * fee_numerator) / fee_denominator;
        s.lastSwap = block.timestamp;
        
        // finally, readjust the FIFO list of relayers and reward the relayer that made the transaction by moving up one notch
        if (relayer_allowed_index != 0){
            address relayer_before = relayers[relayer_allowed_index - 1];
            relayers[relayer_allowed_index - 1] = msg.sender;
            relayers[relayer_allowed_index] = relayer_before;
        }
    }


    // check that is the right time to trigger a swap for a certain user
    // NOTE: this function needs to return 0 for the transaction to be possible
    function check_time(address payable _user) public view returns(uint){
        Stream storage s = streams[_user];
        if (s.created == 0) { 
            // if the user was never created
            return uint(-1);
            
        } else if (now < s.lastSwap + s.interval){
            // if the user was created, but it's not yet time to make a swap, return the remaining time in seconds
            return s.lastSwap + s.interval - now; 
            
        } else {
            // if the timing is good to make the swap, return 0
            return 0;  
        }
    }


    // check that the address has a sufficient DAI balance and allowance to make the swap & the stream is active
    // NOTE: this function needs to return 1 for the transaction to be possible
    function check_balance(address payable _user) public view returns(uint){
        Stream storage s = streams[_user];
        if (s.created == 0) {
            // if the user was never created
            return uint(-1);
            
        } else if (dai.balanceOf(_user) > s.parcel && dai.allowance(_user, address(this)) > s.parcel && s.isactive == 1) {
            // if the balance is enough and we have enough allowance to make the swap, return 1
            return 1;
            
        } else {
            // if not, return 0
            return 0;
        }
    }
    
    
    // check what relayer is currently allowed to execute the transaction
    // NOTE: this function needs to return your address for you to be allowed as a relayer to execute the transaction and obtain the fee
    function check_allowed_relayer(address payable _user) public view returns(address){
        Stream storage s = streams[_user];
        if (now - (s.lastSwap + s.interval) < 0){
            return 0x0000000000000000000000000000000000000000;
        } else{
            uint relayer_allowed_index = (now - (s.lastSwap + s.interval)) / 240;
            return relayers[relayer_allowed_index];
        }
        
    }

        
    // scan through the all_users list and obtain the address of each user
    function scanUsers(uint _index) public view returns(address){
        return all_users[_index];
    }


    // Include fallback so the contract can receive ETH from exchange
    function () external payable {}

}