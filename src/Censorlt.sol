// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSAServiceManagerBase} from "../lib/eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "../lib/eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {OperatorAllowlist } from "../lib/wizard-templates/src/templates/OperatorAllowlist.sol";
import "../lib/eigenlayer-contracts/src/contracts/libraries/BytesLib.sol";
contract Censorlt is ECDSAServiceManagerBase,OperatorAllowlist {
    using BytesLib for bytes;
    using ECDSAUpgradeable for bytes32;
    // ECDSAStakeRegistry public stakeRegistry;
    enum VoilationType{
        VULGAR,
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
    
    struct ContentReport{
        string content;
        ContentType contentType;
        address reporter;
        VoilationType voilationType;
        bool isResolved;
        uint256 removeCount;
        uint256 keepCount;
        address[] hasVoted;
        uint32 taskCreatedBlock;
    }

    event newReportCreated(uint256 indexed _numReports,ContentReport indexed _newReport);
    event TaskResponded(uint256 indexed _reportIndex,ContentReport indexed _report, address indexed _operator);

    mapping(uint256 => bytes32) public allTaskHashes;
    mapping(address => mapping(uint256 => bytes)) public allTaskResponses;

    modifier onlyOperator() {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender),
            "Operator must be the caller"
        );
        _;
    }

    uint256 public numReports;
    mapping(uint256=>ContentReport) public reports;

    constructor(
        address __avsDirectory,
        address __stakeRegistry,
        address __rewardsCoordinator,
        address __delegationManager
    )ECDSAServiceManagerBase(
            __avsDirectory,
            __stakeRegistry,
            __rewardsCoordinator,
            __delegationManager
    ){}

     function initialize(address initialOwner_, address rewardsInitiator_, address allowlistManager_)
        external
        initializer
    {
        __ServiceManagerBase_init(initialOwner_, rewardsInitiator_);
        __OperatorAllowlist_init(allowlistManager_, true);
    }

    function createNewTask(string memory _content, VoilationType _voilationType, ContentType _contentType) external {
        // create a new task struct
        ContentReport memory newReport;
        newReport.content=_content;
        newReport.reporter=msg.sender;
        newReport.contentType=_contentType;
        newReport.voilationType=_voilationType;
        newReport.taskCreatedBlock = uint32(block.number);
        
        // store hash of task onchain, emit event, and increase taskNum
        allTaskHashes[numReports] = keccak256(abi.encode(newReport));
        reports[numReports] = newReport;
        emit newReportCreated(numReports, newReport);
        numReports = numReports + 1;
    }

    function alreadyVoted(uint256 _contentId,address _operator) internal view returns(bool){
        ContentReport memory report= reports[_contentId];
        for(uint256 i=0;i<report.hasVoted.length;i++){
            if(report.hasVoted[i]==_operator){
                return true;
            }
        }
        return false;
    }
    
    function respondToTask(
        uint256 _contentId,
        bool _vote,
        bytes memory signature
    ) external onlyOperator {

        // check that the task is valid, hasn't been responsed yet, and is being responded in time
        require(!alreadyVoted(_contentId, msg.sender), "already voted");
        require(
            allTaskResponses[msg.sender][numReports].length == 0,
            "Operator has already responded to the task"
        );
        require(operatorHasMinimumWeight(msg.sender), "Operator does not have match the weight requirements");
        // check that the task is valid, hasn't been responsed yet, and is being responded in time
       
        // The message that was signed
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                _contentId,
                _vote,
                msg.sender
            )
        );

        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        // Verify signature using the stake registry
        address signer = ethSignedMessageHash.recover(signature);

        require(signer == msg.sender, "Message signer is not operator");

        ContentReport storage report = reports[_contentId];
        // updating the storage with task responses
        allTaskResponses[msg.sender][numReports] = signature;
        
        if (!_vote) {
            report.removeCount++;
        } else {
            report.keepCount++;
        }
        report.hasVoted.push(msg.sender);

        // emitting event
        emit TaskResponded(numReports, report, msg.sender);
    }
    
    function operatorHasMinimumWeight(address operator) public view returns (bool) {
        return ECDSAStakeRegistry(stakeRegistry).getOperatorWeight(operator)
            >= ECDSAStakeRegistry(stakeRegistry).minimumWeight();
    }

    function getReport(uint256 _contentId) public view returns(ContentReport memory){
        return reports[_contentId];
    }
}