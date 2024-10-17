import json
from typing import Any, Tuple, Type, Union, get_origin

from py_tests.test_utils.types import TYPE_MAP, ByteArray, handle_list_type


class Deserializer:
    """
    A utility class for deserializing ByteArray objects into specific types or tuples of types.
    """

    @staticmethod
    def deserialize(
        byte_array: ByteArray, output_type: Union[Type[Any], Tuple[Type[Any], ...]]
    ) -> Any:
        """
        Deserialize a ByteArray object into a specified output type or tuple of types.

        Args:
        ----
            byte_array (ByteArray): The ByteArray object to deserialize.
            output_type (Union[Type[Any], Tuple[Type[Any], ...]]): The desired output type(s).

        Returns:
        -------
            Any: An instance of the specified output_type or a tuple of instances.

        Raises:
        ------
            ValueError: If the output_type is not supported or if the data doesn't match the expected format.

        """
        json_string = byte_array.to_string()
        data = json.loads(json_string)

        if isinstance(output_type, tuple):
            if not isinstance(data, list) or len(data) != len(output_type):
                raise ValueError(
                    f"Expected a list of {len(output_type)} elements, got {data}"
                )
            return tuple(
                Deserializer._deserialize_single(json.dumps(item), t)
                for t, item in zip(output_type, data)
            )
        else:
            return Deserializer._deserialize_single(json_string, output_type)

    @staticmethod
    def _deserialize_single(json_string: str, output_type: Type[Any]) -> Any:
        """
        Deserialize a JSON string into a single specified output type.

        Args:
        ----
            json_string (str): The JSON string to deserialize.
            output_type (Type[Any]): The desired output type.

        Returns:
        -------
            Any: An instance of the specified output_type.

        Raises:
        ------
            ValueError: If the output_type is not supported.

        """
        # Handle deserialization based on the output_type
        # 1. If output_type is a list, use a specialized list handling function
        # 2. If output_type is not in the predefined TYPE_MAP, raise an error
        # 3. Otherwise, use the appropriate type class to deserialize from JSON
        if get_origin(output_type) is list:
            return handle_list_type(json_string, output_type)
        elif output_type.__name__ not in TYPE_MAP:
            raise ValueError(f"Unsupported output type: {output_type.__name__}")

        type_class = TYPE_MAP[output_type.__name__]
        return type_class.from_json(json_string)
