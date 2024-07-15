// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./CairoLib.sol";

using CairoLib for uint256;

/// @notice EVM adapter into a Cairo ERC20 token
/// @author Kakarot
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract DualVMToken {
    /*//////////////////////////////////////////////////////////////
                        CAIRO SPECIFIC VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The address of the starknet token to call
    uint256 immutable starknetToken;

    /// @dev The address of the kakarot starknet contract to call
    uint256 immutable kakarot;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA ACCESS
    //////////////////////////////////////////////////////////////*/

    function name() public view returns (string memory) {
        bytes memory returnData = starknetToken.staticcallCairo("name");
        return CairoLib.byteArrayToString(returnData);
    }

    function symbol() public view returns (string memory) {
        bytes memory returnData = starknetToken.staticcallCairo("symbol");
        return CairoLib.byteArrayToString(returnData);
    }

    function decimals() public view returns (uint8) {
        bytes memory returnData = starknetToken.staticcallCairo("decimals");
        return abi.decode(returnData, (uint8));
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    function totalSupply() public view returns (uint256) {
        bytes memory returnData = starknetToken.staticcallCairo("total_supply");
        return abi.decode(returnData, (uint256));
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256[] memory kakarotCallData = new uint256[](1);
        kakarotCallData[0] = uint256(uint160(account));
        uint256 accountStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", kakarotCallData), (uint256));
        uint256[] memory balanceOfCallData = new uint256[](1);
        balanceOfCallData[0] = accountStarknetAddress;
        bytes memory returnData = starknetToken.staticcallCairo("balance_of", balanceOfCallData);
        (uint128 valueLow, uint128 valueHigh) = abi.decode(returnData, (uint128, uint128));
        return uint256(valueLow) + (uint256(valueHigh) << 128);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        uint256[] memory ownerAddressCalldata = new uint256[](1);
        ownerAddressCalldata[0] = uint256(uint160(owner));
        uint256 ownerStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", ownerAddressCalldata), (uint256));

        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", spenderAddressCalldata), (uint256));

        uint256[] memory allowanceCallData = new uint256[](2);
        allowanceCallData[0] = ownerStarknetAddress;
        allowanceCallData[1] = spenderStarknetAddress;

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

    //     /*//////////////////////////////////////////////////////////////
    //                                ERC20 LOGIC
    //     //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", spenderAddressCalldata), (uint256));

        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);
        uint256[] memory approveCallData = new uint256[](3);
        approveCallData[0] = spenderStarknetAddress;
        approveCallData[1] = uint256(amountLow);
        approveCallData[2] = uint256(amountHigh);

        starknetToken.delegatecallCairo("approve", approveCallData);

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256[] memory toAddressCalldata = new uint256[](1);
        toAddressCalldata[0] = uint256(uint160(to));
        uint256 toStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", toAddressCalldata), (uint256));

        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferCallData = new uint256[](3);
        transferCallData[0] = toStarknetAddress;
        transferCallData[1] = uint256(amountLow);
        transferCallData[2] = uint256(amountHigh);

        starknetToken.delegatecallCairo("transfer", transferCallData);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256[] memory fromAddressCalldata = new uint256[](1);
        fromAddressCalldata[0] = uint256(uint160(from));
        uint256 fromStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", fromAddressCalldata), (uint256));

        uint256[] memory toAddressCalldata = new uint256[](1);
        toAddressCalldata[0] = uint256(uint160(to));
        uint256 toStarknetAddress =
            abi.decode(kakarot.staticcallCairo("compute_starknet_address", toAddressCalldata), (uint256));

        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferFromCallData = new uint256[](4);
        transferFromCallData[0] = fromStarknetAddress;
        transferFromCallData[1] = toStarknetAddress;
        transferFromCallData[2] = uint256(amountLow);
        transferFromCallData[3] = uint256(amountHigh);

        starknetToken.delegatecallCairo("transfer_from", transferFromCallData);

        emit Transfer(from, to, amount);

        return true;
    }
}
