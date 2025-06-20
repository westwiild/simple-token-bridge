// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title TokenBridge
 * @dev Contract for locking tokens on the origin chain (Chain A)
 */
contract TokenBridge is OApp {
    using SafeERC20 for IERC20;

    IERC20 public immutable ORIGIN_TOKEN;
    uint32 public immutable DST_EID;

    mapping(bytes32 => bool) public processedDeposits;
    uint256 public totalLocked;

    error ZeroAmount();
    error ZeroAddress();
    error AlreadyProcessed();
    error InsufficientNativeFee();

    event TokensLocked(address indexed user, address indexed recipient, uint256 amount, bytes32 indexed txHash);

    /**
     * @dev Constructor sets the original token and oracle addresses
     * @param _originToken Address of the token to be bridged
     * @param endpoint Address of the endpoint
     * @param _dstEid Destination chain ID
     */
    constructor(address _originToken, address endpoint, uint32 _dstEid)
        Ownable(msg.sender)
        OApp(endpoint, msg.sender)
    {
        if (_originToken == address(0)) revert ZeroAddress();

        ORIGIN_TOKEN = IERC20(_originToken);
        DST_EID = _dstEid;
    }

    /**
     * @dev Locks tokens on Chain A and emits event for oracle to process on Chain B
     * @param amount Amount of tokens to lock
     * @param recipient Address that will receive wrapped tokens on Chain B
     */
    function lockTokens(uint256 amount, address recipient) external payable {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Get current transaction hash for anti-replay protection
        bytes32 txHash =
            keccak256(abi.encodePacked(block.chainid, block.number, block.timestamp, msg.sender, amount, recipient));

        if (processedDeposits[txHash]) revert AlreadyProcessed();
        processedDeposits[txHash] = true;

        // Transfer tokens from user to this contract
        ORIGIN_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        totalLocked += amount;

        emit TokensLocked(msg.sender, recipient, amount, txHash);

        bytes memory payload = abi.encode(msg.sender, recipient, amount, txHash);
        MessagingFee memory fee = quote(msg.sender, recipient, amount, txHash);
        if (fee.nativeFee > msg.value) revert InsufficientNativeFee();
        _lzSend(DST_EID, payload, createLzReceiveOption(300000, 0), MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /**
     * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param from The address to send the message from.
     * @param to The address to send the message to.
     * @param value The value to send with the message.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(address from, address to, uint256 value, bytes32 txHash)
        public
        view
        returns (MessagingFee memory fee)
    {
        bytes memory payload = abi.encode(from, to, value, txHash);
        fee = _quote(DST_EID, payload, createLzReceiveOption(300000, 0), false);
    }

    /**
     * @notice Creates LayerZero receive options with specified gas and value parameters
     * @param _gas Amount of gas to provide for execution
     * @param _value Native token value to attach
     * @return bytes Encoded options for LayerZero receive
     */
    function createLzReceiveOption(uint128 _gas, uint128 _value) public pure returns (bytes memory) {
        return OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), _gas, _value);
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata, address, bytes calldata) internal override {}
}
