// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

contract DualVmTokenHack {
    address target;
    uint256 constant AMOUNT = 1337;

    constructor(address _target) {
        target = _target;
    }

    function tryApproveEvm() external returns (bool success) {
        (success,) = target.delegatecall{gas: 30000}(
            abi.encodeWithSelector(bytes4(keccak256("approve(address,uint256)")), address(this), AMOUNT)
        );
    }

    function tryApproveStarknet() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("approve(uint256,uint256)")), uint256(uint160(address(this))), AMOUNT
            )
        );
    }

    function tryTransferEvm() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(this), AMOUNT)
        );
    }

    function tryTransferStarknet() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("transfer(uint256,uint256)")), uint256(uint160(address(this))), AMOUNT
            )
        );
    }

    function tryTransferFromEvmEvm() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(address,address,uint256)")), msg.sender, address(this), AMOUNT
            )
        );
    }

    function tryTransferFromStarknetEvm() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(uint256,address,uint256)")),
                uint256(uint160(msg.sender)),
                address(this),
                AMOUNT
            )
        );
    }

    function tryTransferFromEvmStarknet() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(address,uint256,uint256)")),
                msg.sender,
                uint256(uint160(address(this))),
                AMOUNT
            )
        );
    }

    function tryTransferFromStarknetStarknet() external returns (bool success) {
        (success,) = target.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(uint256,uint256,uint256)")),
                uint256(uint160(msg.sender)),
                uint256(uint160(address(this))),
                AMOUNT
            )
        );
    }
}
