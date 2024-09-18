// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

using CairoLib for uint256;

/// @notice EVM adapter into a Cairo ERC20 token
/// @dev This implementation is highly experimental
///      It relies on CairoLib to perform Cairo precompile calls
///      Events are emitted in this contract but also in the Starknet token contract
/// @author Kakarot
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
contract DualVmToken {
    /*//////////////////////////////////////////////////////////////
                        CAIRO SPECIFIC VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The address of the starknet token to call
    uint256 public immutable starknetToken;

    /// @dev The address of the kakarot starknet contract to call
    uint256 public immutable kakarot;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when tokens are transferred from one address to another
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @dev Emitted when tokens are transferred from one starknet address to another
    event TransferStarknet(uint256 indexed from, uint256 indexed to, uint256 amount);

    /// @dev Emitted when the allowance of a spender over the owner's tokens is set
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @dev Emitted when the allowance of a starknet address spender over the owner's tokens is set
    event ApprovalStarknet(address indexed owner, uint256 indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA ACCESS
    //////////////////////////////////////////////////////////////*/

    function name() external view returns (string memory) {
        bytes memory returnData = starknetToken.staticcallCairo("name");
        return CairoLib.byteArrayToString(returnData);
    }

    function symbol() external view returns (string memory) {
        bytes memory returnData = starknetToken.staticcallCairo("symbol");
        return CairoLib.byteArrayToString(returnData);
    }

    function decimals() external view returns (uint8) {
        bytes memory returnData = starknetToken.staticcallCairo("decimals");
        return abi.decode(returnData, (uint8));
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256) {
        bytes memory returnData = starknetToken.staticcallCairo("total_supply");
        return abi.decode(returnData, (uint256));
    }

    function balanceOf(address account) external view returns (uint256) {
        uint256[] memory kakarotCallData = new uint256[](1);
        kakarotCallData[0] = uint256(uint160(account));
        uint256 accountStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", kakarotCallData), (uint256));
        return _balanceOf(accountStarknetAddress);
    }

    /// @dev This function is used to get the balance of a starknet address
    /// @param starknetAddress The starknet address to get the balance of
    /// @return The balance of the starknet address
    function balanceOfStarknetAddress(uint256 starknetAddress) external view returns (uint256) {
        return _balanceOf(starknetAddress);
    }

    function _balanceOf(uint256 starknetAddress) private view returns (uint256) {
        uint256[] memory balanceOfCallData = new uint256[](1);
        balanceOfCallData[0] = starknetAddress;
        bytes memory returnData = starknetToken.staticcallCairo("balance_of", balanceOfCallData);
        (uint128 valueLow, uint128 valueHigh) = abi.decode(returnData, (uint128, uint128));
        return uint256(valueLow) + (uint256(valueHigh) << 128);
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        uint256[] memory ownerAddressCalldata = new uint256[](1);
        ownerAddressCalldata[0] = uint256(uint160(owner));
        uint256 ownerStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", ownerAddressCalldata), (uint256));

        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", spenderAddressCalldata), (uint256));

        return _allowance(ownerStarknetAddress, spenderStarknetAddress);
    }

    /// @dev Get the allowance of the spender when it is a starknet address
    /// @param owner The evm address of the owner of the tokens
    /// @param spender The starknet address of the spender to get the allowance of
    /// @return The allowance of spender over the owner's tokens
    function allowanceStarknetAddressSpender(address owner, uint256 spender) external view returns (uint256) {
        uint256[] memory ownerAddressCalldata = new uint256[](1);
        ownerAddressCalldata[0] = uint256(uint160(owner));
        uint256 ownerStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", ownerAddressCalldata), (uint256));

        return _allowance(ownerStarknetAddress, spender);
    }

    /// @dev Get the allowance of spender when the owner is a starknet address
    /// @param owner The starknet address of the owner of the tokens
    /// @param spender The evm address of the spender to get the allowance of
    /// @return The allowance of spender over the owner's tokens
    function allowanceStarknetAddressOwner(uint256 owner, address spender) external view returns (uint256) {
        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", spenderAddressCalldata), (uint256));

        return _allowance(owner, spenderStarknetAddress);
    }

    /// @dev Get the allowance of spender when both the owner and spender are starknet addresses
    /// @param owner The starknet address of the owner of the tokens
    /// @param spender The starknet address of the spender to get the allowance of
    /// @return The allowance of spender over the owner's tokens
    function allowanceStarknetAddressOwnerAndSpender(uint256 owner, uint256 spender) external view returns (uint256) {
        return _allowance(owner, spender);
    }

    function _allowance(uint256 owner, uint256 spender) private view returns (uint256) {
        uint256[] memory allowanceCallData = new uint256[](2);
        allowanceCallData[0] = owner;
        allowanceCallData[1] = spender;

        bytes memory returnData = starknetToken.staticcallCairo("allowance", allowanceCallData);
        (uint128 valueLow, uint128 valueHigh) = abi.decode(returnData, (uint128, uint128));

        return uint256(valueLow) + (uint256(valueHigh) << 128);
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
     //////////////////////////////////////////////////////////////*/

    constructor(uint256 _kakarot, uint256 _starknetToken) {
        kakarot = _kakarot;
        starknetToken = _starknetToken;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", spenderAddressCalldata), (uint256));

        _approve(spenderStarknetAddress, amount);

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @dev Approve a starknet address
    /// @param spender The starknet address to approve
    /// @param amount The amount of tokens to approve
    /// @return True if the approval was successful
    function approveStarknetAddress(uint256 spender, uint256 amount) external returns (bool) {
        _approve(spender, amount);
        emit ApprovalStarknet(msg.sender, spender, amount);
        return true;
    }

    function _approve(uint256 spender, uint256 amount) private {
        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);
        uint256[] memory approveCallData = new uint256[](3);
        approveCallData[0] = spender;
        approveCallData[1] = uint256(amountLow);
        approveCallData[2] = uint256(amountHigh);

        starknetToken.delegatecallCairo("approve", approveCallData);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256[] memory toAddressCalldata = new uint256[](1);
        toAddressCalldata[0] = uint256(uint160(to));
        uint256 toStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", toAddressCalldata), (uint256));

        _transfer(toStarknetAddress, amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Transfer tokens to a starknet address
    /// @param to The starknet address to transfer the tokens to
    /// @param amount The amount of tokens to transfer
    /// @return True if the transfer was successful
    function transferStarknetAddress(uint256 to, uint256 amount) external returns (bool) {
        _transfer(to, amount);
        emit TransferStarknet(uint256(uint160(msg.sender)), to, amount);
        return true;
    }

    function _transfer(uint256 to, uint256 amount) private {
        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferCallData = new uint256[](3);
        transferCallData[0] = to;
        transferCallData[1] = uint256(amountLow);
        transferCallData[2] = uint256(amountHigh);

        starknetToken.delegatecallCairo("transfer", transferCallData);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256[] memory toAddressCalldata = new uint256[](1);
        toAddressCalldata[0] = uint256(uint160(to));
        uint256 toStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", toAddressCalldata), (uint256));

        uint256[] memory fromAddressCalldata = new uint256[](1);
        fromAddressCalldata[0] = uint256(uint160(from));
        uint256 fromStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", fromAddressCalldata), (uint256));

        _transferFrom(fromStarknetAddress, toStarknetAddress, amount);

        emit Transfer(from, to, amount);
        return true;
    }

    /// @dev Transfer tokens from a starknet address
    /// @param from The starknet address to transfer the tokens from
    /// @param to The evm address to transfer the tokens to
    /// @param amount The amount of tokens to transfer
    /// @return True if the transfer was successful
    function transferFromStarknetAddressFrom(uint256 from, address to, uint256 amount) external returns (bool) {
        uint256[] memory toAddressCalldata = new uint256[](1);
        uint256 toAddressUint256 = uint256(uint160(to));
        toAddressCalldata[0] = toAddressUint256;
        uint256 toStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", toAddressCalldata), (uint256));

        _transferFrom(from, toStarknetAddress, amount);

        emit TransferStarknet(from, toAddressUint256, amount);
        return true;
    }

    /// @dev Transfer from tokens to a starknet address
    /// @param from The evm address to transfer the tokens from
    /// @param to The starknet address to transfer the tokens to
    /// @param amount The amount of tokens to transfer
    /// @return True if the transfer was successful
    function transferFromStarknetAddressTo(address from, uint256 to, uint256 amount) external returns (bool) {
        uint256[] memory fromAddressCalldata = new uint256[](1);
        uint256 fromAddressUint256 = uint256(uint160(from));
        fromAddressCalldata[0] = fromAddressUint256;
        uint256 fromStarknetAddress =
            abi.decode(kakarot.staticcallCairo("get_starknet_address", fromAddressCalldata), (uint256));

        _transferFrom(fromStarknetAddress, to, amount);

        emit TransferStarknet(fromAddressUint256, to, amount);
        return true;
    }

    /// @dev Transfer from tokens when both from and to address as starknet addresses
    /// @param from The starknet address to transfer the tokens from
    /// @param to The starknet address to transfer the tokens to
    /// @param amount The amount of tokens to transfer
    /// @return True if the transfer was successful
    function transferFromStarknetAddressFromAndTo(uint256 from, uint256 to, uint256 amount) external returns (bool) {
        _transferFrom(from, to, amount);
        emit TransferStarknet(from, to, amount);
        return true;
    }

    function _transferFrom(uint256 from, uint256 to, uint256 amount) private {
        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferFromCallData = new uint256[](4);
        transferFromCallData[0] = from;
        transferFromCallData[1] = to;
        transferFromCallData[2] = uint256(amountLow);
        transferFromCallData[3] = uint256(amountHigh);

        starknetToken.delegatecallCairo("transfer_from", transferFromCallData);
    }
}
