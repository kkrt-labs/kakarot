import pytest
from web3 import Web3

from tests.utils.errors import evm_error


@pytest.mark.asyncio(scope="package")
@pytest.mark.PlainOpcodes
class TestPlainOpcodes:
    class TestStaticCall:
        async def test_should_return_counter_count(self, counter, plain_opcodes):
            assert await plain_opcodes.opcodeStaticCall() == await counter.count()

        async def test_should_revert_when_trying_to_modify_state(
            self,
            plain_opcodes,
        ):
            success, error = await plain_opcodes.opcodeStaticCall2()
            assert not success
            assert error == b""

    class TestCall:
        async def test_should_increase_counter(
            self,
            counter,
            plain_opcodes,
        ):
            count_before = await counter.count()
            await plain_opcodes.opcodeCall()
            count_after = await counter.count()
            assert count_after - count_before == 1

    class TestTimestamp:
        async def test_should_return_starknet_timestamp(
            self, plain_opcodes, block_with_tx_hashes
        ):
            timestamp = await plain_opcodes.opcodeTimestamp()
            assert timestamp == (await block_with_tx_hashes("pending")).timestamp

    class TestBlockhash:
        @pytest.mark.xfail(reason="Need to fix blockhash on real Starknet network")
        async def test_should_return_blockhash_with_valid_block_number(
            self,
            plain_opcodes,
            block_with_tx_hashes,
        ):
            latest_block = block_with_tx_hashes("latest")
            blockhash = await plain_opcodes.opcodeBlockHash(latest_block.block_number)

            assert int.from_bytes(blockhash, byteorder="big") == latest_block.block_hash

        async def test_should_return_zero_with_invalid_block_number(
            self,
            plain_opcodes,
            block_with_tx_hashes,
        ):
            latest_block = await block_with_tx_hashes("latest")
            blockhash_invalid_number = await plain_opcodes.opcodeBlockHash(
                latest_block.block_number + 1
            )

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

    class TestAddress:
        async def test_should_return_self_address(self, plain_opcodes):
            address = await plain_opcodes.opcodeAddress()

            assert int(plain_opcodes.address, 16) == int(address, 16)

    class TestExtCodeCopy:
        @pytest.mark.parametrize("offset, size", [[0, 32], [32, 32], [0, None]])
        async def test_should_return_counter_code(
            self, plain_opcodes, counter, offset, size
        ):
            """
            The counter.bytecode is indeed the structured as follows.

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
                "owner": Web3.to_checksum_address(f"{10:040x}"),
                "spender": Web3.to_checksum_address(f"{11:040x}"),
                "value": 10,
            }

        async def test_should_emit_log0_with_no_data(self, plain_opcodes, owner):
            receipt = (
                await plain_opcodes.opcodeLog0(caller_eoa=owner.starknet_contract)
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["Log0"] == [{}]

        async def test_should_emit_log0_with_data(self, plain_opcodes, owner, event):
            receipt = (
                await plain_opcodes.opcodeLog0Value(caller_eoa=owner.starknet_contract)
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["Log0Value"] == [{"value": event["value"]}]

        async def test_should_emit_log1(self, plain_opcodes, owner, event):
            receipt = (
                await plain_opcodes.opcodeLog1(caller_eoa=owner.starknet_contract)
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["Log1"] == [{"value": event["value"]}]

        async def test_should_emit_log2(self, plain_opcodes, owner, event):
            receipt = (
                await plain_opcodes.opcodeLog2(caller_eoa=owner.starknet_contract)
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            del event["spender"]
            assert events["Log2"] == [event]

        async def test_should_emit_log3(self, plain_opcodes, owner, event):
            receipt = (
                await plain_opcodes.opcodeLog3(caller_eoa=owner.starknet_contract)
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["Log3"] == [event]

        async def test_should_emit_log4(self, plain_opcodes, owner, event):
            receipt = (
                await plain_opcodes.opcodeLog4(caller_eoa=owner.starknet_contract)
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["Log4"] == [event]

    class TestCreate:
        @pytest.mark.parametrize("count", [1, 2])
        async def test_should_create_counters(
            self,
            plain_opcodes,
            counter,
            owner,
            get_solidity_contract,
            count,
            get_contract,
        ):
            plain_opcodes_contract_account = get_contract(
                "account_contract", address=plain_opcodes.starknet_address
            )
            nonce_initial = (
                await plain_opcodes_contract_account.functions["get_nonce"].call()
            ).nonce

            receipt = (
                await plain_opcodes.create(
                    bytecode=counter.constructor().data_in_transaction,
                    count=count,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert len(events["CreateAddress"]) == count
            for create_event in events["CreateAddress"]:
                deployed_counter = get_solidity_contract(
                    "PlainOpcodes", "Counter", address=create_event["_address"]
                )
                assert await deployed_counter.count() == 0

            nonce_final = (
                await plain_opcodes_contract_account.functions["get_nonce"].call()
            ).nonce
            assert nonce_final == nonce_initial + count

        @pytest.mark.parametrize("bytecode", ["0x", "0x6000600155600160015500"])
        async def test_should_create_empty_contract_when_creation_code_has_no_return(
            self,
            plain_opcodes,
            owner,
            bytecode,
            compute_starknet_address,
            get_contract,
        ):
            receipt = (
                await plain_opcodes.create(
                    bytecode=bytecode,
                    count=1,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]

            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert len(events["CreateAddress"]) == 1
            starknet_address = await compute_starknet_address(
                events["CreateAddress"][0]["_address"]
            )
            contract_account = get_contract(
                "account_contract", address=starknet_address
            )
            assert [] == (await contract_account.functions["bytecode"].call()).bytecode

        async def test_should_create_counter_and_call_in_the_same_tx(
            self,
            plain_opcodes,
            get_solidity_contract,
        ):
            receipt = (await plain_opcodes.createCounterAndCall())["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            address = events["CreateAddress"][0]["_address"]
            counter = get_solidity_contract("PlainOpcodes", "Counter", address=address)
            assert await counter.count() == 0

        async def test_should_create_counter_and_invoke_in_the_same_tx(
            self,
            plain_opcodes,
            get_solidity_contract,
        ):
            receipt = (await plain_opcodes.createCounterAndInvoke())["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            address = events["CreateAddress"][0]["_address"]
            counter = get_solidity_contract("PlainOpcodes", "Counter", address=address)
            assert await counter.count() == 1

    class TestCreate2:
        async def test_should_collision_after_selfdestruct_different_tx(
            self,
            plain_opcodes,
            get_solidity_contract,
            owner,
            eth_get_code,
        ):
            contract_with_selfdestruct = get_solidity_contract(
                "PlainOpcodes", "ContractWithSelfdestructMethod"
            )
            salt = 12345
            receipt = (
                await plain_opcodes.create2(
                    bytecode=contract_with_selfdestruct.constructor().data_in_transaction,
                    salt=salt,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert len(events["Create2Address"]) == 1
            contract_with_selfdestruct = get_solidity_contract(
                "PlainOpcodes",
                "ContractWithSelfdestructMethod",
                address=events["Create2Address"][0]["_address"],
            )
            pre_code = await eth_get_code(contract_with_selfdestruct.address)
            assert pre_code
            await contract_with_selfdestruct.kill()
            post_code = await eth_get_code(contract_with_selfdestruct.address)
            assert pre_code == post_code

            receipt = (
                await plain_opcodes.create2(
                    bytecode=contract_with_selfdestruct.constructor().data_in_transaction,
                    salt=salt,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]

            events = plain_opcodes.events.parse_starknet_events(receipt.events)

            # There should be a create2 collision which returns zero
            assert events["Create2Address"] == [
                {
                    "_address": "0x0000000000000000000000000000000000000000",
                }
            ]

        async def test_should_deploy_bytecode_at_address(
            self,
            plain_opcodes,
            counter,
            owner,
            get_solidity_contract,
            get_contract,
            compute_starknet_address,
        ):
            plain_opcodes_contract_account = get_contract(
                "account_contract", address=plain_opcodes.starknet_address
            )
            nonce_initial = (
                await plain_opcodes_contract_account.functions["get_nonce"].call()
            ).nonce

            salt = 1234
            receipt = (
                await plain_opcodes.create2(
                    bytecode=counter.constructor().data_in_transaction,
                    salt=salt,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert len(events["Create2Address"]) == 1

            deployed_counter = get_solidity_contract(
                "PlainOpcodes",
                "Counter",
                address=events["Create2Address"][0]["_address"],
            )
            assert await deployed_counter.count() == 0

            deployed_counter_contract_account = get_contract(
                "account_contract",
                address=await compute_starknet_address(deployed_counter.address),
            )

            assert (
                await deployed_counter_contract_account.functions["get_nonce"].call()
            ).nonce == 1

            nonce_final = (
                await plain_opcodes_contract_account.functions["get_nonce"].call()
            ).nonce
            assert nonce_final == nonce_initial + 1

    class TestRequire:
        async def test_should_revert_when_value_is_zero(self, plain_opcodes):
            with evm_error("ZERO_VALUE"):
                await plain_opcodes.requireNotZero(0)

        @pytest.mark.parametrize("value", [2**127, 2**128])
        async def test_should_not_revert_when_value_is_not_zero(
            self, plain_opcodes, value
        ):
            await plain_opcodes.requireNotZero(value)

    class TestExceptionHandling:
        async def test_calling_context_should_propagate_revert_from_sub_context_on_create(
            self, plain_opcodes, owner
        ):
            with evm_error("FAIL"):
                await plain_opcodes.newContractConstructorRevert(
                    caller_eoa=owner.starknet_contract
                )

        async def test_should_revert_via_call(
            self, plain_opcodes, get_solidity_contract, owner
        ):
            receipt = (
                await plain_opcodes.contractCallRevert(
                    caller_eoa=owner.starknet_contract
                )
            )["receipt"]

            reverting_contract = get_solidity_contract(
                "PlainOpcodes", "ContractRevertsOnMethodCall"
            )

            assert reverting_contract.events.parse_starknet_events(receipt.events) == {
                "PartyTime": []
            }

    class TestOriginAndSender:
        async def test_should_return_owner_as_origin_and_sender(
            self, plain_opcodes, owner
        ):
            origin, sender = await plain_opcodes.originAndSender(
                caller_eoa=owner.starknet_contract
            )
            assert origin == sender == owner.address

        async def test_should_return_owner_as_origin_and_caller_as_sender(
            self, plain_opcodes, owner, caller
        ):
            receipt = (
                await caller.call(
                    target=plain_opcodes.address,
                    payload=plain_opcodes.encodeABI("originAndSender"),
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]
            events = caller.events.parse_starknet_events(receipt.events)
            assert len(events["Call"]) == 1
            assert events["Call"][0]["success"]
            decoded = Web3().codec.decode(
                ["address", "address"], events["Call"][0]["returnData"]
            )
            assert int(owner.address, 16) == int(decoded[0], 16)  # tx.origin
            assert int(caller.address, 16) == int(decoded[1], 16)  # msg.sender

    class TestLoop:
        @pytest.mark.parametrize("steps", [0, 1, 2, 10])
        async def test_loop_should_write_to_storage(self, plain_opcodes, steps):
            value = await plain_opcodes.loop(steps)
            assert value == steps

    class TestTransfer:
        async def test_send_some_should_send_to_eoa(
            self, plain_opcodes, fund_starknet_address, eth_balance_of, owner, other
        ):
            amount = 1
            await fund_starknet_address(plain_opcodes.starknet_address, amount)

            receiver_balance_before = await eth_balance_of(
                other.starknet_contract.address
            )
            sender_balance_before = await eth_balance_of(plain_opcodes.starknet_address)

            await plain_opcodes.sendSome(
                other.address, amount, caller_eoa=owner.starknet_contract
            )

            receiver_balance_after = await eth_balance_of(
                other.starknet_contract.address
            )
            sender_balance_after = await eth_balance_of(plain_opcodes.starknet_address)

            assert receiver_balance_after - receiver_balance_before == amount
            assert sender_balance_before - sender_balance_after == amount

        async def test_send_some_should_revert_when_amount_exceed_balance(
            self, plain_opcodes, fund_starknet_address, eth_balance_of, owner, other
        ):
            amount = 1
            await fund_starknet_address(plain_opcodes.starknet_address, amount)

            sender_balance_before = await eth_balance_of(plain_opcodes.starknet_address)
            receipt = (
                await plain_opcodes.sendSome(
                    other.address,
                    sender_balance_before + 1,
                    caller_eoa=owner.starknet_contract,
                )
            )["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["SentSome"] == [
                {
                    "to": other.address,
                    "amount": sender_balance_before + 1,
                    "success": False,
                }
            ]
            assert sender_balance_before == await eth_balance_of(
                plain_opcodes.starknet_address
            )

    class TestMapping:
        async def test_should_emit_event_and_increase_nonce(self, plain_opcodes):
            receipt = (await plain_opcodes.incrementMapping())["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            prev_nonce = events["NonceIncreased"][0]["nonce"]
            receipt = (await plain_opcodes.incrementMapping())["receipt"]
            events = plain_opcodes.events.parse_starknet_events(receipt.events)
            assert events["NonceIncreased"][0]["nonce"] - prev_nonce == 1

    class TestFallbackFunctions:
        @pytest.mark.parametrize(
            "data,value,message", (("", 1234, "receive"), ("0x00", 0, "fallback"))
        )
        async def test_should_revert_on_fallbacks(
            self,
            revert_on_fallbacks,
            eth_send_transaction,
            data,
            value,
            message,
            addresses,
        ):
            receipt, response, success, gas_used = await eth_send_transaction(
                to=revert_on_fallbacks.address,
                gas=200_000,
                data=data,
                value=value,
                caller_eoa=addresses[2].starknet_contract,
            )
            assert not success
            assert f"reverted on {message}".encode() in bytes(response)

    class TestMulmod:
        async def test_should_return_0(self, plain_opcodes):
            assert 0 == await plain_opcodes.mulmodMax()

    class TestAddmod:
        async def test_should_return_0(self, plain_opcodes):
            assert 0 == await plain_opcodes.addmodMax()
