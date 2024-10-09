from typing import Any, List


class Serializer:
    """
    A utility class for serializing arguments, particularly useful for handling
    nested structures and custom objects with 'to_felt_array' method.
    """

    @staticmethod
    def serialize_args(args: List[Any]) -> List[Any]:
        """
        Serialize a list of arguments, maintaining the structure for nested lists.

        Args:
        ----
            args (List[Any]): A list of arguments to be serialized.

        Returns:
        -------
            List[Any]: A list of serialized arguments, preserving the original structure.

        Example:
        -------
            >>> Serializer.serialize_args([[U256(0x10), U256(0x20)], 3])
            [[16, 0, 32, 0], 3]

        """
        serialized_args = []
        for arg in args:
            if isinstance(arg, list):
                # Keep the list structure, but serialize its contents
                serialized_args.append(Serializer.serialize_list(arg))
            else:
                serialized_args.append(Serializer.serialize_single(arg))
        return serialized_args

    @staticmethod
    def serialize_list(arg_list: List[Any]) -> List[Any]:
        """
        Serialize a list of arguments, flattening any nested structures.

        Args:
        ----
            arg_list (List[Any]): A list of arguments to be serialized.

        Returns:
        -------
            List[Any]: A flattened list of serialized arguments.

        Example:
        -------
            >>> Serializer.serialize_list([U256(0x10), U256(0x20)])
            [16, 0, 32, 0]

        """
        return [item for arg in arg_list for item in Serializer.serialize_single(arg)]

    @staticmethod
    def serialize_single(arg: Any) -> Any:
        """
        Serialize a single argument.

        If the argument has a 'to_felt_array' method, it uses that for serialization.
        Otherwise, it returns the argument as is.

        Args:
        ----
            arg (Any): The argument to be serialized.

        Returns:
        -------
            Any: The serialized argument, either as a felt array or the original value.

        Example:
        -------
            >>> Serializer.serialize_single(5)
            5
            >>> Serializer.serialize_single(U256(0x10))
            [16, 0]

        """
        if hasattr(arg, "to_felt_array"):
            return arg.to_felt_array()
        return arg  # Return single values as is, without wrapping in a list
