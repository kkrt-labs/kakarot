import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet

random.seed(0)


@pytest_asyncio.fixture(scope="module")
async def environmental_information(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_environmental_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestEnvironmentalInformation:
    async def test_address(
        self,
        environmental_information,
    ):
        await environmental_information.test__exec_address__should_push_address_to_stack().call()

    async def test_extcodesize(
        self,
        environmental_information,
        account_registry,
    ):
        await environmental_information.test__exec_extcodesize__should_handle_address_with_no_code(
            account_registry_address=account_registry.contract_address
        ).call()

    async def test_extcodecopy_should_handle_address_with_no_code(
        self,
        environmental_information,
        account_registry,
    ):
        await environmental_information.test__exec_extcodecopy__should_handle_address_with_no_code(
            account_registry_address=account_registry.contract_address
        ).call()
        await environmental_information.test__returndatacopy().call()

    @pytest.mark.parametrize(
        "case",
        [
            {
                "size": 31,
                "offset": 0,
                "dest_offset": 0,
            },
            {
                "size": 33,
                "offset": 0,
                "dest_offset": 0,
            },
            {
                "size": 1,
                "offset": 32,
                "dest_offset": 0,
            },
        ],
        ids=["size_is_bytecodelen-1", "size_is_bytecodelen+1", "offset_is_bytecodelen"],
    )
    async def test_excodecopy_should_handle_address_with_code(
        self,
        contract_account,
        kakarot,
        account_registry,
        environmental_information,
        case,
    ):
        bytecode = [random.randint(0, 255) for _ in range(32)]

        contract_account = await contract_account.write_bytecode(bytecode).execute(
            caller_address=1
        )

        starknet_contract_address = contract_account.call_info.contract_address

        evm_contract_address = 1

        await account_registry.set_account_entry(
            starknet_contract_address, evm_contract_address
        ).execute(caller_address=kakarot.contract_address)

        size = case["size"]
        offset = case["offset"]
        dest_offset = case["dest_offset"]

        res = await environmental_information.test__exec_extcodecopy__should_handle_address_with_code(
            account_registry_address=account_registry.contract_address,
            evm_contract_address=evm_contract_address,
            size=size,
            offset=offset,
            dest_offset=dest_offset,
        ).call()

        memory_result = res.result.memory

        expected = (bytecode + [0] * (offset + size))[offset : (offset + size)]

        assert memory_result == expected
