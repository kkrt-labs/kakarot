def debug_info(program):
    def _debug_info(pc):
        print(
            program.debug_info.instruction_locations.get(
                pc.offset
            ).inst.to_string_with_content("")
        )

    return _debug_info


def flatten_rlp_list(list_ptr, list_len, output_ptr, memory, segments):
    for i in range(list_len):
        data_len = memory[list_ptr + i * 3]
        data_ptr = memory[list_ptr + i * 3 + 1]
        is_list = memory[list_ptr + i * 3 + 2]

        if is_list:
            output_ptr = flatten_rlp_list(
                data_ptr, data_len, output_ptr, memory, segments
            )
        else:
            data = [memory[data_ptr + j] for j in range(data_len)]
            segments.write_arg(output_ptr, data)
            output_ptr += len(data)

    return output_ptr
