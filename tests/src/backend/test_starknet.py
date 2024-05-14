from starkware.starknet.public.abi import get_selector_from_name

from tests.utils.syscall_handler import SyscallHandler


class TestStarknet:
    class TestGetEnv:
        def test_should_return_env_with_given_origin_and_gas_price(self, cairo_run):
            env = cairo_run("test__get_env", origin=1, gas_price=2)
            assert env["origin"] == 1
            assert env["gas_price"] == 2

    class TestSaveValidJumpdests:
        @SyscallHandler.patch(
            "IERC20.balanceOf",
            lambda addr, data: [0, 0],
        )
        @SyscallHandler.patch("IAccount.write_jumpdests", lambda addr, data: [])
        def test_should_save_jumpdests_to_storage(self, cairo_run):
            jumpdests = {0x1: True, 0x10: False, 0x101: True}
            contract_address = 0x97283590
            cairo_run(
                "test__save_valid_jumpdests",
                jumpdests=jumpdests,
                contract_address=contract_address,
            )

            expected_valid_jumpdests = [
                key for key, value in jumpdests.items() if value != 0
            ]
            SyscallHandler.mock_call.assert_any_call(
                contract_address=contract_address,
                function_selector=get_selector_from_name("write_jumpdests"),
                calldata=[len(expected_valid_jumpdests), *expected_valid_jumpdests],
            )
