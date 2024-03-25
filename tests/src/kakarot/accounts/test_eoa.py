from starkware.starknet.public.abi import get_storage_var_address

from tests.utils.syscall_handler import SyscallHandler


class TestExternallyOwnedAccount:
    class TestInitialize:
        @SyscallHandler.patch("IKakarot.get_native_token", lambda addr, data: [0xDEAD])
        @SyscallHandler.patch("IERC20.approve", lambda addr, data: [1])
        def test_should_store_given_addresses(self, cairo_run):
            cairo_run(
                "test__initialize__should_store_given_evm_address",
                kakarot_address=0x1234,
                evm_address=0xABDE1,
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("kakarot_address_"), value=0x1234
            )
            SyscallHandler.mock_storage.assert_any_call(
                address=get_storage_var_address("evm_address_"), value=0xABDE1
            )

    class TestGetEvmAddress:
        @SyscallHandler.patch("evm_address_", 0xABDE1)
        def test_should_return_stored_address(self, cairo_run):
            output = cairo_run("test__get_evm_address__should_return_stored_address")
            assert output == [0xABDE1]
