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
        call_address = addresses[1]["int"]
        address = addresses[1]["hex"]
        await erc_721.mint(address, 1337, caller_address=call_address)
        balance = await erc_721.balanceOf(address)
        owner = await erc_721.ownerOf(1337)

        assert balance == 1
        assert owner == address

    async def test_should_burn(self, addresses, kakarot_snapshot, erc_721):
        call_address = addresses[1]["int"]
        address = addresses[1]["hex"]
        await erc_721.mint(address, 1337, caller_address=call_address)

        await erc_721.burn(1337, caller_address=call_address)
        balance = await erc_721.balanceOf(address)

        assert balance == 0

    async def test_should_approve(self, addresses, kakarot_snapshot, erc_721):
        await erc_721.mint(
            addresses[1]["hex"], 1339, caller_address=addresses[1]["int"]
        )
        await erc_721.approve(
            addresses[2]["hex"], 1339, caller_address=addresses[1]["int"]
        )
        approved = await erc_721.getApproved(1339)

        assert approved == addresses[2]["hex"]

    async def test_should_approve_all(self, addresses, kakarot_snapshot, erc_721):
        await erc_721.setApprovalForAll(
            addresses[1]["hex"], True, caller_address=addresses[0]["int"]
        )

        is_approved_for_all = await erc_721.isApprovedForAll(
            addresses[0]["hex"], addresses[1]["hex"]
        )

        assert is_approved_for_all == True

    async def test_should_transfer_from(self, addresses, kakarot_snapshot, erc_721):
        await erc_721.mint(
            addresses[2]["hex"], 1340, caller_address=addresses[1]["int"]
        )
        await erc_721.approve(
            addresses[3]["hex"], 1340, caller_address=addresses[2]["int"]
        )
        await erc_721.transferFrom(
            addresses[2]["hex"],
            addresses[3]["hex"],
            1340,
            caller_address=addresses[2]["int"],
        )

        approved = await erc_721.getApproved(1340)
        owner = await erc_721.ownerOf(1340)
        receiver_balance = await erc_721.balanceOf(addresses[3]["hex"])
        sender_balance = await erc_721.balanceOf(addresses[2]["hex"])

        assert approved == "0x" + 40 * "0"
        assert owner == addresses[3]["hex"]
        assert receiver_balance == 1
        assert sender_balance == 0

    async def test_should_transfer_from_self(
        self, addresses, kakarot_snapshot, erc_721
    ):
        await erc_721.mint(
            addresses[1]["hex"], 1337, caller_address=addresses[2]["int"]
        )
        await erc_721.transferFrom(
            addresses[1]["hex"],
            addresses[2]["hex"],
            1337,
            caller_address=addresses[1]["int"],
        )

        approved = await erc_721.getApproved(1337)
        owner = await erc_721.ownerOf(1337)
        receiver_balance = await erc_721.balanceOf(addresses[2]["hex"])
        sender_balance = await erc_721.balanceOf(addresses[1]["hex"])

        assert approved == "0x" + 40 * "0"
        assert owner == addresses[2]["hex"]
        assert receiver_balance == 1
        assert sender_balance == 0

    async def test_transfer_from_approve_all(
        self, addresses, kakarot_snapshot, erc_721
    ):
        await erc_721.mint(
            addresses[2]["hex"], 1342, caller_address=addresses[2]["int"]
        )

        await erc_721.setApprovalForAll(
            addresses[3]["hex"], True, caller_address=addresses[2]["int"]
        )

        await erc_721.transferFrom(
            addresses[2]["hex"],
            addresses[3]["hex"],
            1342,
            caller_address=addresses[2]["int"],
        )

        approved = await erc_721.getApproved(1342)
        owner = await erc_721.ownerOf(1342)
        receiver_balance = await erc_721.balanceOf(addresses[3]["hex"])
        sender_balance = await erc_721.balanceOf(addresses[2]["hex"])

        assert approved == "0x" + 40 * "0"
        assert owner == addresses[3]["hex"]
        assert receiver_balance == 1
        assert sender_balance == 0
