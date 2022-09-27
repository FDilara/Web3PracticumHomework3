// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//Used this interface from OpenZeppelin library for token
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrowdFund {
    /***Events***/
    event Launch(uint count, address indexed creator, uint goal, uint startAt, uint endAt);
    event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint indexed id, address indexed caller, uint amount);

    //Data that should be in the campaign structure
    struct Campaign {
        address creator; //Campaign creator
        uint goal; //Will the amount of tokens that needs to be raised for the campaign to be successful
        uint pledged; //Amount of tokens sent for the campaign
        uint32 startAt; //Start time
        uint32 endAt; //End time
        bool claimed; //Claimed by the creator
    }

    /***State Variables***/
    //ERC20 interface
    IERC20 public immutable token; 
    //Campaign count
    uint public count;
    //Maps campaign to id
    mapping(uint => Campaign) public campaigns;
    //Keeps how many tokens the account has sent to which campaign
    mapping(uint => mapping(address => uint)) public pledgedAmount;  

    constructor(address _token) {
        //In this contract, the coin accepted for the Campaign is set to Dai.
        //0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735 - Dai token address on Rinkeby network
        //Accounts that want to send tokens for the campaign should call the "approve" function in the Dai contract.
        token = IERC20(_token); 
    }

    //Users can start a campaign
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        require(_startAt >= block.timestamp, "start time is smaller than now");
        require(_endAt >= _startAt, "end time is smaller than start time");
        require(_endAt <= block.timestamp + 90 days, "end time is greater than max duration");

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    //Campaign creator can cancel the campaign if the campaign has not started yet
    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "not creator");
        require(block.timestamp < campaign.startAt, "started");
        delete campaigns[_id];
        emit Cancel(_id);
    }

    //Tokens are sent for active campaign
    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "not started");
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    //Token sent for active campaign can be withdrawn
    function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    /*If the goal amount entered for the campaign is greater than the pledged amount, 
     *the campaign creator will be able to claim all the pledged tokens.
     */
    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "not creator");
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged >= campaign.goal, "less than pledged goal");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;
        token.transfer(msg.sender, campaign.pledged);

        emit Claim(_id);
    }

    /*If the campaign unsuccessful, 
     *it will be refunded if the amount of coins pledged by all users is less than the goal.
     */
    function refund(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged < campaign.goal, "less than pledged goal");

        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
    
}
