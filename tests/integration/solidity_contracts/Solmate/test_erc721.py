import pytest


@pytest.mark.asyncio
@pytest.mark.SolmateERC721
class TestERC721:
    class TestDeploy:
        async def test_should_set_name_and_symbol(self, erc_721):
            name = await erc_721.name()
            assert name == "Kakarot NFT"
            symbol = await erc_721.symbol()
            assert symbol == "KKNFT"

    async def test_should_mint(self, addresses, erc_721):
        await erc_721.mint(
            addresses[1].address, 1337, caller_address=addresses[1].starknet_address
        )
        balance = await erc_721.balanceOf(addresses[1].address)
        owner = await erc_721.ownerOf(1337)

        assert balance == 1
        assert owner == addresses[1].address

    async def test_should_burn(self, addresses, erc_721):

        await erc_721.mint(
            addresses[1].address, 1337, caller_address=addresses[1].starknet_address
        )
        await erc_721.burn(1337, caller_address=addresses[1].starknet_address)
        balance = await erc_721.balanceOf(addresses[1].address)

        assert balance == 0

        # todo expect NOT_MINTED
        # token.ownerOf(1337);

    async def test_should_approve(self, addresses, erc_721):
        await erc_721.mint(
            addresses[1].address, 1337, caller_address=addresses[1].starknet_address
        )
        await erc_721.approve(
            addresses[2].address, 1337, caller_address=addresses[1].starknet_address
        )
        approved = await erc_721.getApproved(1337)

        assert approved == addresses[2].address

    async def test_should_approve_all(self, addresses, erc_721):
        await erc_721.setApprovalForAll(
            addresses[2].address, True, caller_address=addresses[1].starknet_address
        )

        is_approved_for_all = await erc_721.isApprovedForAll(
            addresses[1].address, addresses[2].address
        )

        assert is_approved_for_all == True

    async def test_should_transfer_from(self, addresses, erc_721):
        await erc_721.mint(
            addresses[2].address, 1337, caller_address=addresses[1].starknet_address
        )
        await erc_721.approve(
            addresses[3].address, 1340, caller_address=addresses[2].starknet_address
        )
        await erc_721.transferFrom(
            addresses[2].address,
            addresses[3].address,
            1337,
            caller_address=addresses[2].starknet_address,
        )

        approved = await erc_721.getApproved(1337)
        owner = await erc_721.ownerOf(1337)
        receiver_balance = await erc_721.balanceOf(addresses[3].address)
        sender_balance = await erc_721.balanceOf(addresses[2].address)

        assert approved == "0x" + 40 * "0"
        assert owner == addresses[3].address
        assert receiver_balance == 1
        assert sender_balance == 0
