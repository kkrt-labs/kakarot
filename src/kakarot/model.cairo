// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.dict import DictAccess
from starkware.cairo.common.uint256 import Uint256

namespace model {
    // @notice Info: https://www.evm.codes/about#stack
    // @notice Stack with a 1024 items maximum size. Each item is a 256 bits word. The stack is used by most
    // @notice opcodes to consume their parameters from.
    // @dev The dict stores a pointer to the word (a Uint256).
    // @param size The size of the Stack.
    // @param dict_ptr_start pointer to a DictAccess array used to store the stack's value at a given index.
    // @param dict_ptr pointer to the end of the DictAccess array.
    struct Stack {
        dict_ptr_start: DictAccess*,
        dict_ptr: DictAccess*,
        size: felt,
    }

    // @notice info: https://www.evm.codes/about#memory
    // @notice Transient memory maintained by the EVM during an execution which doesn't persist
    // @notice between transactions.
    // @param word_dict_start pointer to a DictAccess used to store the memory's value at a given index.
    // @param word_dict pointer to the end of the DictAccess array.
    // @param words_len number of words (bytes32).
    struct Memory {
        word_dict_start: DictAccess*,
        word_dict: DictAccess*,
        words_len: felt,
    }

    // @dev In Cairo Zero, dict are list of DictAccess, ie that they can contain only felts. For having
    //      dict of structs, we store in the dict pointers to the struct. List of structs are just list of
    //      felt with inlined structs. Hence one has eventually
    //      accounts := Dict<starknet_address, Account*>
    //      events := List<Event>
    //      transfers := List<Transfer>
    //      Unlike in standard EVM, we need to store the native token transfers as well since we use the
    //      Starknet's ETH and can't just set the balances
    struct State {
        accounts_start: DictAccess*,
        accounts: DictAccess*,
        events_len: felt,
        events: Event*,
        transfers_len: felt,
        transfers: Transfer*,
    }

    // @notice The struct representing an EVM account.
    // @dev We don't put the balance here to avoid loading the whole Account just for sending ETH
    // @dev The address here is consequently an EVM address
    struct Account {
        address: felt,
        code_len: felt,
        code: felt*,
        storage_start: DictAccess*,
        storage: DictAccess*,
        nonce: felt,
        balance: Uint256*,
        selfdestruct: felt,
    }

    // @notice The struct representing an EVM event.
    // @dev The topics are indeed a first felt for the emitting EVM account, followed by a list of Uint256
    struct Event {
        topics_len: felt,
        topics: felt*,
        data_len: felt,
        data: felt*,
    }

    // @dev A struct to save Starknet native ETH transfers to be made when finalizing a tx
    struct Transfer {
        sender: Address*,
        recipient: Address*,
        amount: Uint256,
    }

    // @dev Though one of the two address is enough, we store both to save on steps and simplify the usage.
    struct Address {
        starknet: felt,
        evm: felt,
    }

    // @notice info: https://www.evm.codes/about#calldata
    // @notice Struct storing data related to a call.
    // @dev All CallContext fields are constant during a given call.
    // @param bytecode The executed bytecode.
    // @param bytecode_len The length of bytecode.
    // @param calldata byte The space where the data parameter of a transaction or call is held.
    // @param calldata_len The length of calldata.
    // @param value The amount of native token to transfer.
    // @param gas_limit The gas limit for the call.
    // @param gas_price The gas price for the call.
    // @param origin The origin of the transaction.
    // @param calling_context The parent context of the current execution context, can be empty when context
    //                        is root context | see ExecutionContext.is_empty(ctx).
    // @param address The address of the current EVM account. Note that the bytecode may not be the one
    //        of the account in case of a CALLCODE or DELEGATECALL
    // @param read_only if set to true, context cannot do any state modifying instructions or send ETH in the sub context.
    // @param is_create if set to true, the call context is a CREATEs or deploy execution
    struct CallContext {
        bytecode: felt*,
        bytecode_len: felt,
        calldata: felt*,
        calldata_len: felt,
        value: felt,
        gas_limit: felt,
        gas_price: felt,
        origin: Address*,
        calling_context: ExecutionContext*,
        address: Address*,
        read_only: felt,
        is_create: felt,
    }

    // @dev Stores all data relevant to the current execution context.
    // @param call_context The call context data.
    // @param program_counter The keep track of the current position in the program as it is being executed.
    // @param stopped A boolean that state if the current execution is halted.
    // @param return_data The region used to return a value after a call.
    // @param return_data_len The return_data length.
    // @param stack The current execution context stack.
    // @param memory The current execution context memory.
    // @param gas_used The gas consumed by the current state of the execution.
    // @param state The current journal of state updates.
    struct ExecutionContext {
        state: State*,
        call_context: CallContext*,
        stack: Stack*,
        memory: Memory*,
        return_data_len: felt,
        return_data: felt*,
        program_counter: felt,
        stopped: felt,
        gas_used: felt,
        reverted: felt,
    }

    // @dev Stores the constant data of an opcode
    // @dev Stores the constant data of an opcode
    // @param number The opcode number
    // @param gas The minimum gas used by the opcode (not including possible dynamic gas)
    // @param stack_input The number of inputs popped from the stack.
    // @param stack_size_min The minimal size of the Stack for this opcode.
    // @param stack_size_diff The difference between the stack size after and before
    struct Opcode {
        number: felt,
        gas: felt,
        stack_input: felt,
        stack_size_min: felt,
        stack_size_diff: felt,
    }
}
