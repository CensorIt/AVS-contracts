// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Censorlt.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MockAVSDirectory} from "./mocks/MockAVSDirectory.sol";
import {MockECDSAStakeRegistry} from "./mocks/MockECDSAStakeRegistry.sol";
import {MockDelegationManager} from "./mocks/MockDelegationManager.sol";
import {MockRewardsCoordinator} from "./mocks/MockRewardsCoordinator.sol";

contract CensorltTest is Test {
    Censorlt public censorlt;
    MockAVSDirectory public avsDirectory;
    MockECDSAStakeRegistry public stakeRegistry;
    MockDelegationManager public delegationManager;
    MockRewardsCoordinator public rewardsCoordinator;

    address public owner;
    address public operator;
    address public reporter;
    address public rewardsInitiator;
    address public allowlistManager;    

    // event newReportCreated(uint256 indexed _numReports,Censorlt.ContentReport indexed _newReport);
    event TaskResponded(uint256 indexed _reportIndex,Censorlt.ContentReport indexed _report, address indexed _operator);

    function setUp() public {
        owner = 0x0000000000000000000000000000000000000000;
        operator = makeAddr("operator");
        reporter = makeAddr("reporter");
        rewardsInitiator = makeAddr("rewardsInitiator");
        allowlistManager = makeAddr("allowlistManager");

        // Deploy mock contracts
        avsDirectory = new MockAVSDirectory();
        stakeRegistry = new MockECDSAStakeRegistry();
        delegationManager = new MockDelegationManager();
        rewardsCoordinator = new MockRewardsCoordinator();

        // Deploy main contract
        censorlt = new Censorlt(
            address(avsDirectory),
            address(stakeRegistry),
            address(rewardsCoordinator),
            address(delegationManager)
        );

        // Initialize contract
        vm.prank(owner);

        // Setup mock responses
        stakeRegistry.setOperatorRegistered(operator, true);
    }

    function testInitialization() public {
        assertEq(censorlt.numReports(), 0);
        assertEq(censorlt.owner(), owner);
    }

    function testCreateNewTask() public {
        string memory content = "Test content";

        // Create empty address array for hasVoted
        
        //Censorlt.ContentReport memory expectedReport =Censorlt.ContentReport({
        //     content: content,
        //     contentType: _contentType,
        //     reporter: reporter,
        //     voilationType: _violationType,
        //     isResolved: false,
        //     removeCount: 0,
        //     keepCount: 0,
        //     hasVoted: emptyAddressArray,
        //     taskCreatedBlock: uint32(block.number)
        // });
        // emit newReportCreated(0, expectedReport);

        vm.prank(reporter);
        censorlt.createNewTask(content, Censorlt.VoilationType.VULGAR, Censorlt.ContentType.TEXT);

        assertEq(censorlt.numReports(), 1);
        
        Censorlt.ContentReport memory report = censorlt.getReport(0);

        assertEq(report.content, content);
        assertEq(uint(report.contentType), uint(Censorlt.ContentType.TEXT));
        assertEq(uint(report.voilationType), uint(Censorlt.VoilationType.VULGAR));
        assertEq(report.reporter, reporter);
        assertEq(report.isResolved, false);
    }

    function testRespondToTask() public {
        // First create a task
        string memory content = "Test content";
        vm.prank(reporter);
        censorlt.createNewTask(
            content,
            Censorlt.VoilationType.VULGAR,
            Censorlt.ContentType.TEXT
        );

        // Create signature
        uint256 contentId = 0;
        bool vote = true;
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                contentId,
                vote,
                operator
            )
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Setup mock for signature verification
        stakeRegistry.setIsValidSignatureResponse(IERC1271Upgradeable.isValidSignature.selector);

        // Submit response
        vm.prank(operator);
        censorlt.respondToTask(contentId, vote, signature);

        // Verify response was recorded
        Censorlt.ContentReport memory report = censorlt.getReport(contentId);

        assertEq(report.keepCount, 1);
        assertEq(report.removeCount, 0);
        assertEq(report.hasVoted[0], operator);
    }

    // ... [rest of the test functions remain the same]

    // Helper function to create and submit a vote for a given operator
    function createAndSubmitVote(address op, bool vote) internal {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                uint256(0),
                vote,
                op
            )
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethSignedMessageHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        
        vm.prank(op);
        censorlt.respondToTask(0, vote, sig);
    }

    function testMultipleVotesCount() public {
        // Create task
        vm.prank(reporter);
        censorlt.createNewTask(
            "Test content",
            Censorlt.VoilationType.VULGAR,
            Censorlt.ContentType.TEXT
        );

        // Setup additional operators
        address operator2 = makeAddr("operator2");
        address operator3 = makeAddr("operator3");
        stakeRegistry.setOperatorRegistered(operator2, true);
        stakeRegistry.setOperatorRegistered(operator3, true);

        // Setup mock signature verification
        stakeRegistry.setIsValidSignatureResponse(IERC1271Upgradeable.isValidSignature.selector);

        // Submit votes using the helper function
        createAndSubmitVote(operator, true);   // keep
        createAndSubmitVote(operator2, false); // remove
        createAndSubmitVote(operator3, false); // remove

        // Verify final counts
        Censorlt.ContentReport memory report = censorlt.getReport(0);

        assertEq(report.keepCount, 1);
        assertEq(report.removeCount, 2);
        assertEq(report.hasVoted.length, 3);
    }
}