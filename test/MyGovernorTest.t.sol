// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
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

    uint256 public constant MIN_DELAY = 3600; // 1 hour

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
}
