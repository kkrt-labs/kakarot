import logging

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import get_contract as get_contract_starknet
from kakarot_scripts.utils.starknet import invoke

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


@pytest_asyncio.fixture(scope="package")
async def starknet_token(owner):
    address = await deploy_starknet(
        "StarknetToken",
        "MyToken",
        "MTK",
        18,
        int(2**256 - 1),
        owner.starknet_contract.address,
    )
    return get_contract_starknet("StarknetToken", address=address)


@pytest_asyncio.fixture(
    scope="package",
    params=[
        ("CairoPrecompiles", "DualVmToken"),
        ("NoDelegateCallTesting", "DualVmTokenWithoutModifier"),
    ],
    ids=["Modifier", "NoModifier"],
)
async def dual_vm_token(request, kakarot, starknet_token, owner):
    dual_vm_token = await deploy_kakarot(
        request.param[0],
        request.param[1],
        kakarot.address,
        starknet_token.address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(dual_vm_token.address, 16),
        True,
    )
    return dual_vm_token


@pytest_asyncio.fixture(scope="package")
async def hack_vm_token(dual_vm_token, owner):
    hack_vm_token = await deploy_kakarot(
        "CairoPrecompiles",
        "DualVmTokenHack",
        dual_vm_token.address,
        caller_eoa=owner.starknet_contract,
    )
    return hack_vm_token


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestDualVmToken:
    class TestActions:
        async def test_malicious_approve_address_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token, owner
        ):
            result = await hack_vm_token.functions["tryApproveEvm()"](gas_limit=1000000)
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            allowance = await dual_vm_token.functions["allowance(address,address)"](
                owner.address, hack_vm_token.address
            )
            assert allowance == 0

        async def test_malicious_approve_starknet_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token, owner
        ):
            result = await hack_vm_token.functions["tryApproveStarknet()"]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            allowance = await dual_vm_token.functions["allowance(address,uint256)"](
                owner.address, int(hack_vm_token.address, 16)
            )
            assert allowance == 0

        async def test_malicious_transfer_address_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token
        ):
            result = await hack_vm_token.functions["tryTransferEvm()"]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            balance = await dual_vm_token.functions["balanceOf(address)"](
                hack_vm_token.address
            )
            assert balance == 0

        async def test_malicious_transfer_starknet_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token
        ):
            result = await hack_vm_token.functions["tryTransferStarknet()"]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            balance = await dual_vm_token.functions["balanceOf(uint256)"](
                int(hack_vm_token.address, 16)
            )
            assert balance == 0

        async def test_malicious_transfer_from_address_address_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token
        ):
            result = await hack_vm_token.functions["tryTransferFromEvmEvm()"]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            balance = await dual_vm_token.functions["balanceOf(address)"](
                hack_vm_token.address
            )
            assert balance == 0

        async def test_malicious_transfer_from_starknet_address_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token
        ):
            result = await hack_vm_token.functions["tryTransferFromStarknetEvm()"]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            balance = await dual_vm_token.functions["balanceOf(address)"](
                hack_vm_token.address
            )
            assert balance == 0

        async def test_malicious_transfer_from_address_starknet_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token
        ):
            result = await hack_vm_token.functions["tryTransferFromEvmStarknet()"]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            balance = await dual_vm_token.functions["balanceOf(uint256)"](
                int(hack_vm_token.address, 16)
            )
            assert balance == 0

        async def test_malicious_transfer_from_starknet_starknet_should_fail_nodelegatecall(
            self, dual_vm_token, hack_vm_token
        ):
            result = await hack_vm_token.functions[
                "tryTransferFromStarknetStarknet()"
            ]()
            assert result["success"] == 1
            underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
            assert underlying_call_succeeded == 0

            balance = await dual_vm_token.functions["balanceOf(uint256)"](
                int(hack_vm_token.address, 16)
            )
            assert balance == 0
