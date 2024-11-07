from typing import Dict, List, Tuple

from ethereum.base_types import U256, Bytes, Uint
from ethereum.cancun.vm.memory import buffer_read
from ethereum.cancun.vm.precompiled_contracts.modexp import gas_cost
from ethereum.crypto.hash import keccak256
from hypothesis import given, settings
from hypothesis import strategies as st

# Store test cases
test_cases: List[Dict] = []


def modexp_384_bits(data: Bytes) -> Tuple[Uint, Bytes]:
    """
    Calculate `(base**exp) % modulus` for arbitrary sized `base`, `exp` and.
    `modulus`. The return value is the same length as the modulus.

    Modified version of EELS modexp implementation that only accepts up to 384-bit inputs.
    Reference: https://github.com/ethereum/execution-specs/blob/master/src/ethereum/cancun/vm/precompiled_contracts/modexp.py#L23-L64
    """
    MAX_INPUT_BYTES = 48

    # GAS
    base_length = U256.from_be_bytes(buffer_read(data, U256(0), U256(32)))
    exp_length = U256.from_be_bytes(buffer_read(data, U256(32), U256(32)))
    modulus_length = U256.from_be_bytes(buffer_read(data, U256(64), U256(32)))

    if (
        base_length > MAX_INPUT_BYTES
        or exp_length > MAX_INPUT_BYTES
        or modulus_length > MAX_INPUT_BYTES
    ):
        raise ValueError("Input length exceeds maximum allowed length")

    exp_start = U256(96) + base_length

    exp_head = Uint.from_be_bytes(
        buffer_read(data, exp_start, min(U256(32), exp_length))
    )

    gas = gas_cost(base_length, modulus_length, exp_length, exp_head)

    # OPERATION
    if base_length == 0 and modulus_length == 0:
        output = Bytes()
        return gas, output

    base = Uint.from_be_bytes(buffer_read(data, U256(96), base_length))
    exp = Uint.from_be_bytes(buffer_read(data, exp_start, exp_length))

    modulus_start = exp_start + exp_length
    modulus = Uint.from_be_bytes(buffer_read(data, modulus_start, modulus_length))

    if modulus == 0:
        output = Bytes(b"\x00") * modulus_length
    else:
        output = Uint(pow(base, exp, modulus)).to_bytes(modulus_length, "big")

    return gas, output


def create_input_data(
    base_len: int,
    exp_len: int,
    modulus_len: int,
    base: bytes,
    exp: bytes,
    modulus: bytes,
) -> Bytes:
    encoded_base_len = U256(base_len).to_be_bytes32()
    encoded_exp_len = U256(exp_len).to_be_bytes32()
    encoded_modulus_len = U256(modulus_len).to_be_bytes32()

    return Bytes(
        encoded_base_len + encoded_exp_len + encoded_modulus_len + base + exp + modulus
    )


def add_test_case(name: str, input_data: Bytes, is_err: bool = False) -> None:
    """Add a test case to the global test cases list."""
    try:
        result = modexp_384_bits(input_data)
        gas, output = result
        test_cases.append(
            {
                "name": name,
                "input": input_data,
                "output_gas": gas,
                "output_data": output,
                "is_err": is_err,
            }
        )
    except ValueError:
        test_cases.append(
            {
                "name": name,
                "input": input_data,
                "output_gas": 0,
                "output_data": Bytes(),
                "is_err": True,
            }
        )


@given(
    data=st.data(),
    base_len=st.integers(min_value=0, max_value=256),
    exp_len=st.integers(min_value=0, max_value=256),
    modulus_len=st.integers(min_value=0, max_value=256),
    base_bytes=st.binary(min_size=0, max_size=256),
    exp_bytes=st.binary(min_size=0, max_size=256),
    modulus_bytes=st.binary(min_size=0, max_size=256),
)
@settings(max_examples=50)
def generate_test_modexp_384_bits_random_inputs(
    data, base_len, exp_len, modulus_len, base_bytes, exp_bytes, modulus_bytes
):
    # Ensure the actual data matches the specified length
    base = base_bytes[:base_len].ljust(base_len, b"\x00")
    exp = exp_bytes[:exp_len].ljust(exp_len, b"\x00")
    modulus = modulus_bytes[:modulus_len].ljust(modulus_len, b"\x00")

    input_data = create_input_data(base_len, exp_len, modulus_len, base, exp, modulus)
    test_id = keccak256(input_data)[0:20].hex()

    add_test_case(
        f"modexp_random_inputs_{base_len}_{exp_len}_{modulus_len}__{test_id}",
        input_data,
    )


@given(
    data=st.data(),
    base_len=st.integers(min_value=1, max_value=48),  # At least 1 byte
    exp_len=st.integers(min_value=1, max_value=48),  # At least 1 byte
    modulus_len=st.integers(min_value=1, max_value=48),  # At least 1 byte
)
@settings(max_examples=50)
def generate_test_modexp_384_bits_non_empty_outputs(
    data, base_len, exp_len, modulus_len
):
    base = data.draw(st.binary(min_size=base_len, max_size=base_len))
    exp = data.draw(st.binary(min_size=exp_len, max_size=exp_len))
    # Ensure modulus is not zero by requiring at least one non-zero byte
    modulus = data.draw(
        st.binary(min_size=modulus_len, max_size=modulus_len).filter(
            lambda x: any(b != 0 for b in x)
        )
    )

    input_data = create_input_data(base_len, exp_len, modulus_len, base, exp, modulus)

    add_test_case(
        f"modexp_non_empty_outputs_{base_len}_{exp_len}_{modulus_len}", input_data
    )


def generate_cairo_tests() -> str:
    """Generate Cairo test code from collected test cases."""
    cairo_tests = []

    # Remove duplicate test cases based on the name
    filtered_test_cases = [
        dict(t) for t in {case["name"]: case for case in test_cases}.values()
    ]

    for case in filtered_test_cases:
        # Convert bytes to hex array format
        input_bytes = [f"0x{b:02x}" for b in case["input"]]
        test_name = f"test_{case['name']}"
        test_input = f"let input = array![{', '.join(input_bytes)}];"

        if not case["is_err"]:
            output_bytes = [f"0x{b:02x}" for b in case["output_data"]]

            test = f"""
    #[test]
    fn {test_name}() {{
        #[cairofmt::skip]
        {test_input}
        #[cairofmt::skip]
        let expected_result = array![{', '.join(output_bytes)}];
        let expected_gas = {case['output_gas']};

        let (gas, result) = ModExp::exec(input.span()).unwrap();
        assert_eq!(result, expected_result.span());
        assert_eq!(gas, expected_gas);
    }}"""
            cairo_tests.append(test)
            continue

        # In case the test errors, due to an input length too large
        # just assert result.is_err()
        test = f"""
        #[test]
        fn {test_name}() {{
            #[cairofmt::skip]
            {test_input}
            let result = ModExp::exec(input.span());
            assert!(result.is_err());
        }}
        """
        cairo_tests.append(test)

    return "\n".join(cairo_tests)


if __name__ == "__main__":
    # Run the Hypothesis test
    generate_test_modexp_384_bits_random_inputs()
    generate_test_modexp_384_bits_non_empty_outputs()

    # Generate and save the Cairo tests
    print(f"Generated {len(test_cases)} test cases")
    with open("generated_modexp_tests.cairo", "w") as f:
        f.write(generate_cairo_tests())

    print("Saved Cairo tests to generated_modexp_tests.cairo")
