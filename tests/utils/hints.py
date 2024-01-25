def flatten_list(list_ptr, list_len, output_ptr, memory, segments):
    for i in range(list_len):
        data_len = memory[list_ptr + i * 3]
        data_ptr = memory[list_ptr + i * 3 + 1]
        is_list = memory[list_ptr + i * 3 + 2]

        if is_list:
            flatten_list(data_ptr, data_len // 3, output_ptr, memory, segments)
        else:
            bytes = [memory[data_ptr + j] for j in range(data_len)]
            segments.write_arg(output_ptr, bytes)
            output_ptr += data_len
