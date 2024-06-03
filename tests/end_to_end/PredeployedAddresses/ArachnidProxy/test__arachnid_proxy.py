import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy_raw_bytecode, eth_call
from kakarot_scripts.utils.starknet import wait_for_transaction

# from https://github.com/Arachnid/deterministic-deployment-proxy/blob/master/scripts/test.sh
PROXY_ADDRESS = 0x4E59B44847B379578588920CA78FBF26C0B4956C
INITCODE_PATH = "tests/end_to_end/PredeployedAddresses/ArachnidProxy/bytecode.txt"
# contract: pragma solidity 0.5.8; contract Apple {function banana() external pure returns (uint8) {return 42;}}
TEST_CONTRACT_BYTECODE = "6080604052348015600f57600080fd5b5060848061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063c3cafc6f14602d575b600080fd5b6033604f565b604051808260ff1660ff16815260200191505060405180910390f35b6000602a90509056fea165627a7a72305820ab7651cb86b8c1487590004c2444f26ae30077a6b96c6bc62dda37f1328539250029"
EXPECTED_DEPLOYED_ADDRESS = 0x115BCF08A650D194D410F1CA43A17CA41C8D88BC


async def deploy_proxy(invoke) -> (int, int):
    with open(INITCODE_PATH, "r") as f:
        initcode = bytes.fromhex(f.read()[:-1])

    evm_address, starknet_address = await deploy_raw_bytecode(initcode)
    tx_hash = await invoke("kakarot", "set_patched_address", PROXY_ADDRESS, evm_address)
    await wait_for_transaction(tx_hash)
    return evm_address, starknet_address


class TestArachnidProxyPatch:
    @pytest.mark.asyncio(scope="module")
    async def test_should_get_patched_address(self, invoke, call):
        evm_address, _ = await deploy_proxy(invoke)
        patched_address = (
            await call(
                "kakarot",
                "get_patched_address",
                PROXY_ADDRESS,
            )
        ).patched_address
        assert patched_address == evm_address

    @pytest.mark.asyncio(scope="module")
    async def test_should_deploy_to_same_address_as_sepolia(
        self, invoke, owner, eth_send_transaction
    ):
        await deploy_proxy(invoke)
        salt = bytes.fromhex(f"{0:064x}")
        initcode = bytes.fromhex(TEST_CONTRACT_BYTECODE)
        data = salt + initcode

        receipt, response, success, gas_used = await eth_send_transaction(
            to=PROXY_ADDRESS, gas=200_000, data=data, value=0
        )
        deployed_address = int.from_bytes(response, "big")
        assert deployed_address == EXPECTED_DEPLOYED_ADDRESS

        result = await eth_call(
            to=hex(deployed_address),
            calldata=bytes.fromhex("c3cafc6f"),
            gas_limit=30_000,
        )
        assert int.from_bytes(bytes(result), "big") == 0x2A
        # call `c3cafc6f` (banana) on the deployed contract
