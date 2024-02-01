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
            bytes = [memory[data_ptr + j] for j in range(data_len)]
            segments.write_arg(output_ptr, bytes)
            output_ptr += len(bytes)
    return output_ptr


def serialize_cairo_access_list(
    access_list, access_list_len, output_ptr, memory, segments
):
    """
    Serialize an access list in the Cairo format [address, keys_len, [...keys]] (Cairo object)
    to a flat list of [address, keys]. The `access_list_len` argument is the len, in felts,
    of the access list.
    """
    access_list_ptr = access_list
    i = 0
    while i < access_list_len:
        address = memory[access_list_ptr]
        storage_keys_len = memory[access_list_ptr + 1]
        storage_keys_start = access_list_ptr + 2
        storage_keys = [
            memory[storage_keys_start + j] for j in range(storage_keys_len * 2)
        ]
        i += 2 + storage_keys_len * 2
        access_list_ptr += i
        segments.write_arg(output_ptr, [address, *storage_keys])
        output_ptr += 1 + storage_keys_len * 2


def deserialize_cairo_access_list(access_list, access_list_ptr, memory):
    """
    Transform the access list from a transaction dictionary into a deserialized data structure
    in a Cairo-compatible format [*[addr, keys_len, keys], *[address, keys_len, keys]].

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

    for item in access_list:
        memory[access_list_ptr] = int(item["address"], 16)
        storage_keys_count = len(
            item.get("storageKeys") or []
        )  # It's not the length in felts, but the count of storage_keys
        memory[access_list_ptr + 1] = storage_keys_count
        for j in range(len(item["storageKeys"])):
            value = int(item["storageKeys"][j], 16)
            memory[access_list_ptr + 2 + j * 2] = value & 2**128 - 1
            memory[access_list_ptr + 2 + j * 2 + 1] = value >> 128

        access_list_ptr += 2 + storage_keys_count * 2
