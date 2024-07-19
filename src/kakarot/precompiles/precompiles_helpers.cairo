from starkware.cairo.common.math_cmp import is_nn, is_not_zero, is_in_range

const LAST_ETHEREUM_PRECOMPILE_ADDRESS = 0x0a;
const FIRST_ROLLUP_PRECOMPILE_ADDRESS = 0x100;
const LAST_ROLLUP_PRECOMPILE_ADDRESS = 0x100;
const EXEC_PRECOMPILE_SELECTOR = 0x01e3e7ac032066525c37d0791c3c0f5fbb1c17f1cb6fe00afc206faa3fbd18e1;
const FIRST_KAKAROT_PRECOMPILE_ADDRESS = 0x75001;
const LAST_KAKAROT_PRECOMPILE_ADDRESS = 0x75002;

namespace PrecompilesHelpers {
    func is_rollup_precompile{range_check_ptr}(address: felt) -> felt {
        return is_in_range(
            address, FIRST_ROLLUP_PRECOMPILE_ADDRESS, LAST_ROLLUP_PRECOMPILE_ADDRESS + 1
        );
    }

    func is_kakarot_precompile{range_check_ptr}(address: felt) -> felt {
        return is_in_range(
            address, FIRST_KAKAROT_PRECOMPILE_ADDRESS, LAST_KAKAROT_PRECOMPILE_ADDRESS + 1
        );
    }
    // @notice Return whether the address is a precompile address.
    // @dev Ethereum precompiles start at address 0x01.
    // @dev RIP precompiles start at address FIRST_ROLLUP_PRECOMPILE_ADDRESS.
    // @dev Kakarot precompiles start at address FIRST_KAKAROT_PRECOMPILE_ADDRESS.
    func is_precompile{range_check_ptr}(address: felt) -> felt {
        alloc_locals;
        let is_rollup_precompile_ = is_rollup_precompile(address);
        let is_kakarot_precompile_ = is_kakarot_precompile(address);
        return is_not_zero(address) * (
            is_nn(LAST_ETHEREUM_PRECOMPILE_ADDRESS - address) +
            is_rollup_precompile_ +
            is_kakarot_precompile_
        );
    }
}
