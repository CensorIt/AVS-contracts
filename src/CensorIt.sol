// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ECDSAServiceManagerBase} from "../lib/eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";

contract Censorlt{
    enum VoilationType{
        SPAM,
        FAKE,
        HARMFUL,
        COPYRIGHT
    }
    enum ContentType{
        AUDIO,
        VIDEO,
        TEXT,
        IMAGE
    }
    struct Operator{
        uint256 stake;   
        uint256 reputation; 
        uint256 totalVotes;   
        uint256 correctVotes;
    }
    struct ContentReport{
        string content;
        ContentType contentType;
        address reporter;
        VoilationType voilationType;
        bool isResolved;
        uint rewardAmount;
        uint removeCount;
        uint keepCount;
        address[] hasVoted;
        mapping(address=>bool) removeVote;
    }
    uint numReports;
    mapping(uint=>ContentReport) public reports;
    mapping(address => Operator) public registeredOperators;
    uint public minStakeRequired= 10000000000000000;
    address public owner;
    constructor(){
        owner= msg.sender;
    }
    function reportContent(string memory _content, VoilationType _voilationType, ContentType _contentType) external payable{
        require(msg.value>0,"stake required");
        ContentReport storage newReport= reports[numReports++];
        newReport.content=_content;
        newReport.reporter=msg.sender;
        newReport.contentType=_contentType;
        newReport.voilationType=_voilationType;
        newReport.rewardAmount=msg.value;
    }
    function alreadyVoted(uint _contentId,address _operator) internal view returns(bool){
        ContentReport storage report= reports[_contentId];
        for(uint i=0;i<report.hasVoted.length;i++){
            if(report.hasVoted[i]==_operator){
                return true;
            }
        }
        return false;
    }
    function voteAsOperator(uint _contentId,bool _removeCount) external{
        require(isOperator(msg.sender),"Only Operater can vote");
        ContentReport storage report= reports[_contentId];
        require(! alreadyVoted(_contentId, msg.sender),"already voted");
        if(_removeCount){
            report.removeCount++;
            report.removeVote[msg.sender]=true;
        }
        else{
            report.keepCount++;
            report.removeVote[msg.sender]=false;
        }
        report.hasVoted.push(msg.sender);
        // uint totalVotes= report.removeCount+report.keepCount;
        // if(totalVotes>=3){
        //     bool remove= report.removeCount>report.keepCount;
        //     report.isResolved=true;
        //     // distributeRewards(_contentId, remove);
        // }
    }
    
    function setMinStake(uint256 _newMinStake) external {
        require(msg.sender==owner);
        minStakeRequired = _newMinStake;
    }

    function registerAsOperator() external payable{
         require(msg.value >= minStakeRequired, "Not enough stake");
        Operator storage newOperator= registeredOperators[msg.sender];
        newOperator.stake=msg.value;
    }

     function isOperator(address _operator) internal view returns(bool){
        if(registeredOperators[_operator].stake>=minStakeRequired){
            return true;
        }
        return false;
    }

    // function distributeRewards(uint _contentId,bool _remove) internal{
    //     ContentReport storage report= reports[_contentId];
    //     uint256 correctVoterCount = 0;
    //     for(uint i=0;i<report.hasVoted.length;i++){
    //         if(report.removeVote[report.hasVoted[i]]==_remove){
    //             correctVoterCount++;
    //         }
    //     }
    //      uint256 rewardPerCorrectVoter = report.rewardAmount / correctVoterCount;
    //      for(uint i=0;i<report.hasVoted.length;i++){
    //         if(report.removeVote[report.hasVoted[i]]==_remove){
    //             (bool success,)=payable(report.hasVoted[i]).call{value:rewardPerCorrectVoter}("");
    //             require(success);
    //         }
    //     }
    // }
}