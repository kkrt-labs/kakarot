import pytest
from web3 import Web3

from tests.utils.errors import kakarot_error


@pytest.mark.asyncio
@pytest.mark.PlainOpcodes
@pytest.mark.usefixtures("starknet_snapshot")
class TestPlainOpcodes:
    class TestStaticCall:
        async def test_should_return_counter_count(self, counter, plain_opcodes):
            assert await plain_opcodes.opcodeStaticCall() == await counter.count()

        async def test_should_revert_when_trying_to_modify_state(
            self,
            plain_opcodes,
        ):
            with kakarot_error("Kakarot: StateModificationError"):
                await plain_opcodes.opcodeStaticCall2()

    class TestCall:
        async def test_should_increase_counter(
            self,
            counter,
            plain_opcodes,
            addresses,
        ):
            await plain_opcodes.opcodeCall(caller_address=addresses[1].starknet_address)
            assert await counter.count() == 1

    class TestBlockhash:
        async def test_should_return_blockhash_with_valid_block_number(
            self,
            plain_opcodes,
            blockhashes,
        ):
            block_number = max(blockhashes["last_256_blocks"].keys())
            blockhash = await plain_opcodes.opcodeBlockHash(int(block_number))

            assert (
                int.from_bytes(blockhash, byteorder="big")
                == blockhashes["last_256_blocks"][block_number]
            )

            blockhash_invalid_number = await plain_opcodes.opcodeBlockHash(1)

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

        async def test_should_return_0_with_invalid_block_number(
            self,
            plain_opcodes,
        ):
            blockhash_invalid_number = await plain_opcodes.opcodeBlockHash(1)

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

    class TestAddress:
        async def test_should_return_self_address(
            self,
            plain_opcodes,
        ):
            evm_contract_address = await plain_opcodes.opcodeAddress()

            assert int(plain_opcodes.evm_contract_address, 16) == int(
                evm_contract_address, 16
            )

    class TestExtCodeCopy:
        @pytest.mark.parametrize("offset, size", [[0, 32], [32, 32], [0, None]])
        async def test_should_return_counter_code(
            self, plain_opcodes, counter, offset, size
        ):
            """
            The counter.bytecode is indeed the structured as follows

                constructor bytecode      contract bytecode       calldata
            |------------------------FE|----------------------|---------------|

            When deploying a contract, the constructor bytecode is run but not
            stored eventually,
            """
            deployed_bytecode = counter.bytecode[counter.bytecode.index(0xFE) + 1 :]
            size = len(deployed_bytecode) if size is None else size
            bytecode = await plain_opcodes.opcodeExtCodeCopy(offset=offset, size=size)
            assert bytecode == deployed_bytecode[offset : offset + size]

    class TestLog:
        @pytest.fixture
        def event(self):
            return {
                "owner": Web3.toChecksumAddress(f"{10:040x}"),
                "spender": Web3.toChecksumAddress(f"{11:040x}"),
                "value": 10,
            }

        async def test_should_emit_log0_with_no_data(self, plain_opcodes, addresses):
            await plain_opcodes.opcodeLog0(caller_address=addresses[0].starknet_address)
            assert plain_opcodes.events.Log0 == [{}]

        async def test_should_emit_log0_with_data(
            self, plain_opcodes, addresses, event
        ):
            await plain_opcodes.opcodeLog0Value(
                caller_address=addresses[0].starknet_address
            )
            assert plain_opcodes.events.Log0Value == [{"value": event["value"]}]

        async def test_should_emit_log1(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog1(caller_address=addresses[0].starknet_address)
            assert plain_opcodes.events.Log1 == [{"value": event["value"]}]

        async def test_should_emit_log2(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog2(caller_address=addresses[0].starknet_address)
            del event["spender"]
            assert plain_opcodes.events.Log2 == [event]

        async def test_should_emit_log3(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog3(caller_address=addresses[0].starknet_address)
            assert plain_opcodes.events.Log3 == [event]

        async def test_should_emit_log4(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog4(caller_address=addresses[0].starknet_address)
            assert plain_opcodes.events.Log4 == [event]

    class TestCreate2:
        async def test_should_deploy_bytecode_at_address(
            self,
            plain_opcodes,
            counter,
            addresses,
            get_starknet_address,
            get_solidity_contract,
        ):
            salt = 1234
            evm_address = await plain_opcodes.create2(
                bytecode=counter.constructor().data_in_transaction,
                salt=salt,
                caller_address=addresses[0].starknet_address,
            )
            starknet_address = get_starknet_address(salt)
            deployed_counter = get_solidity_contract(
                "PlainOpcodes", "Counter", starknet_address, evm_address, None
            )
            assert await deployed_counter.count() == 0

    class TestRequire:
        async def test_should_revert_when_address_is_zero(
            self, plain_opcodes, addresses
        ):
            with kakarot_error("ZERO_ADDRESS"):
                await plain_opcodes.requireNotZero(
                    f"0x{0:040x}",
                    caller_address=addresses[0].starknet_address,
                )

        @pytest.mark.skip("Test fails when address is 2**128 or greater")
        @pytest.mark.parametrize("address", [2**127, 2**128])
        async def test_should_not_revert_when_address_is_not_zero(
            self, plain_opcodes, addresses, address
        ):
            await plain_opcodes.requireNotZero(
                f"0x{address:x}",
                caller_address=addresses[0].starknet_address,
            )

    class TestOriginAndSender:
        @pytest.mark.skip(
            "Origin returns 0 because ORIGIN currently assumes that the caller is a ContractAccount"
            "See issue https://github.com/sayajin-labs/kakarot/issues/445"
        )
        async def test_should_return_owner_as_origin_and_sender(
            self, plain_opcodes, owner
        ):
            origin, sender = await plain_opcodes.originAndSender(
                caller_address=owner.starknet_address
            )
            assert origin == sender == owner.address

        @pytest.mark.skip(
            "ORIGIN returns address(0)"
            "See issue https://github.com/sayajin-labs/kakarot/issues/445"
            # "Raises in RETURNDATACOPY"
            # "See issue https://github.com/sayajin-labs/kakarot/issues/446"
        )
        async def test_should_return_owner_as_origin_and_caller_as_sender(
            self, plain_opcodes, owner, caller
        ):
            success, data = await caller.call(
                target=plain_opcodes.evm_contract_address,
                payload=plain_opcodes.encodeABI("originAndSender"),
                caller_address=owner.starknet_address,
            )
            assert success
            decoded = Web3().codec.decode(["address", "address"], data)
            assert owner.address == decoded[0]  # tx.origin
            assert caller.evm_contract_address == decoded[1]  # msg.sender
