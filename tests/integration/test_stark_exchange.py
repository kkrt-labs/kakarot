from typing import Callable

import pytest
from starkware.starknet.testing.contract import StarknetContract


@pytest.mark.asyncio
@pytest.mark.StarkExchange
class TestStarkExchange:
    class TestDeploy:
        async def test_stark_exchange_proxy_utils_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            proxy_utils = await deploy_solidity_contract("ProxyUtils", caller_address=1)

        async def test_stark_exchange_stark_exchange_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            stark_exchange = await deploy_solidity_contract(
                "StarkExchange", caller_address=1
            )

        async def test_stark_exchange_all_verifiers_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            all_verifiers = await deploy_solidity_contract(
                "AllVerifiers", caller_address=1
            )

        async def test_stark_exchange_forced_actions_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            forced_actions = await deploy_solidity_contract(
                "ForcedActions", caller_address=1
            )

        async def test_stark_exchange_on_chain_vaults_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            on_chain_vaults = await deploy_solidity_contract(
                "OnChainVaults", caller_address=1
            )

        async def test_stark_exchange_stark_ex_state_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            stark_ex_state = await deploy_solidity_contract(
                "StarkExState", caller_address=1
            )

        @pytest.mark.skip(
            "Currently getting Out of Resource issue - n_steps is estimated to be around 1.100.000"
        )
        async def test_stark_exchange_token_and_ramping_contract_deployment(
            self,
            deploy_solidity_contract: Callable,
        ):
            token_and_ramping = await deploy_solidity_contract(
                "TokenAndRamping", caller_address=1
            )
