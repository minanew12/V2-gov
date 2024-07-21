// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {IGovernanceV2} from "../src/interfaces/IGovernanceV2.sol";
import {ILQTY} from "../src/interfaces/ILQTY.sol";

import {BribeInitiative} from "../src/BribeInitiative.sol";
import {GovernanceV2} from "../src/GovernanceV2.sol";
import {UserProxy} from "../src/UserProxy.sol";

import {PermitParams} from "../src/utils/Types.sol";

contract GovernanceV2Test is Test {
    IERC20 private constant lqty = IERC20(address(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D));
    IERC20 private constant lusd = IERC20(address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0));
    address private constant stakingV1 = address(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d);
    address private constant user = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address private constant lusdHolder = address(0xcA7f01403C4989d2b1A9335A2F09dD973709957c);

    uint256 private constant REGISTRATION_FEE = 1e18;
    uint256 private constant REGISTRATION_THRESHOLD_FACTOR = 0.01e18;
    uint256 private constant VOTING_THRESHOLD_FACTOR = 0.04e18;
    uint256 private constant MIN_CLAIM = 500e18;
    uint256 private constant MIN_ACCRUAL = 1000e18;
    uint256 private constant EPOCH_DURATION = 604800;
    uint256 private constant EPOCH_VOTING_CUTOFF = 518400;

    GovernanceV2 private governance;
    address[] private initialInitiatives;

    address private baseInitiative2;
    address private baseInitiative3;
    address private baseInitiative1;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        baseInitiative1 = address(
            new BribeInitiative(
                address(vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3)),
                address(lusd),
                address(lqty)
            )
        );

        baseInitiative2 = address(
            new BribeInitiative(
                address(vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2)),
                address(lusd),
                address(lqty)
            )
        );

        baseInitiative3 = address(
            new BribeInitiative(
                address(vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1)),
                address(lusd),
                address(lqty)
            )
        );

        initialInitiatives.push(baseInitiative1);
        initialInitiatives.push(baseInitiative2);

        governance = new GovernanceV2(
            address(lqty),
            address(lusd),
            stakingV1,
            address(lusd),
            IGovernanceV2.Configuration({
                registrationFee: REGISTRATION_FEE,
                regstrationThresholdFactor: REGISTRATION_THRESHOLD_FACTOR,
                votingThresholdFactor: VOTING_THRESHOLD_FACTOR,
                minClaim: MIN_CLAIM,
                minAccrual: MIN_ACCRUAL,
                epochStart: block.timestamp,
                epochDuration: EPOCH_DURATION,
                epochVotingCutoff: EPOCH_VOTING_CUTOFF
            }),
            initialInitiatives
        );
    }

    function test_depositLQTY_withdrawShares_v2() public {
        uint256 timeIncrease = 86400 * 30;
        vm.warp(block.timestamp + timeIncrease);

        vm.startPrank(user);

        // check address
        address userProxy = governance.deriveUserProxyAddress(user);

        // deploy and deposit 1 LQTY
        lqty.approve(address(userProxy), 1e18);
        governance.depositLQTY(1e18);
        assertEq(UserProxy(payable(userProxy)).staked(), 1e18);
        (uint96 allocatedLQTY, uint32 averageStakingTimestamp) = governance.userStates(user);
        assertEq(allocatedLQTY, 0);
        assertEq(averageStakingTimestamp, block.timestamp);
        (uint96 totalStakedLQTY, uint32 totalStakedLQTYAverageTimestamp,,) = governance.globalState();
        assertEq(totalStakedLQTY, 1e18);
        assertEq(totalStakedLQTYAverageTimestamp, block.timestamp);

        vm.warp(block.timestamp + timeIncrease);

        lqty.approve(address(userProxy), 1e18);
        governance.depositLQTY(1e18);
        assertEq(UserProxy(payable(userProxy)).staked(), 2e18);
        (allocatedLQTY, averageStakingTimestamp) = governance.userStates(user);
        assertEq(allocatedLQTY, 0);
        assertEq(averageStakingTimestamp, block.timestamp - timeIncrease / 2);
        (totalStakedLQTY, totalStakedLQTYAverageTimestamp,,) = governance.globalState();
        assertEq(totalStakedLQTY, 2e18);
        assertEq(totalStakedLQTYAverageTimestamp, block.timestamp - timeIncrease / 2);

        // withdraw 0.5 half of shares
        vm.warp(block.timestamp + timeIncrease);
        governance.withdrawLQTY(1e18);
        assertEq(UserProxy(payable(userProxy)).staked(), 1e18);
        (allocatedLQTY, averageStakingTimestamp) = governance.userStates(user);
        assertEq(allocatedLQTY, 0);
        assertEq(averageStakingTimestamp, (block.timestamp - timeIncrease) - timeIncrease / 2);
        (totalStakedLQTY, totalStakedLQTYAverageTimestamp,,) = governance.globalState();
        assertEq(totalStakedLQTY, 1e18);
        assertEq(totalStakedLQTYAverageTimestamp, (block.timestamp - timeIncrease) - timeIncrease / 2);

        // withdraw remaining shares
        governance.withdrawLQTY(1e18);
        assertEq(UserProxy(payable(userProxy)).staked(), 0);
        (allocatedLQTY, averageStakingTimestamp) = governance.userStates(user);
        assertEq(allocatedLQTY, 0);
        assertEq(averageStakingTimestamp, (block.timestamp - timeIncrease) - timeIncrease / 2);
        (totalStakedLQTY, totalStakedLQTYAverageTimestamp,,) = governance.globalState();
        assertEq(totalStakedLQTY, 0);
        assertEq(totalStakedLQTYAverageTimestamp, (block.timestamp - timeIncrease) - timeIncrease / 2);

        vm.stopPrank();
    }

    function test_depositLQTYViaPermit_v2() public {
        uint256 timeIncrease = 86400 * 30;
        vm.warp(block.timestamp + timeIncrease);

        vm.startPrank(user);
        VmSafe.Wallet memory wallet = vm.createWallet(uint256(keccak256(bytes("1"))));
        lqty.transfer(wallet.addr, 1e18);
        vm.stopPrank();
        vm.startPrank(wallet.addr);

        // check address
        address userProxy = governance.deriveUserProxyAddress(wallet.addr);

        PermitParams memory permitParams = PermitParams({
            owner: wallet.addr,
            spender: address(userProxy),
            value: 1e18,
            deadline: block.timestamp + 86400,
            v: 0,
            r: "",
            s: ""
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            wallet.privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ILQTY(address(lqty)).domainSeparator(),
                    keccak256(
                        abi.encode(
                            0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9,
                            permitParams.owner,
                            permitParams.spender,
                            permitParams.value,
                            0,
                            permitParams.deadline
                        )
                    )
                )
            )
        );

        permitParams.v = v;
        permitParams.r = r;
        permitParams.s = s;

        // deploy and deposit 1 LQTY
        governance.depositLQTYViaPermit(1e18, permitParams);
        assertEq(UserProxy(payable(userProxy)).staked(), 1e18);
        (uint96 allocatedLQTY, uint32 averageStakingTimestamp) = governance.userStates(wallet.addr);
        assertEq(allocatedLQTY, 0);
        assertEq(averageStakingTimestamp, block.timestamp);
        (uint96 totalStakedLQTY, uint32 totalStakedLQTYAverageTimestamp,,) = governance.globalState();
        assertEq(totalStakedLQTY, 1e18);
        assertEq(totalStakedLQTYAverageTimestamp, block.timestamp);
    }

    function test_epoch() public {
        assertEq(governance.epoch(), 1);

        vm.warp(block.timestamp + 7 days - 1);
        assertEq(governance.epoch(), 1);

        vm.warp(block.timestamp + 1);
        assertEq(governance.epoch(), 2);

        vm.warp(block.timestamp + 3653 days - 7 days);
        assertEq(governance.epoch(), 522); // number of weeks + 1
    }

    function test_calculateVotingThreshold() public {
        governance = new GovernanceV2(
            address(lqty),
            address(lusd),
            address(stakingV1),
            address(lusd),
            IGovernanceV2.Configuration({
                registrationFee: REGISTRATION_FEE,
                regstrationThresholdFactor: REGISTRATION_THRESHOLD_FACTOR,
                votingThresholdFactor: VOTING_THRESHOLD_FACTOR,
                minClaim: MIN_CLAIM,
                minAccrual: MIN_ACCRUAL,
                epochStart: block.timestamp,
                epochDuration: EPOCH_DURATION,
                epochVotingCutoff: EPOCH_VOTING_CUTOFF
            }),
            initialInitiatives
        );

        // check that votingThreshold is is high enough such that MIN_CLAIM is met
        IGovernanceV2.VoteSnapshot memory snapshot = IGovernanceV2.VoteSnapshot(1e18, 1);
        vm.store(address(governance), bytes32(uint256(2)), bytes32(abi.encode(snapshot)));
        (uint240 votes,) = governance.votesSnapshot();
        assertEq(votes, 1e18);

        uint256 boldAccrued = 1000e18;
        vm.store(address(governance), bytes32(uint256(1)), bytes32(abi.encode(boldAccrued)));
        assertEq(governance.boldAccrued(), 1000e18);

        assertEq(governance.calculateVotingThreshold(), MIN_CLAIM / 1000);

        // check that votingThreshold is 4% of votes of previous epoch
        governance = new GovernanceV2(
            address(lqty),
            address(lusd),
            address(stakingV1),
            address(lusd),
            IGovernanceV2.Configuration({
                registrationFee: REGISTRATION_FEE,
                regstrationThresholdFactor: REGISTRATION_THRESHOLD_FACTOR,
                votingThresholdFactor: VOTING_THRESHOLD_FACTOR,
                minClaim: 10e18,
                minAccrual: 10e18,
                epochStart: block.timestamp,
                epochDuration: EPOCH_DURATION,
                epochVotingCutoff: EPOCH_VOTING_CUTOFF
            }),
            initialInitiatives
        );

        snapshot = IGovernanceV2.VoteSnapshot(10000e18, 1);
        vm.store(address(governance), bytes32(uint256(2)), bytes32(abi.encode(snapshot)));
        (votes,) = governance.votesSnapshot();
        assertEq(votes, 10000e18);

        boldAccrued = 1000e18;
        vm.store(address(governance), bytes32(uint256(1)), bytes32(abi.encode(boldAccrued)));
        assertEq(governance.boldAccrued(), 1000e18);

        assertEq(governance.calculateVotingThreshold(), 10000e18 * 0.04);
    }

    function test_registerInitiative_v2() public {
        vm.startPrank(user);

        address userProxy = governance.deployUserProxy();

        IGovernanceV2.VoteSnapshot memory snapshot = IGovernanceV2.VoteSnapshot(1e18, 1);
        vm.store(address(governance), bytes32(uint256(2)), bytes32(abi.encode(snapshot)));
        (uint240 votes,) = governance.votesSnapshot();
        assertEq(votes, 1e18);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        governance.registerInitiative(baseInitiative3);

        vm.startPrank(lusdHolder);
        lusd.transfer(user, 1e18);
        vm.stopPrank();

        vm.startPrank(user);

        lusd.approve(address(governance), 1e18);

        vm.expectRevert("Governance: insufficient-lqty");
        governance.registerInitiative(baseInitiative3);

        lqty.approve(address(userProxy), 1e18);
        governance.depositLQTY(1e18);
        vm.warp(block.timestamp + 365 days);

        governance.registerInitiative(baseInitiative3);
        (,,,, uint16 atEpoch,) = governance.initiativeStates(baseInitiative3);
        assertEq(atEpoch, governance.epoch());

        vm.stopPrank();
    }

    function test_allocateLQTY_v2() public {
        vm.startPrank(user);

        address userProxy = governance.deployUserProxy();

        lqty.approve(address(userProxy), 1e18);
        governance.depositLQTY(1e18);

        (uint96 allocatedLQTY,) = governance.userStates(user);
        assertEq(allocatedLQTY, 0);
        (uint96 totalStakedLQTY,, uint96 countedVoteLQTY,) = governance.globalState();
        assertEq(totalStakedLQTY, 1e18);
        assertEq(countedVoteLQTY, 0);

        address[] memory initiatives = new address[](1);
        initiatives[0] = baseInitiative1;
        int192[] memory deltaLQTYVotes = new int192[](1);
        deltaLQTYVotes[0] = 1e18;
        int192[] memory deltaLQTYVetos = new int192[](1);

        vm.expectRevert("Governance: initiative-not-active");
        governance.allocateLQTY(initiatives, deltaLQTYVotes, deltaLQTYVetos);

        vm.warp(block.timestamp + 365 days);
        governance.allocateLQTY(initiatives, deltaLQTYVotes, deltaLQTYVetos);

        (allocatedLQTY,) = governance.userStates(user);
        assertEq(allocatedLQTY, 1e18);

        (uint96 voteLQTY, uint96 vetoLQTY, uint8 counted, uint8 active, uint16 atEpoch, uint32 averageStakingTimestamp)
        = governance.initiativeStates(baseInitiative1);
        assertEq(voteLQTY, 1e18);
        assertEq(vetoLQTY, 0);
        assertEq(counted, 1);
        assertEq(active, 1);
        assertEq(atEpoch, governance.epoch());
        assertEq(averageStakingTimestamp, block.timestamp - 365 days);

        uint32 countedVoteLQTYAverageTimestamp;
        (,, countedVoteLQTY, countedVoteLQTYAverageTimestamp) = governance.globalState();
        assertEq(countedVoteLQTY, 1e18);

        (voteLQTY, vetoLQTY, atEpoch) = governance.lqtyAllocatedByUserToInitiative(user, baseInitiative1);
        assertEq(voteLQTY, 1e18);
        assertEq(vetoLQTY, 0);
        assertEq(atEpoch, governance.epoch());
        assertGt(atEpoch, 0);

        vm.expectRevert("Governance: insufficient-unallocated-lqty");
        governance.withdrawLQTY(1e18);

        vm.warp(block.timestamp + EPOCH_DURATION - governance.secondsDuringCurrentEpoch() - 1);

        initiatives[0] = baseInitiative1;
        deltaLQTYVotes[0] = 1e18;
        vm.expectRevert("Governance: epoch-voting-cutoff");
        governance.allocateLQTY(initiatives, deltaLQTYVotes, deltaLQTYVetos);

        initiatives[0] = baseInitiative1;
        deltaLQTYVotes[0] = -1e18;
        governance.allocateLQTY(initiatives, deltaLQTYVotes, deltaLQTYVetos);

        (allocatedLQTY,) = governance.userStates(user);
        assertEq(allocatedLQTY, 0);
        (,, countedVoteLQTY,) = governance.globalState();
        assertEq(countedVoteLQTY, 0);

        vm.stopPrank();
    }

    function test_claimForInitiative() public {
        vm.startPrank(user);

        // deploy
        address userProxy = governance.deployUserProxy();

        lqty.approve(address(userProxy), 1000e18);
        governance.depositLQTY(1000e18);

        vm.warp(block.timestamp + 365 days);

        vm.stopPrank();

        vm.startPrank(lusdHolder);
        lusd.transfer(address(governance), 10000e18);
        vm.stopPrank();

        vm.startPrank(user);

        address[] memory initiatives = new address[](2);
        initiatives[0] = baseInitiative1;
        initiatives[1] = baseInitiative2;
        int192[] memory deltaVoteLQTY = new int192[](2);
        deltaVoteLQTY[0] = 500e18;
        deltaVoteLQTY[1] = 500e18;
        int192[] memory deltaVetoLQTY = new int192[](2);
        governance.allocateLQTY(initiatives, deltaVoteLQTY, deltaVetoLQTY);
        (uint96 allocatedLQTY,) = governance.userStates(user);
        assertEq(allocatedLQTY, 1000e18);

        vm.warp(block.timestamp + governance.EPOCH_DURATION() + 1);

        assertEq(governance.claimForInitiative(baseInitiative1), 5000e18);
        governance.claimForInitiative(baseInitiative1);
        assertEq(governance.claimForInitiative(baseInitiative1), 0);

        assertEq(lusd.balanceOf(baseInitiative1), 5000e18);

        assertEq(governance.claimForInitiative(baseInitiative2), 5000e18);
        assertEq(governance.claimForInitiative(baseInitiative2), 0);

        assertEq(lusd.balanceOf(baseInitiative2), 5000e18);

        vm.stopPrank();

        vm.startPrank(lusdHolder);
        lusd.transfer(address(governance), 10000e18);
        vm.stopPrank();

        vm.startPrank(user);

        initiatives[0] = baseInitiative1;
        initiatives[1] = baseInitiative2;
        deltaVoteLQTY[0] = 495e18;
        deltaVoteLQTY[1] = -495e18;
        governance.allocateLQTY(initiatives, deltaVoteLQTY, deltaVetoLQTY);

        vm.warp(block.timestamp + governance.EPOCH_DURATION() + 1);

        assertEq(governance.claimForInitiative(baseInitiative1), 10000e18);
        assertEq(governance.claimForInitiative(baseInitiative1), 0);

        assertEq(lusd.balanceOf(baseInitiative1), 15000e18);

        assertEq(governance.claimForInitiative(baseInitiative2), 0);
        assertEq(governance.claimForInitiative(baseInitiative2), 0);

        assertEq(lusd.balanceOf(baseInitiative2), 5000e18);

        vm.stopPrank();
    }

    function test_multicall() public {
        vm.startPrank(user);

        vm.warp(block.timestamp + 365 days);

        uint96 lqtyAmount = 1000e18;
        uint256 lqtyBalance = lqty.balanceOf(user);

        lqty.approve(address(governance.deriveUserProxyAddress(user)), lqtyAmount);

        bytes[] memory data = new bytes[](7);
        address[] memory initiatives = new address[](1);
        initiatives[0] = baseInitiative1;
        int192[] memory deltaVoteLQTY = new int192[](1);
        deltaVoteLQTY[0] = int192(uint192(lqtyAmount));
        int192[] memory deltaVetoLQTY = new int192[](1);

        int192[] memory deltaVoteLQTY_ = new int192[](1);
        deltaVoteLQTY_[0] = -int192(uint192(lqtyAmount));

        data[0] = abi.encodeWithSignature("deployUserProxy()");
        data[1] = abi.encodeWithSignature("depositLQTY(uint96)", lqtyAmount);
        data[2] = abi.encodeWithSignature(
            "allocateLQTY(address[],int192[],int192[])", initiatives, deltaVoteLQTY, deltaVetoLQTY
        );
        data[3] = abi.encodeWithSignature("userStates(address)", user);
        data[4] = abi.encodeWithSignature("snapshotVotesForInitiative(address)", baseInitiative1);
        data[5] = abi.encodeWithSignature(
            "allocateLQTY(address[],int192[],int192[])", initiatives, deltaVoteLQTY_, deltaVetoLQTY
        );
        data[6] = abi.encodeWithSignature("withdrawLQTY(uint96)", lqtyAmount);
        bytes[] memory response = governance.multicall(data);

        (uint96 allocatedLQTY,) = abi.decode(response[3], (uint96, uint32));
        assertEq(allocatedLQTY, lqtyAmount);
        (IGovernanceV2.VoteSnapshot memory votes, IGovernanceV2.InitiativeVoteSnapshot memory votesForInitiative) =
            abi.decode(response[4], (IGovernanceV2.VoteSnapshot, IGovernanceV2.InitiativeVoteSnapshot));
        assertEq(votes.votes + votesForInitiative.votes, 0);
        assertEq(lqty.balanceOf(user), lqtyBalance);

        vm.stopPrank();
    }
}
