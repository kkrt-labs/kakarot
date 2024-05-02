from starkware.starknet.public.abi import get_selector_from_name

from tests.utils.syscall_handler import SyscallHandler


class TestStarknet:
    class TestGetEnv:
        def test_should_return_env_with_given_origin_and_gas_price(self, cairo_run):
            env = cairo_run("test__get_env", origin=1, gas_price=2)
            assert env["origin"] == 1
            assert env["gas_price"] == 2

    class TestSaveTestStarknetJumpdests:
        @SyscallHandler.patch("IAccount.write_jumpdests", lambda addr, data: [])
        def test_should_save_jumpdests_to_storage(self, cairo_run):
            valid_jumpdests = [(0x01, 0, 1), (0x10, 0, 1), (0x101, 0, 1)]
            contract_address = 0x97283590
            valid_indexes = cairo_run(
                "test__save_valid_jumpdests",
                jumpdests=valid_jumpdests,
                contract_address=contract_address,
            )

            assert valid_indexes == [
                valid_jumpdest[0] for valid_jumpdest in valid_jumpdests
            ]

            SyscallHandler.mock_call.assert_any_call(
                contract_address=contract_address,
                function_selector=get_selector_from_name("write_jumpdests"),
                calldata=[len(valid_indexes), *valid_indexes],
            )
