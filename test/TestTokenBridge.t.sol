// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {TokenBridge} from "../src/TokenBridge.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {WrappedToken} from "../src/WrappedToken.sol";

contract TestTokenBridge is Test {
    uint32 public constant EXECUTOR_CONFIG_TYPE = 1;
    uint32 public constant ULN_CONFIG_TYPE = 2;
    uint32 public constant RECEIVE_CONFIG_TYPE = 2;
    uint32 public sepoliaEID;
    uint32 public holeskyEID;

    uint256 public sepoliaFork;
    uint256 public holeskyFork;
    address public owner;
    MockERC20 public token;
    TokenBridge public tokenBridge;
    WrappedToken public wrappedToken;

    function setUp() public {
        sepoliaEID = uint32(vm.envUint("SEPOLIA_EID"));
        holeskyEID = uint32(vm.envUint("HOLESKY_EID"));
        createFork();
        owner = makeAddr("OWNER");
        vm.selectFork(sepoliaFork);
        vm.deal(owner, 100 ether);
        vm.selectFork(holeskyFork);
        vm.deal(owner, 100 ether);

        deploySepolia();
        deployHolesky();

        setPeer();

        setSendConfig();
        setReceiveConfig();

        vm.selectFork(sepoliaFork);
        vm.startBroadcast(owner);
        token.approve(address(tokenBridge), 1000000000000000000000000);
        vm.stopBroadcast();
    }

    function createFork() internal {
        sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        holeskyFork = vm.createFork(vm.envString("HOLESKY_RPC_URL"));
    }

    function deploySepolia() internal {
        vm.selectFork(sepoliaFork);
        vm.startBroadcast(owner);

        token = new MockERC20("MockERC20", "MCK");
        token.mint(owner, 1000000000000000000000000);

        tokenBridge = new TokenBridge(address(token), vm.envAddress("SEPOLIA_ENDPOINT_V2"), holeskyEID);

        vm.stopBroadcast();
    }

    function deployHolesky() internal {
        vm.selectFork(holeskyFork);
        vm.startBroadcast(owner);
        wrappedToken = new WrappedToken("Wrapped MockERC20", "wMCK", vm.envAddress("HOLESKY_ENDPOINT_V2"));
        vm.stopBroadcast();
    }

    function setPeer() internal {
        vm.selectFork(sepoliaFork);
        vm.startBroadcast(owner);
        tokenBridge.setPeer(holeskyEID, addressToBytes32(address(wrappedToken)));
        vm.stopBroadcast();

        vm.selectFork(holeskyFork);
        vm.startBroadcast(owner);
        wrappedToken.setPeer(sepoliaEID, addressToBytes32(address(tokenBridge)));
        vm.stopBroadcast();
    }

    function setSendConfig() internal {
        address endpoint = vm.envAddress("SEPOLIA_ENDPOINT_V2");
        address oapp = address(tokenBridge);
        uint32 eid = holeskyEID;
        address sendLib = vm.envAddress("SEPOLIA_SEND_LIB");

        /// @notice ULNConfig defines security parameters (DVNs + confirmation threshold)
        /// @notice Send config requests these settings to be applied to the DVNs and Executor
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations: 15, // minimum block confirmations required
            requiredDVNCount: 1, // number of DVNs required
            optionalDVNCount: type(uint8).max, // optional DVNs count, uint8
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: new address[](1), // sorted list of required DVN addresses
            optionalDVNs: new address[](0) // sorted list of optional DVNs
        });
        uln.requiredDVNs[0] = vm.envAddress("LAYERZERO_SEPOLIA_DVN");

        /// @notice ExecutorConfig sets message size limit + fee‑paying executor
        ExecutorConfig memory exec = ExecutorConfig({
            maxMessageSize: 10000, // max bytes per cross-chain message
            executor: vm.envAddress("SEPOLIA_EXECUTOR") // address that pays destination execution fees
        });

        bytes memory encodedUln = abi.encode(uln);
        bytes memory encodedExec = abi.encode(exec);

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam(eid, EXECUTOR_CONFIG_TYPE, encodedExec);
        params[1] = SetConfigParam(eid, ULN_CONFIG_TYPE, encodedUln);

        vm.selectFork(sepoliaFork);
        vm.startBroadcast(owner);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, sendLib, params);
        vm.stopBroadcast();
    }

    function setReceiveConfig() internal {
        address endpoint = vm.envAddress("HOLESKY_ENDPOINT_V2");
        address oapp = address(wrappedToken);
        uint32 eid = sepoliaEID;
        address receiveLib = vm.envAddress("HOLESKY_RECEIVE_LIB");

        /// @notice UlnConfig controls verification threshold for incoming messages
        /// @notice Receive config enforces these settings have been applied to the DVNs and Executor
        /// @dev 0 values will be interpretted as defaults, so to apply NIL settings, use:
        /// @dev uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
        /// @dev uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
        UlnConfig memory uln = UlnConfig({
            confirmations: 15, // min block confirmations from source
            requiredDVNCount: 1, // required DVNs for message acceptance
            optionalDVNCount: type(uint8).max, // optional DVNs count
            optionalDVNThreshold: 0, // optional DVN threshold
            requiredDVNs: new address[](1), // sorted required DVNs
            optionalDVNs: new address[](0) // no optional DVNs
        });
        uln.requiredDVNs[0] = vm.envAddress("LAYERZERO_HOLESKY_DVN");

        bytes memory encodedUln = abi.encode(uln);

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(eid, RECEIVE_CONFIG_TYPE, encodedUln);

        vm.selectFork(holeskyFork);
        vm.startBroadcast(owner);
        ILayerZeroEndpointV2(endpoint).setConfig(oapp, receiveLib, params);
        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function test_TokenBalance() public {
        vm.selectFork(sepoliaFork);
        assertEq(token.balanceOf(owner), 1000000000000000000000000, "Token balance should be 1M tokens");
    }

    function test_lockTokens() public {
        vm.selectFork(sepoliaFork);
        vm.startBroadcast(owner);
        MessagingFee memory fee = tokenBridge.quote(owner, owner, 1000000000000000000000000, bytes32(0));
        console.log("Fee", fee.nativeFee);

        tokenBridge.lockTokens{value: (fee.nativeFee * 12) / 10}(1000000000000000000000000, owner);
        vm.stopBroadcast();
    }
}
