from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from kakarot.model import model

namespace Debug {
    func print_felt(x: felt) {
        %{ print(ids.x) %}
        return ();
    }

    func print_uint256(val: Uint256) {
        %{
            low = ids.val.low
            high = ids.val.high
            print(f"Uint256(low={low}, high={high}) = {2 ** 128 * high + low}")
        %}
        return ();
    }

    func print_array(name: felt, arr_len: felt, arr: felt*) {
        %{
            print(bytes.fromhex(f"{ids.name:062x}").decode().replace('\x00',''))
            arr = [memory[ids.arr + i] for i in range(ids.arr_len)]
            print(arr)
        %}
        return ();
    }

    func print_dict(name: felt, dict_ptr: DictAccess*, pointer_size: felt) {
        %{
            print(bytes.fromhex(f"{ids.name:062x}").decode().replace('\x00',''))
            data = __dict_manager.get_dict(ids.dict_ptr)
            print(
                {k: v if isinstance(v, int) else [memory[v + i] for i in range(ids.pointer_size)] for k, v in data.items()}
            )
        %}
        return ();
    }

    func print_message(message: model.Message*) {
        print_array('calldata', message.calldata_len, message.calldata);
        print_array('bytecode', message.bytecode_len, message.bytecode);
        print_felt(message.env.gas_price);
        print_felt(message.env.origin);
        print_felt(message.address.evm);
        print_felt(message.address.starknet);
        print_felt(message.read_only);
        print_felt(message.is_create);
        return ();
    }

    func print_execution_context(evm: model.EVM*) {
        print_message(evm.message);
        print_array('return_data', evm.return_data_len, evm.return_data);
        print_felt(evm.program_counter);
        print_felt(evm.stopped);
        print_felt(evm.gas_left);
        print_felt(evm.reverted);
        return ();
    }
}
