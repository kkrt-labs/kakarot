import pytest
import pytest_asyncio
from eth_utils import keccak

from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import get_contract as get_contract_starknet
from kakarot_scripts.utils.starknet import get_starknet_account, invoke
from tests.utils.errors import cairo_error


@pytest_asyncio.fixture(scope="function")
async def starknet_token(owner):
    address = (
        await deploy_starknet(
            "StarknetToken", int(1e18), owner.starknet_contract.address
        )
    )["address"]
    return get_contract_starknet("StarknetToken", address=address)


@pytest_asyncio.fixture(scope="function")
async def dual_vm_token(kakarot, starknet_token, owner):
    dual_vm_token = await deploy_kakarot(
        "CairoPrecompiles",
        "DualVmToken",
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


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestDualVmToken:
    class TestMetadata:
        async def test_should_return_name(self, starknet_token, dual_vm_token):
            (name_starknet,) = await starknet_token.functions["name"].call()
            name_evm = await dual_vm_token.name()
            assert name_starknet == name_evm

        async def test_should_return_symbol(self, starknet_token, dual_vm_token):
            (symbol_starknet,) = await starknet_token.functions["symbol"].call()
            symbol_evm = await dual_vm_token.symbol()
            assert symbol_starknet == symbol_evm

        async def test_should_return_decimals(self, starknet_token, dual_vm_token):
            (decimals_starknet,) = await starknet_token.functions["decimals"].call()
            decimals_evm = await dual_vm_token.decimals()
            assert decimals_starknet == decimals_evm

    class TestAccounting:

        async def test_should_return_total_supply(self, starknet_token, dual_vm_token):
            (total_supply_starknet,) = await starknet_token.functions[
                "total_supply"
            ].call()
            total_supply_evm = await dual_vm_token.totalSupply()
            assert total_supply_starknet == total_supply_evm

        @pytest.mark.parametrize(
            "signature,account_address",
            [
                ("balanceOf(address)", lambda account: account.address),
                (
                    "balanceOf(uint256)",
                    lambda account: account.starknet_contract.address,
                ),
            ],
        )
        async def test_should_return_balance(
            self, starknet_token, dual_vm_token, owner, signature, account_address
        ):
            (balance_owner_starknet,) = await starknet_token.functions[
                "balance_of"
            ].call(owner.starknet_contract.address)
            balance_owner_evm = await dual_vm_token.functions[signature](
                account_address(owner)
            )
            assert balance_owner_starknet == balance_owner_evm

        async def test_should_revert_balance_of_invalid_address(
            self, starknet_token, dual_vm_token
        ):
            evm_error = keccak(b"InvalidStarknetAddress()")[:4]
            with cairo_error(evm_error):
                await dual_vm_token.functions["balanceOf(uint256)"](2**256 - 1)

    class TestActions:
        async def test_should_transfer(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            receipt = (
                await dual_vm_token.functions["transfer(address,uint256)"](
                    other.address, amount
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer(address,address,uint256)"] == [
                {
                    "from": str(owner.address),
                    "to": str(other.address),
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_transfer_starknet_address(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            receipt = (
                await dual_vm_token.functions["transfer(uint256,uint256)"](
                    other.starknet_contract.address, amount
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer(address,uint256,uint256)"] == [
                {
                    "from": str(owner.address),
                    "to": other.starknet_contract.address,
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        @pytest.mark.parametrize(
            "signature,to_address",
            [
                ("transfer(address,uint256)", lambda to: to.address),
                (
                    "transfer(uint256,uint256)",
                    lambda to: to.starknet_contract.address,
                ),
            ],
        )
        async def test_should_revert_transfer_insufficient_balance(
            self, dual_vm_token, owner, other, signature, to_address
        ):
            # No wrapping of errors for OZ 0.10 contracts
            with cairo_error("u256_sub Overflow"):
                await dual_vm_token.functions[signature](
                    to_address(owner), 1, caller_eoa=other.starknet_contract
                )

        async def test_should_revert_transfer_starknet_address_invalid_address(
            self, starknet_token, dual_vm_token
        ):
            evm_error = keccak(b"InvalidStarknetAddress()")[:4]
            with cairo_error(evm_error):
                await dual_vm_token.functions["transfer(uint256,uint256)"](
                    2**256 - 1, 1
                )

        async def test_should_approve(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            allowance_before = await dual_vm_token.functions[
                "allowance(address,address)"
            ](owner.address, other.address)
            receipt = (
                await dual_vm_token.functions["approve(address,uint256)"](
                    other.address, amount
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Approval(address,address,uint256)"] == [
                {
                    "owner": str(owner.address),
                    "spender": str(other.address),
                    "amount": amount,
                }
            ]
            allowance_after = await dual_vm_token.functions[
                "allowance(address,address)"
            ](owner.address, other.address)
            assert allowance_after == allowance_before + amount

        async def test_should_approve_starknet_address(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            allowance_before = await dual_vm_token.functions[
                "allowance(address,uint256)"
            ](owner.address, other.starknet_contract.address)
            receipt = (
                await dual_vm_token.functions["approve(uint256,uint256)"](
                    other.starknet_contract.address, amount
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Approval(address,uint256,uint256)"] == [
                {
                    "owner": str(owner.address),
                    "spender": other.starknet_contract.address,
                    "amount": amount,
                }
            ]
            allowance_after = await dual_vm_token.functions[
                "allowance(address,uint256)"
            ](owner.address, other.starknet_contract.address)
            assert allowance_after == allowance_before + amount

        async def test_should_revert_approve_starknet_address_invalid_address(
            self, starknet_token, dual_vm_token
        ):
            evm_error = keccak(b"InvalidStarknetAddress()")[:4]
            with cairo_error(evm_error):
                await dual_vm_token.functions["approve(uint256,uint256)"](2**256 - 1, 1)

        async def test_allowance_owner_starknet_address(
            self, starknet_token, dual_vm_token, other
        ):

            amount = 1
            owner = await get_starknet_account()
            allowance_before = await dual_vm_token.functions[
                "allowance(uint256,address)"
            ](owner.address, other.address)
            await invoke(
                starknet_token.address,
                "approve",
                other.starknet_contract.address,
                amount,
                0,
                account=owner,
            )
            allowance_after = await dual_vm_token.functions[
                "allowance(uint256,address)"
            ](owner.address, other.address)
            assert allowance_after == allowance_before + amount

        async def test_should_revert_allowance_starknet_address_owner_invalid_address(
            self, starknet_token, dual_vm_token, other
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await dual_vm_token.functions["allowance(uint256,address)"](
                    2**256 - 1, other.address
                )

        async def test_should_revert_allowance_starknet_address_spender_invalid_address(
            self, starknet_token, dual_vm_token, owner
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await dual_vm_token.functions["allowance(address,uint256)"](
                    owner.address, 2**256 - 1
                )

        async def test_allowance_owner_and_spender_starknet_address(
            self, starknet_token, dual_vm_token, new_eoa
        ):
            amount = 1
            owner = await get_starknet_account()
            eoa = await new_eoa()
            spender = await get_starknet_account(eoa.private_key)
            allowance_before = await dual_vm_token.functions[
                "allowance(uint256,uint256)"
            ](owner.address, spender.address)

            await invoke(
                starknet_token.address,
                "approve",
                spender.address,
                amount,
                0,
                account=owner,
            )

            allowance_after = await dual_vm_token.functions[
                "allowance(uint256,uint256)"
            ](owner.address, spender.address)
            assert allowance_after == allowance_before + amount

        async def test_should_transfer_from(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            await dual_vm_token.functions["approve(address,uint256)"](
                other.address, amount
            )
            receipt = (
                await dual_vm_token.functions["transferFrom(address,address,uint256)"](
                    owner.address,
                    other.address,
                    amount,
                    caller_eoa=other.starknet_contract,
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer(address,address,uint256)"] == [
                {
                    "from": str(owner.address),
                    "to": str(other.address),
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_transfer_from_starknet_address_from(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            await dual_vm_token.functions["approve(uint256,uint256)"](
                other.starknet_contract.address, amount
            )
            receipt = (
                await dual_vm_token.functions["transferFrom(uint256,address,uint256)"](
                    owner.starknet_contract.address,
                    other.address,
                    amount,
                    caller_eoa=other.starknet_contract,
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer(uint256,address,uint256)"] == [
                {
                    "from": owner.starknet_contract.address,
                    "to": str(other.address),
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_transfer_from_starknet_address_to(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            await dual_vm_token.functions["approve(uint256,uint256)"](
                other.starknet_contract.address, amount
            )
            receipt = (
                await dual_vm_token.functions["transferFrom(address,uint256,uint256)"](
                    owner.address,
                    other.starknet_contract.address,
                    amount,
                    caller_eoa=other.starknet_contract,
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer(address,uint256,uint256)"] == [
                {
                    "from": str(owner.address),
                    "to": other.starknet_contract.address,
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_transfer_from_starknet_address_from_and_to(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            await dual_vm_token.functions["approve(uint256,uint256)"](
                other.starknet_contract.address, amount
            )
            receipt = (
                await dual_vm_token.functions["transferFrom(uint256,uint256,uint256)"](
                    owner.starknet_contract.address,
                    other.starknet_contract.address,
                    amount,
                    caller_eoa=other.starknet_contract,
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer(uint256,uint256,uint256)"] == [
                {
                    "from": owner.starknet_contract.address,
                    "to": other.starknet_contract.address,
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.functions["balanceOf(address)"](
                owner.address
            )
            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        @pytest.mark.parametrize(
            "signature,from_address,to_address",
            [
                (
                    "transferFrom(address,address,uint256)",
                    lambda other: other.address,
                    lambda owner: owner.address,
                ),
                (
                    "transferFrom(uint256,address,uint256)",
                    lambda other: other.starknet_contract.address,
                    lambda owner: owner.address,
                ),
                (
                    "transferFrom(address,uint256,uint256)",
                    lambda other: other.address,
                    lambda owner: owner.starknet_contract.address,
                ),
                (
                    "transferFrom(uint256,uint256,uint256)",
                    lambda other: other.starknet_contract.address,
                    lambda owner: owner.starknet_contract.address,
                ),
            ],
        )
        async def test_should_revert_transfer_from_insufficient_balance(
            self, dual_vm_token, owner, other, signature, from_address, to_address
        ):
            # No wrapping of errors for OZ 0.10 contracts
            with cairo_error("u256_sub Overflow"):
                amount = 1
                await dual_vm_token.functions["approve(address,uint256)"](
                    owner.address, amount
                )
                await dual_vm_token.functions[signature](
                    from_address(other),
                    to_address(owner),
                    amount,
                    caller_eoa=owner.starknet_contract,
                )

        @pytest.mark.parametrize(
            "signature,from_address,to_address",
            [
                (
                    "transferFrom(address,address,uint256)",
                    lambda owner: owner.address,
                    lambda other: other.address,
                ),
                (
                    "transferFrom(uint256,address,uint256)",
                    lambda owner: owner.starknet_contract.address,
                    lambda other: other.address,
                ),
                (
                    "transferFrom(address,uint256,uint256)",
                    lambda owner: owner.address,
                    lambda other: other.starknet_contract.address,
                ),
                (
                    "transferFrom(uint256,uint256,uint256)",
                    lambda owner: owner.starknet_contract.address,
                    lambda other: other.starknet_contract.address,
                ),
            ],
        )
        async def test_should_revert_transfer_from_insufficient_allowance(
            self, dual_vm_token, owner, other, signature, from_address, to_address
        ):
            # No wrapping of errors for OZ 0.10 contracts
            with cairo_error("u256_sub Overflow"):
                await dual_vm_token.functions[signature](
                    from_address(other),
                    to_address(owner),
                    1,
                    caller_eoa=other.starknet_contract,
                )

        @pytest.mark.parametrize(
            "signature,from_address,to_address",
            [
                (
                    "transferFrom(uint256,address,uint256)",
                    lambda _: 2**256 - 1,
                    lambda other: other.address,
                ),
                (
                    "transferFrom(address,uint256,uint256)",
                    lambda owner: owner.address,
                    lambda _: 2**256 - 1,
                ),
            ],
        )
        async def test_should_revert_transfer_from_starknet_address_invalid_address(
            self, dual_vm_token, owner, other, signature, from_address, to_address
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await dual_vm_token.functions[signature](
                    from_address(other),
                    to_address(owner),
                    1,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_revert_transfer_from_starknet_address_from_and_to_invalid_address(
            self, starknet_token, dual_vm_token, other
        ):
            evm_error = keccak(b"InvalidStarknetAddress()")[:4]
            with cairo_error(evm_error):
                await dual_vm_token.functions["transferFrom(uint256,uint256,uint256)"](
                    2**256 - 1, 2**256 - 1, 1, caller_eoa=other.starknet_contract
                )

        async def test_should_revert_tx_cairo_precompiles(
            self, starknet_token, dual_vm_token, owner, other
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await dual_vm_token.transfer(
                    other.address, 1, gas_limit=45_000
                )  # fails with out of gas

    class TestIntegrationUniswap:
        async def test_should_add_liquidity_and_swap(
            starknet_token, dual_vm_token, token_a, router, owner, other
        ):
            amount_a_desired = 1000 * await token_a.decimals()
            amount_dual_vm_token_desired = 500 * await dual_vm_token.decimals()

            await token_a.mint(owner.address, amount_a_desired)
            await token_a.approve(
                router.address, amount_a_desired * 2, caller_eoa=owner.starknet_contract
            )
            await dual_vm_token.functions["approve(address,uint256)"](
                router.address,
                amount_dual_vm_token_desired * 2,
                caller_eoa=owner.starknet_contract,
            )

            deadline = 99999999999
            to_address = owner.address
            success = (
                await router.addLiquidity(
                    token_a.address,
                    dual_vm_token.address,
                    amount_a_desired,
                    amount_dual_vm_token_desired,
                    0,
                    0,
                    to_address,
                    deadline,
                    caller_eoa=owner.starknet_contract,
                )
            )["success"]

            assert success == 1

            amount_dual_vm_token_desired = 5 * await dual_vm_token.decimals()

            balance_other_before = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            amount_in_max = 2**128
            success = (
                await router.swapTokensForExactTokens(
                    amount_dual_vm_token_desired,
                    amount_in_max,
                    [token_a.address, dual_vm_token.address],
                    other.address,
                    deadline,
                    caller_eoa=owner.starknet_contract,
                )
            )["success"]
            assert success == 1

            balance_other_after = await dual_vm_token.functions["balanceOf(address)"](
                other.address
            )
            assert (
                balance_other_before + amount_dual_vm_token_desired
                == balance_other_after
            )
