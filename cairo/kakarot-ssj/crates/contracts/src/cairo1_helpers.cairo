use core::starknet::{EthAddress, secp256_trait::Signature, ContractAddress};

#[starknet::interface]
pub trait IPrecompiles<T> {
    /// Executes a precompiled contract at a given address with provided data.
    ///
    /// # Arguments
    ///
    /// * `self` - The instance of the current class.
    /// * `address` - The address of the precompiled contract to be executed.
    /// * `data` - The data to be passed to the precompiled contract.
    ///
    /// # Returns
    ///
    /// * A tuple containing:
    ///   * True if the execution was successful, false otherwise.
    ///   * The gas cost of the execution if successful, otherwise 0.
    ///   * The output data from the execution.
    fn exec_precompile(self: @T, address: felt252, data: Span<u8>) -> (bool, u64, Span<u8>);
}

#[starknet::interface]
pub trait IHelpers<T> {
    /// Gets the hash of a specific StarkNet block within the range of
    /// [first_v0_12_0_block, current_block - 10].
    ///
    /// # Arguments
    ///
    /// * `block_number` - The block number for which to get the hash.
    ///
    /// # Returns
    /// The hash of the specified block.
    ///
    /// # Errors
    /// `Block number out of range` - If the block number is greater than `current_block - 10`.
    /// `0`: The block number is inferior to `first_v0_12_0_block`.
    fn get_block_hash(self: @T, block_number: u64) -> felt252;

    /// Computes the keccak hash of the provided data.
    ///
    /// The data is expected to be an array of full 64-bit words.
    /// The last u64-word to hash may be incomplete and is provided separately.
    /// # Arguments
    ///
    /// * `words` - The full 64-bit words to hash.
    /// * `last_input_word` - The last word to hash.
    /// * `last_input_num_bytes` - The number of bytes in the last word.
    ///
    /// # Returns
    /// The EVM-compatible keccak hash of the provided data.
    fn keccak(
        self: @T, words: Array<u64>, last_input_word: u64, last_input_num_bytes: usize
    ) -> u256;

    /// Computes the SHA-256 of the provided data.
    ///
    /// The data is expected to be an array of full 32-bit unsigned words.
    /// The last u32-word to hash may be incomplete and is provided separately.
    /// # Arguments
    ///
    /// * `input` - The full 32-bit unsigned words to hash.
    /// * `last_input_word` - the last word to hash.
    /// * `last_input_num_bytes` - the number of bytes in the last word.
    ///
    /// # Returns
    /// The SHA-256 of the provided data.
    fn compute_sha256_u32_array(
        self: @T, input: Array<u32>, last_input_word: u32, last_input_num_bytes: u32
        ) -> [
        u32
    ; 8];

    // DEPRECATED
    fn verify_eth_signature(
        self: @T, msg_hash: u256, signature: Signature, eth_address: EthAddress
    );

    /// Recovers the Ethereum address from a message hash and a signature.
    ///
    /// # Arguments
    ///
    /// * `msg_hash` - The hash of the message.
    /// * `signature` - The signature to recover the address from.
    ///
    /// # Returns
    /// A tuple containing:
    /// * A boolean indicating whether the recovery was successful.
    /// * The recovered Ethereum address.
    fn recover_eth_address(self: @T, msg_hash: u256, signature: Signature) -> (bool, EthAddress);

    /// Performs signature verification in the secp256r1 elliptic curve.
    ///
    /// # Arguments
    ///
    /// * `msg_hash` - The hash of the message.
    /// * `r` - The r component of the signature.
    /// * `s` - The s component of the signature.
    /// * `x` - The x coordinate of the public key.
    /// * `y` - The y coordinate of the public key.
    ///
    /// # Returns
    /// A boolean indicating whether the signature is valid.
    fn verify_signature_secp256r1(
        self: @T, msg_hash: u256, r: u256, s: u256, x: u256, y: u256
    ) -> bool;


    /// Calls a contract using the new Cairo call_contract_syscall.
    ///
    /// Meant to be used from Cairo Zero classes that want to be able to manage the return value of
    /// the call.
    /// Only applicable from Starknet v0.13.4 and onwwards.
    ///
    /// # Arguments
    ///
    /// * `to` - The address of the contract to call.
    /// * `selector` - The selector of the function to call.
    /// * `calldata` - The calldata to pass to the function.
    ///
    /// # Returns
    /// A tuple containing:
    /// * A boolean indicating whether the call was successful.
    /// * The output of the call.
    fn new_call_contract_syscall(
        ref self: T, to: ContractAddress, selector: felt252, calldata: Span<felt252>
    ) -> (bool, Span<felt252>);
}


pub mod embeddable_impls {
    use core::keccak::{cairo_keccak, keccak_u256s_be_inputs};
    use core::num::traits::Zero;
    use core::starknet::eth_signature::{verify_eth_signature};
    use core::starknet::secp256_trait::{
        Signature, recover_public_key, Secp256PointTrait, is_valid_signature
    };
    use core::starknet::secp256_trait::{Secp256Trait};
    use core::starknet::secp256k1::Secp256k1Point;
    use core::starknet::secp256r1::{Secp256r1Point};
    use core::starknet::{ContractAddress, EthAddress};
    use core::traits::Into;
    use core::{starknet, starknet::SyscallResultTrait};
    use evm::errors::EVMError;
    use evm::precompiles::EcAdd;
    use evm::precompiles::EcMul;
    use evm::precompiles::Sha256;
    use utils::traits::integer::U256Trait;


    #[starknet::embeddable]
    pub impl Precompiles<TContractState> of super::IPrecompiles<TContractState> {
        fn exec_precompile(
            self: @TContractState, address: felt252, data: Span<u8>
        ) -> (bool, u64, Span<u8>) {
            let result = match address {
                0 => Result::Err(EVMError::NotImplemented),
                1 => Result::Err(EVMError::NotImplemented),
                2 => Sha256::exec(data),
                3 | 4 => Result::Err(EVMError::NotImplemented),
                5 => Result::Err(EVMError::NotImplemented),
                6 => EcAdd::exec(data),
                7 => EcMul::exec(data),
                _ => Result::Err(EVMError::NotImplemented),
            };
            match result {
                Result::Ok((gas, output)) => (true, gas, output),
                Result::Err(_) => (false, 0, [].span())
            }
        }
    }

    #[starknet::embeddable]
    pub impl Helpers<TContractState, +Drop<TContractState>> of super::IHelpers<TContractState> {
        fn get_block_hash(self: @TContractState, block_number: u64) -> felt252 {
            starknet::syscalls::get_block_hash_syscall(block_number).unwrap_syscall()
        }

        fn keccak(
            self: @TContractState,
            mut words: Array<u64>,
            last_input_word: u64,
            last_input_num_bytes: usize
        ) -> u256 {
            cairo_keccak(ref words, last_input_word, last_input_num_bytes).reverse_endianness()
        }

        fn compute_sha256_u32_array(
            self: @TContractState,
            input: Array<u32>,
            last_input_word: u32,
            last_input_num_bytes: u32
            ) -> [
            u32
        ; 8] {
            core::sha256::compute_sha256_u32_array(input, last_input_word, last_input_num_bytes)
        }

        // DEPRECATED
        fn verify_eth_signature(
            self: @TContractState, msg_hash: u256, signature: Signature, eth_address: EthAddress
        ) {
            verify_eth_signature(msg_hash, signature, eth_address);
        }

        fn recover_eth_address(
            self: @TContractState, msg_hash: u256, signature: Signature
        ) -> (bool, EthAddress) {
            match recover_public_key::<Secp256k1Point>(:msg_hash, :signature) {
                Option::Some(public_key_point) => {
                    let (x, y) = public_key_point.get_coordinates().unwrap_syscall();
                    if (x == 0 && y == 0) {
                        return (false, Zero::zero());
                    }
                    // Keccak output is little endian.
                    let point_hash_le = keccak_u256s_be_inputs([x, y].span());
                    let point_hash = u256 {
                        low: core::integer::u128_byte_reverse(point_hash_le.high),
                        high: core::integer::u128_byte_reverse(point_hash_le.low)
                    };

                    (true, point_hash.into())
                },
                Option::None => (false, Zero::zero())
            }
        }

        fn verify_signature_secp256r1(
            self: @TContractState, msg_hash: u256, r: u256, s: u256, x: u256, y: u256
        ) -> bool {
            let maybe_public_key: Option<Secp256r1Point> = Secp256Trait::secp256_ec_new_syscall(
                x, y
            )
                .unwrap_syscall();
            let public_key = match maybe_public_key {
                Option::Some(public_key) => public_key,
                Option::None => { return false; }
            };

            return is_valid_signature(msg_hash, r, s, public_key);
        }

        fn new_call_contract_syscall(
            ref self: TContractState,
            to: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>
        ) -> (bool, Span<felt252>) {
            // Note: until Starknet v0.13.4, the transaction will fail if the call reverted.
            let result = starknet::syscalls::call_contract_syscall(to, selector, calldata);
            match result {
                Result::Ok(output) => { return (true, output); },
                // This will need to be manually tested and enabled once contract calls can be
                // handled.
                Result::Err(error) => { return panic(error); }
            }
        }
    }
}

#[starknet::contract]
pub mod Cairo1Helpers {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    pub impl Precompiles = super::embeddable_impls::Precompiles<ContractState>;

    #[abi(embed_v0)]
    pub impl Helpers = super::embeddable_impls::Helpers<ContractState>;
}
