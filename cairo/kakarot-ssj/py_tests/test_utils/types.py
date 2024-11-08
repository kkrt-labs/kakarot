import json
from typing import Any, Generic, List, Tuple, Type, TypeVar, Union, get_args

BYTE_ARRAY_MAGIC = 0x046A6158A16A947E5916B2A2CA68501A45E93D7110E81AA2D6438B1C57C879A3
BYTES_IN_WORD = 31

T = TypeVar("T")


class ListType(Generic[T]):
    """
    A generic class for handling list types in JSON deserialization.
    """

    @classmethod
    def from_json(cls, json_string: str, item_type: Type[T]) -> List[T]:
        """
        Deserialize a JSON string into a list of specified item type.

        Args:
        ----
            json_string (str): The JSON string to deserialize.
            item_type (Type[T]): The type of items in the list.

        Returns:
        -------
            List[T]: A list of deserialized items of the specified type.

        Raises:
        ------
            ValueError: If the JSON string doesn't represent a list.

        """
        data = json.loads(json_string)
        if not isinstance(data, list):
            raise ValueError(
                f"Invalid JSON format for List. Expected a list, got {type(data)}"
            )
        return [
            TYPE_MAP[item_type.__name__].from_json(json.dumps(item)) for item in data
        ]


def parse_json_output(
    json_string: str, output_type: Union[Type, Tuple[Type, ...], List[Type]]
) -> Any:
    """
    Parse a JSON string into the specified output type(s).

    Args:
    ----
        json_string (str): The JSON string to parse.
        output_type (Union[Type, Tuple[Type, ...], List[Type]]): The desired output type(s).

    Returns:
    -------
        Any: The parsed data in the specified output type(s).

    Raises:
    ------
        ValueError: If the JSON data doesn't match the expected output type(s).

    """
    data = json.loads(json_string)

    if isinstance(output_type, tuple):
        if not isinstance(data, list) or len(data) != len(output_type):
            raise ValueError(
                f"Expected a list of {len(output_type)} elements, got {data}"
            )
        return tuple(
            TYPE_MAP[t.__name__].from_json(json.dumps(item))
            for t, item in zip(output_type, data)
        )
    elif isinstance(output_type, list):
        if not isinstance(data, list):
            raise ValueError(f"Expected a list, got {type(data)}")
        return [
            TYPE_MAP[output_type[0].__name__].from_json(json.dumps(item))
            for item in data
        ]
    else:
        return TYPE_MAP[output_type.__name__].from_json(json_string)


class ByteArray:
    """
    Represents a byte array and provides methods for string conversion and debugging.
    """

    def __init__(self, felt_array: List[int]):
        self.felt_array = felt_array

    def to_string(self) -> str:
        """
        Convert the ByteArray to a string representation.

        Returns
        -------
            str: A formatted string representation of the ByteArray.

        """
        return self.format_for_debug()

    def format_for_debug(self) -> str:
        """
        Format the ByteArray for debugging purposes.
        Note: The input felt array is expected to begin with the BYTE_ARRAY_MAGIC number.
        Otherwise, it's interpreted as a debug string directly.

        This method processes the felt_array and formats each item for debugging.
        If the result is a single string item, it returns that item directly.
        Otherwise, it returns a formatted string with each item on a new line,
        prefixed with '[DEBUG]' for non-string items.


        Source: https://github.com/starkware-libs/cairo/blob/main/crates/cairo-lang-runner/src/casm_run/mod.rs#L2281

        Returns
        -------
            str: A formatted string representation of the ByteArray for debugging.

        """
        items = []
        i = 0
        while i < len(self.felt_array):
            item, is_string, consumed = self.format_next_item(self.felt_array[i:])
            items.append((item, is_string))
            i += consumed

        if len(items) == 1 and items[0][1]:
            return items[0][0]

        return "".join(
            f"{item}\n" if is_string else f"[DEBUG]\t{item}\n"
            for item, is_string in items
        ).strip()  # Remove trailing newline

    @staticmethod
    def format_next_item(values: List[int]) -> Tuple[str, bool, int]:
        if not values:
            return None, False, 0

        if values[0] == BYTE_ARRAY_MAGIC:
            string, consumed = ByteArray.try_format_string(values)
            if string is not None:
                return string, True, consumed

        return ByteArray.format_short_string(values[0]), False, 1

    @staticmethod
    def format_short_string(value: int) -> str:
        as_string = ByteArray.as_cairo_short_string(value)
        if as_string:
            return f"{value:#x} ('{as_string}')"
        return f"{value:#x}"

    @staticmethod
    def try_format_string(values: List[int]) -> Tuple[Union[str, None], int]:
        if len(values) < 4:
            return None, 0

        num_full_words = values[1]
        full_words = values[2 : 2 + num_full_words]
        pending_word = values[2 + num_full_words]
        pending_word_len = values[2 + num_full_words + 1]

        if len(full_words) != num_full_words:
            return None, 0

        full_words_string = "".join(
            ByteArray.as_cairo_short_string_ex(word, BYTES_IN_WORD) or ""
            for word in full_words
        )
        pending_word_string = ByteArray.as_cairo_short_string_ex(
            pending_word, pending_word_len
        )

        if pending_word_string is None:
            return None, 0

        result = full_words_string + pending_word_string
        return result, 2 + num_full_words + 2

    @staticmethod
    def as_cairo_short_string(felt: int) -> Union[str, None]:
        as_string = ""
        is_end = False
        for byte in felt.to_bytes(32, "big"):
            if byte == 0:
                is_end = True
            elif is_end:
                return None
            elif ByteArray.is_ascii_graphic(byte) or ByteArray.is_ascii_whitespace(
                byte
            ):
                as_string += chr(byte)
            else:
                return None
        return as_string

    @staticmethod
    def is_ascii_graphic(byte: int) -> bool:
        return 33 <= byte <= 126  # b'!' to b'~'

    @staticmethod
    def is_ascii_whitespace(byte: int) -> bool:
        return byte in (9, 10, 12, 13, 32)  # \t, \n, \f, \r, space

    @staticmethod
    def as_cairo_short_string_ex(felt: int, length: int) -> Union[str, None]:
        if length == 0:
            return "" if felt == 0 else None
        if length > 31:
            return None

        bytes_data = felt.to_bytes(32, "big")
        bytes_data = bytes_data[-length:]  # Take last 'length' bytes

        as_string = ""
        for byte in bytes_data:
            if byte == 0:
                as_string += r"\0"
            elif ByteArray.is_ascii_graphic(byte) or ByteArray.is_ascii_whitespace(
                byte
            ):
                as_string += chr(byte)
            else:
                as_string += f"\\x{byte:02x}"

        # Prepend missing nulls
        missing_nulls = length - len(bytes_data)
        as_string = r"\0" * missing_nulls + as_string

        return as_string


class UIntBase:
    """
    Base class for unsigned integer types with a maximum value.
    """

    def __init__(self, value: int):
        if not 0 <= value <= self.MAX_VALUE:
            raise ValueError(
                f"{self.__class__.__name__} value must be between 0 and {self.MAX_VALUE}"
            )
        self.value = value

    def __eq__(self, other: "UIntBase") -> bool:
        return isinstance(other, self.__class__) and self.value == other.value

    def __repr__(self) -> str:
        return f"{self.value:#x}"

    @classmethod
    def from_json(cls, json_string: str) -> "UIntBase":
        value = json.loads(json_string)
        if not isinstance(value, int):
            raise ValueError(
                f"Invalid JSON format for {cls.__name__}. Expected a single integer."
            )
        return cls(value)

    def to_felt_array(self) -> List[int]:
        return [self.value]


class U8(UIntBase):
    MAX_VALUE = 2**8 - 1


class U16(UIntBase):
    MAX_VALUE = 2**16 - 1


class U32(UIntBase):
    MAX_VALUE = 2**32 - 1


class U64(UIntBase):
    MAX_VALUE = 2**64 - 1


class U128(UIntBase):
    MAX_VALUE = 2**128 - 1


class U256(UIntBase):
    """
    Represents an unsigned 256-bit integer.
    """

    MAX_VALUE = 2**256 - 1

    def to_felt_array(self) -> List[int]:
        """
        Convert the U256 value to a list of field elements.

        Returns
        -------
            List[int]: A list containing two 128-bit integers representing the U256 value.

        """
        return [self.value & 2**128 - 1, self.value >> 128]


class Stack:
    """
    Represents a stack of U256 values.
    """

    def __init__(self, values: List[U256]):
        self.values = values

    def __eq__(self, other: "Stack") -> bool:
        return self.values == other.values

    def __repr__(self) -> str:
        return f"Stack({self.values})"

    @classmethod
    def from_json(cls, json_string: str) -> "Stack":
        int_array = json.loads(json_string)
        if not isinstance(int_array, list):
            raise ValueError(
                f"Invalid JSON format: expected list, got {type(int_array)}"
            )
        values = [U256(int_value) for int_value in int_array]
        return cls(values)


# Add a dictionary to map type names to their respective classes
TYPE_MAP = {
    "U8": U8,
    "U16": U16,
    "U32": U32,
    "U64": U64,
    "U128": U128,
    "U256": U256,
    "Stack": Stack,
    "Tuple": Tuple,
    "List": ListType,
}


def handle_list_type(json_string: str, list_type: Type[List[Any]]) -> List[Any]:
    """
    Handle deserialization of list types.

    Args:
    ----
        json_string (str): The JSON string to deserialize.
        list_type (Type[List[Any]]): The type of the list.

    Returns:
    -------
        List[Any]: A list of deserialized items.

    """
    item_type = get_args(list_type)[0]
    return ListType.from_json(json_string, item_type)
