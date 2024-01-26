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


def serialize_cairo_access_list(access_list, access_list_ptr, memory, segments):
    """
    Transform the access list from a transaction dictionary into a serialized data structure
    in a Cairo-compatible format.

    Args:
    ----
        access_list (list): The access list from the transaction dictionary.
        access_list_ptr (int): The pointer to the access list in memory to serialize into.
        memory (Memory): The Cairo memory object where the serialized access list will be stored.
        segments (Segments): The Cairo segments object for memory allocation.

    Returns:
    -------
        The length of the access list.
    """
    # Format: ( { "address": "0x0000000000000000000000000000000000000001", "storageKeys": ( "0x0100000000000000000000000000000000000000000000000000000000000000",), },),

    access_list_len = len(access_list)
    for i in range(access_list_len):
        item = access_list[i]
        memory[access_list_ptr] = int(item["address"], 16)
        memory[access_list_ptr + 1] = len(item["storageKeys"])
        keys_ptr = segments.add()
        for j in range(len(item["storageKeys"])):
            value = int(item["storageKeys"][j], 16)
            memory[keys_ptr + 2 * j] = value & 2**128 - 1
            memory[keys_ptr + 2 * j + 1] = value >> 128

        memory[access_list_ptr + 2] = keys_ptr
        access_list_ptr += 3

    return access_list_len
