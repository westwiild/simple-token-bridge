// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {OApp, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title TokenBridge
 * @dev Contract for locking tokens on the origin chain (Chain A)
 */
contract WrappedToken is OApp, ERC20 {
    mapping(bytes32 => bool) public processedMints;

    event TokensMinted(address indexed sender, address indexed recipient, uint256 amount, bytes32 indexed txHash);

    error AlreadyProcessed();

    /**
     * @dev Constructor sets the original token and oracle addresses
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param endpoint Address of the endpoint
     */
    constructor(string memory name, string memory symbol, address endpoint)
        OApp(endpoint, msg.sender)
        Ownable(msg.sender)
        ERC20(name, symbol)
    {}

    /**
     * @dev Called when data is received from the protocol. It overrides the equivalent function in the parent contract.
     * Protocol messages are defined as packets, comprised of the following parameters.
     * @param _message Encoded message.
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata _message, address, bytes calldata) internal override {
        (address sender, address recipient, uint256 amount, bytes32 txHash) =
            abi.decode(_message, (address, address, uint256, bytes32));
        if (processedMints[txHash]) revert AlreadyProcessed();
        processedMints[txHash] = true;
        _mint(recipient, amount);
        emit TokensMinted(sender, recipient, amount, txHash);
    }
}
