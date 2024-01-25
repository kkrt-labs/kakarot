def flatten_list(list_ptr, list_len, output_ptr, memory, segments):
    for i in range(list_len):
        data_len = memory[list_ptr + i * 3]
        data_ptr = memory[list_ptr + i * 3 + 1]
        is_list = memory[list_ptr + i * 3 + 2]

        if is_list:
            flatten_list(data_ptr, data_len, output_ptr, memory, segments)
        else:
            bytes = [memory[data_ptr + j] for j in range(data_len)]
            segments.write_arg(output_ptr, bytes)
            output_ptr += data_len


def flatten_access_list(access_list_ptr, access_list_len, output_ptr, memory, segments):
    for i in range(access_list_len):
        output = []
        address = memory[access_list_ptr + i]
        storage_keys_len = memory[access_list_ptr + i + 1]
        storage_keys_ptr = memory[access_list_ptr + i + 2]

        output.append(address)
        for j in range(storage_keys_len):
            storage_key_low = memory[storage_keys_ptr + j * 2]
            storage_key_high = memory[storage_keys_ptr + 1 + j * 2]
            storage_key = [storage_key_low, storage_key_high]
            output.extend(storage_key)

        segments.write_arg(output_ptr, output)
