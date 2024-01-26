def debug_info(program):
    def _debug_info(pc):
        print(
            program.debug_info.instruction_locations.get(
                pc.offset
            ).inst.to_string_with_content("")
        )

    return _debug_info


def flatten_list(list_ptr, list_len, output_ptr, memory, segments):
    for i in range(list_len):
        data_len = memory[list_ptr + i * 3]
        data_ptr = memory[list_ptr + i * 3 + 1]
        is_list = memory[list_ptr + i * 3 + 2]

        if is_list:
            output_ptr = flatten_list(data_ptr, data_len, output_ptr, memory, segments)
        else:
            bytes = [memory[data_ptr + j] for j in range(data_len)]
            segments.write_arg(output_ptr, bytes)
            output_ptr += len(bytes)
    return output_ptr


def flatten_access_list(access_list, access_list_len, output_ptr, memory, segments):
    for i in range(0, access_list_len):
        address = access_list[i].address
        storage_keys_len = access_list[i].storage_keys_len
        storage_keys_ptr = access_list[i].storage_keys
        storage_keys = [
            memory[storage_keys_ptr.address_ + j] for j in range(storage_keys_len * 2)
        ]
        segments.write_arg(output_ptr, [address, *storage_keys])
        output_ptr += 1 + storage_keys_len * 2
