from starkware.starknet.testing.starknet import StarknetContract


async def fund_evm_address(
    evm_address: int, kakarot: StarknetContract, eth: StarknetContract, amount=10000000
):
    computed_starknet_address = (
        await kakarot.compute_starknet_address(evm_address).call()
    ).result[0]

    # pre fund account so that fees can be paid back to deployer
    await eth.mint(computed_starknet_address, (amount, 0)).execute(caller_address=1234)
