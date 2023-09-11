// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./RevertTestCases.sol";

interface ICounter {
    function count() external view returns (uint256);

    function inc() external;

    function dec() external;

    function reset() external;
}

/// @notice Contract for integration testing of EVM opcodes.
/// @author Kakarot9000
/// @dev Add functions and storage variables for opcodes accordingly.
contract PlainOpcodes {
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    ICounter counter;

    event CreateAddress(address _address) anonymous;
    event Create2Address(address _address) anonymous;
    event Log0() anonymous;
    event Log0Value(uint256 value) anonymous;
    event Log1(uint256 value);
    event Log2(address indexed owner, uint256 value);
    event Log3(address indexed owner, address indexed spender, uint256 value);
    event Log4(address indexed owner, address indexed spender, uint256 indexed value);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address counterAddress) {
        counter = ICounter(counterAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS FOR OPCODES
    //////////////////////////////////////////////////////////////*/
    function opcodeBlockHash(uint256 blockNumber) public view returns (bytes32 _blockhash) {
        return (blockhash(blockNumber));
    }

    function opcodeTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function opcodeAddress() public view returns (address selfAddress) {
        return (address(this));
    }

    function opcodeStaticCall() public view returns (uint256) {
        return counter.count();
    }

    function opcodeStaticCall2() public view returns (bool, bytes memory) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("inc()")));
        return address(counter).staticcall(data);
    }

    function opcodeCall() public {
        counter.inc();
    }

    function opcodeLog0() public {
        emit Log0();
    }

    function opcodeLog0Value() public {
        emit Log0Value(10);
    }

    function opcodeLog1() public {
        emit Log1(10);
    }

    function opcodeLog2() public {
        emit Log2(address(0xa), 10);
    }

    function opcodeLog3() public {
        emit Log3(address(0xa), address(0xb), 10);
    }

    function opcodeLog4() public {
        emit Log4(address(0xa), address(0xb), 10);
    }

    function create(bytes memory bytecode, uint256 count) public returns (address[] memory) {
        address[] memory addresses = new address[](count);
        address _address;
        for (uint256 i = 0; i < count; i++) {
            assembly {
                _address := create(0, add(bytecode, 32), mload(bytecode))
            }
            addresses[i] = _address;
            emit CreateAddress(_address);
        }
        return addresses;
    }

    function create2(bytes memory bytecode, uint256 salt) public returns (address _address) {
        assembly {
            _address := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        emit Create2Address(_address);
    }

    function requireNotZero(uint256 value) external pure {
        require(value != 0, "ZERO_VALUE");
    }

    function originAndSender() external view returns (address origin, address sender) {
        return (tx.origin, msg.sender);
    }

    function opcodeExtCodeCopy(uint256 offset, uint256 size) external view returns (bytes memory extcode) {
        // see https://docs.soliditylang.org/en/v0.8.17/assembly.html#example
        address target = address(counter);
        assembly {
            // Get a free memory location
            extcode := mload(0x40)
            // Update free memory pointer (pointer += size including padding)
            mstore(0x40, add(extcode, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // Copy counter code to this location + size
            mstore(extcode, size)
            extcodecopy(target, add(extcode, 0x20), offset, size)
        }
    }

    function newContractConstructorRevert() public {
        new ContractRevertsOnConstruction();
    }

    function contractCallRevert() external returns (bool, bytes memory) {
        ContractRevertsOnMethodCall doomedContract = new ContractRevertsOnMethodCall();
        return address(doomedContract).call(abi.encodeWithSignature("triggerRevert()"));
    }

    function loop(uint256 steps) public pure returns (uint256) {
        uint256 loopValue;
        for (uint256 i = 0; i < steps; i++) {
            loopValue += 1;
        }
        return loopValue;
    }

    function sendSome(address payable to, uint256 amount) public {
        bool success = to.send(amount);
        require(success, "failed to send");
    }
}
