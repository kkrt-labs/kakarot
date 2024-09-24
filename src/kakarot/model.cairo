// StarkWare dependencies
from starkware.cairo.common.dict import DictAccess
from starkware.cairo.common.uint256 import Uint256

namespace model {
    // @notice Represents the cost and size of a memory expansion operation.
    // @param cost The cost of the memory expansion operation.
    // @param new_words_len The number of words in the memory post-expansion.
    struct MemoryExpansion {
        cost: felt,
        new_words_len: felt,
    }

    // @notice Represents an optional value.
    // @param is_some A boolean indicating whether the value is present.
    // @param value The value (if applicable).
    struct Option {
        is_some: felt,
        value: felt,
    }

    // @notice Info: https://www.evm.codes/about#stack
    // @notice Stack with a 1024 items maximum size. Each item is a 256 bits word. The stack is used by most
    // @notice opcodes to consume their parameters from.
    // @dev The dict stores a pointer to the word (a Uint256).
    // @param size The size of the Stack.
    // @param dict_ptr_start Pointer to a DictAccess array used to store the stack's value at a given index.
    // @param dict_ptr Pointer to the end of the DictAccess array.
    struct Stack {
        dict_ptr_start: DictAccess*,
        dict_ptr: DictAccess*,
        size: felt,
    }

    // @notice Info: https://www.evm.codes/about#memory
    // @notice Transient memory maintained by the EVM during an execution which doesn't persist
    // @notice between transactions.
    // @param word_dict_start Pointer to a DictAccess used to store the memory's value at a given index.
    // @param word_dict Pointer to the end of the DictAccess array.
    // @param words_len Number of words (bytes32).
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
    // @param accounts_start Pointer to the start of the accounts DictAccess array.
    // @param accounts Pointer to the end of the accounts DictAccess array.
    // @param events_len The number of events.
    // @param events Pointer to the start of the events array.
    // @param transfers_len The number of transfers.
    // @param transfers Pointer to the start of the transfers array.
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
    // @dev The address is a tuple (starknet, evm) for step-optimization purposes:
    // we can compute the starknet only once.
    // @param address Pointer to the address of the account.
    // @param code_len The length of the code.
    // @param code Pointer to the code.
    // @param code_hash Pointer to the code hash.
    // @param storage_start Pointer to the start of the storage DictAccess array.
    // @param storage Pointer to the end of the storage DictAccess array.
    // @param transient_storage_start Pointer to the start of the transient storage DictAccess array.
    // @param transient_storage Pointer to the end of the transient storage DictAccess array.
    // @param valid_jumpdests_start Pointer to the start of the valid jump destinations DictAccess array.
    // @param valid_jumpdests Pointer to the end of the valid jump destinations DictAccess array.
    // @param nonce The nonce of the account.
    // @param balance Pointer to the balance of the account.
    // @param selfdestruct Indicates if the account is self-destructed.
    // @param created Indicates if the account was created in the current transaction.
    struct Account {
        address: model.Address*,
        code_len: felt,
        code: felt*,
        code_hash: Uint256*,
        storage_start: DictAccess*,
        storage: DictAccess*,
        transient_storage_start: DictAccess*,
        transient_storage: DictAccess*,
        valid_jumpdests_start: DictAccess*,
        valid_jumpdests: DictAccess*,
        nonce: felt,
        balance: Uint256*,
        selfdestruct: felt,
        created: felt,
    }

    // @notice The struct representing an EVM event.
    // @dev The topics are indeed a first felt for the emitting EVM account, followed by a list of Uint256
    // @param topics_len The number of topics.
    // @param topics Pointer to the topics array.
    // @param data_len The length of the data.
    // @param data Pointer to the data array.
    struct Event {
        topics_len: felt,
        topics: felt*,
        data_len: felt,
        data: felt*,
    }

    // @dev A struct to save Starknet native ETH transfers to be made when finalizing a tx
    // @param sender Pointer to the sender's address.
    // @param recipient Pointer to the recipient's address.
    // @param amount The amount to be transferred.
    struct Transfer {
        sender: Address*,
        recipient: Address*,
        amount: Uint256,
    }

    // @dev Though one of the two address is enough, we store both to save on steps and simplify the usage.
    // @param starknet The Starknet address.
    // @param evm The EVM address.
    struct Address {
        starknet: felt,
        evm: felt,
    }

    // @notice Info: https://www.evm.codes/about#calldata
    // @notice Struct storing data related to a call.
    // @dev All Message fields are constant during a given call.
    // @param bytecode Pointer to the executed bytecode.
    // @param bytecode_len The length of bytecode.
    // @param calldata Pointer to the calldata.
    // @param calldata_len The length of calldata.
    // @param value Pointer to the amount of native token to transfer.
    // @param parent Pointer to the parent context of the current execution context, can be empty.
    // @param address Pointer to the address of the current EVM account. Note that the bytecode may not be the one
    //        of the account in case of a CALLCODE or DELEGATECALL.
    // @param code_address Pointer to the EVM address the bytecode of the message is taken from.
    // @param read_only Indicates if the context cannot do any state modifying instructions or send ETH in the sub context.
    // @param is_create Indicates if the call context is a CREATE or deploy execution.
    // @param depth The depth of the current execution context.
    // @param env Pointer to the environment data.
    // @param cairo_precompile_called Indicates if a Cairo precompile was called.
    struct Message {
        bytecode: felt*,
        bytecode_len: felt,
        valid_jumpdests_start: DictAccess*,
        valid_jumpdests: DictAccess*,
        calldata: felt*,
        calldata_len: felt,
        value: Uint256*,
        caller: felt,
        parent: Parent*,
        address: Address*,
        code_address: Address*,
        read_only: felt,
        is_create: felt,
        depth: felt,
        env: Environment*,
        cairo_precompile_called: felt,
    }

    // @dev Stores all data relevant to the current execution context.
    // @param message Pointer to the call context data.
    // @param return_data_len The length of the return data.
    // @param return_data Pointer to the region used to return a value after a call.
    // @param program_counter The current position in the program as it is being executed.
    // @param stopped Indicates if the current execution is halted.
    // @param gas_left The gas consumed by the current state of the execution.
    // @param gas_refund The gas to be refunded.
    // @param reverted Indicates whether the EVM is reverted or not.
    struct EVM {
        message: Message*,
        return_data_len: felt,
        return_data: felt*,
        program_counter: felt,
        stopped: felt,
        gas_left: felt,
        gas_refund: felt,
        reverted: felt,
    }

    // @notice Store all environment data relevant to the current execution context.
    // @param origin The origin of the transaction.
    // @param gas_price The gas price for the call.
    // @param chain_id The chain id of the current block.
    // @param prev_randao The previous RANDAO value.
    // @param block_number The block number of the current block.
    // @param block_gas_limit The gas limit for the current block.
    // @param block_timestamp The timestamp of the current block.
    // @param coinbase The address of the miner of the current block.
    // @param base_fee The base fee of the current block.
    struct Environment {
        origin: felt,
        gas_price: felt,
        chain_id: felt,
        prev_randao: Uint256,
        block_number: felt,
        block_gas_limit: felt,
        block_timestamp: felt,
        coinbase: felt,
        base_fee: felt,
    }

    // @dev The parent EVM struct is used to store the parent EVM context of the current execution context.
    // @param evm Pointer to the parent EVM context.
    // @param stack Pointer to the parent stack.
    // @param memory Pointer to the parent memory.
    // @param state Pointer to the parent state.
    struct Parent {
        evm: EVM*,
        stack: Stack*,
        memory: Memory*,
        state: State*,
    }

    // @dev Stores the constant data of an opcode.
    // @param number The opcode number.
    // @param gas The minimum gas used by the opcode (not including possible dynamic gas).
    // @param stack_input The number of inputs popped from the stack.
    // @param stack_size_min The minimal size of the stack for this opcode.
    // @param stack_size_diff The difference between the stack size after and before.
    struct Opcode {
        number: felt,
        gas: felt,
        stack_input: felt,
        stack_size_min: felt,
        stack_size_diff: felt,
    }

    // @notice A normalized Ethereum transaction.
    // @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md
    // @param signer_nonce The nonce of the signer.
    // @param gas_limit The gas limit for the transaction.
    // @param max_priority_fee_per_gas The maximum priority fee per gas.
    // @param max_fee_per_gas The maximum fee per gas.
    // @param destination The destination address (optional).
    // @param amount The amount to be transferred.
    // @param payload_len The length of the payload.
    // @param payload Pointer to the payload.
    // @param access_list_len The length of the access list.
    // @param access_list Pointer to the access list.
    // @param chain_id The chain id (optional).
    struct EthTransaction {
        signer_nonce: felt,
        gas_limit: felt,
        max_priority_fee_per_gas: felt,
        max_fee_per_gas: felt,
        destination: Option,
        amount: Uint256,
        payload_len: felt,
        payload: felt*,
        access_list_len: felt,
        access_list: felt*,
        chain_id: Option,
    }
}
