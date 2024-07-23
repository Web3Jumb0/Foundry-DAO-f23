// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor private _governor;
    Box private _box;
    TimeLock private _timeLock;
    GovToken private _govToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] public proposers;
    address[] public executors;
    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    function setUp() public {
        _govToken = new GovToken();
        _govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        _govToken.delegate(USER);
        _timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        _governor = new MyGovernor(_govToken, _timeLock);

        bytes32 proposerRole = _timeLock.PROPOSER_ROLE();
        bytes32 executorRole = _timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = _timeLock.TIMELOCK_ADMIN_ROLE();

        _timeLock.grantRole(proposerRole, address(_governor));
        _timeLock.grantRole(executorRole, address(0));
        _timeLock.revokeRole(adminRole, USER);
        vm.stopPrank();

        _box = new Box();
        _box.transferOwnership(address(_timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        _box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "stroe 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(_box));

        //1. propose to the DAO
        uint256 proposalId = _governor.propose(targets, values, calldatas, description);

        // Vie the state
        console.log("Proposal State: ", uint256(_governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: ", uint256(_governor.state(proposalId)));

        //2. vote
        string memory reason = "I want to store 1 in Box";

        uint8 voteWay = 1;
        vm.prank(USER);
        _governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        _governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the TX
        _governor.execute(targets, values, calldatas, descriptionHash);

        assert(_box.getNumber() == valueToStore);
        console.log("Box Value: ", _box.getNumber());
    }
}
