from typing import Callable

import pytest
from web3 import Web3

from tests.utils.utils import traceit


@pytest.mark.asyncio
@pytest.mark.IntegrationTestContract
class TestIntegrationContract:
    class TestAddress:
        async def test_integration_contract(
            self,
            deploy_solidity_contract: Callable,
            addresses,
            request,
        ):
            counter = await deploy_solidity_contract(
                "Counter", caller_address=addresses[1]["int"]
            )
            counter_address = Web3.toChecksumAddress(
                "0x"
                + hex(
                    counter.contract_account.deploy_call_info.result.evm_contract_address
                )[2:].rjust(40, "0")
            )
            integration_contract = await deploy_solidity_contract(
                "IntegrationTestContract",
                counter_address,
                caller_address=addresses[1]["int"],
            )

            with traceit.context(request.node.own_markers[0].name):
                evm_contract_address = await integration_contract.opcodeAddress()

            assert (
                integration_contract.contract_account.deploy_call_info.result.evm_contract_address
                == int(evm_contract_address, 16)
            )
