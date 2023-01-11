import re

import pytest
import pytest_asyncio

from tests.integration.helpers.constants import MAX_INT, ZERO_ADDRESS


@pytest_asyncio.fixture(scope="module")
async def erc_721(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "MockERC721",
        "Kakarot NFT",
        "KKNFT",
        caller_address=owner.starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_recipient(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "ERC721Recipient",
        caller_address=owner.starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_reverting_recipient(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "RevertingERC721Recipient",
        caller_address=owner.starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_recipient_with_wrong_return_data(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "WrongReturnDataERC721Recipient",
        caller_address=owner.starknet_address,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_nonrecipient(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "NonERC721Recipient",
        caller_address=owner.starknet_address,
    )


@pytest.fixture(scope="module")
async def other(others):
    return others[0]


@pytest.mark.asyncio
@pytest.mark.SolmateERC721
@pytest.mark.usefixtures("starknet_snapshot")
class TestERC721:
    class TestMetadata:
        async def test_should_set_name_and_symbol(self, erc_721):
            name = await erc_721.name()
            assert name == "Kakarot NFT"
            symbol = await erc_721.symbol()
            assert symbol == "KKNFT"

    class TestOwnerOf:
        async def test_owner_of_should_fail_when_token_is_unminted(self, erc_721):
            with pytest.raises(Exception) as e:
                await erc_721.ownerOf(1337)
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

    class TestBalanceOf:
        async def test_balance_of_should_fail_on_zero_address(self, addresses, erc_721):
            with pytest.raises(Exception) as e:
                await erc_721.balanceOf(ZERO_ADDRESS)

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

    class TestMint:
        async def test_should_mint(self, erc_721, other):
            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )
            assert await erc_721.balanceOf(other.address) == 1
            assert await erc_721.ownerOf(1337) == other.address

        async def test_should_fail_mint_to_zero_address(self, erc_721, other):
            with pytest.raises(Exception) as e:
                await erc_721.mint(
                    ZERO_ADDRESS, 1337, caller_address=other.starknet_address
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_double_mint(self, erc_721, other):
            await erc_721.mint(
                other.address,
                1337,
                caller_address=other.starknet_address,
            )

            with pytest.raises(Exception) as e:
                await erc_721.mint(
                    other.address,
                    1337,
                    caller_address=other.starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

    class TestBurn:
        async def test_should_burn(self, erc_721, other):
            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )
            await erc_721.burn(1337, caller_address=other.starknet_address)

            assert await erc_721.balanceOf(other.address) == 0

            with pytest.raises(Exception) as e:
                await erc_721.ownerOf(1337)
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_burn_unminted(self, erc_721, other):
            with pytest.raises(Exception) as e:
                await erc_721.burn(1337, caller_address=other.starknet_address)
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_double_burn(self, erc_721, other):
            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )

            await erc_721.burn(1337, caller_address=other.starknet_address)

            with pytest.raises(Exception) as e:
                await erc_721.burn(1337, caller_address=other.starknet_address)
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

    class TestApprove:
        async def test_should_approve(self, erc_721, others):
            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )
            await erc_721.approve(
                others[1].address, 1337, caller_address=others[0].starknet_address
            )
            assert await erc_721.getApproved(1337) == others[1].address

        async def test_should_approve_all(self, erc_721, others):
            await erc_721.setApprovalForAll(
                others[1].address, True, caller_address=others[0].starknet_address
            )

            assert (
                await erc_721.isApprovedForAll(others[0].address, others[1].address)
                == True
            )

        async def test_should_fail_to_approve_unminted(self, erc_721, others):
            with pytest.raises(Exception) as e:
                await erc_721.approve(
                    others[1].address,
                    1337,
                    caller_address=others[0].starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_approve_unauthorized(self, erc_721, others):
            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )
            with pytest.raises(Exception) as e:
                await erc_721.approve(
                    others[1].address,
                    1337,
                    caller_address=others[2].starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

    class TestTransferFrom:
        async def test_should_transfer_from(self, erc_721, others):
            await erc_721.mint(
                others[1].address, 1337, caller_address=others[0].starknet_address
            )
            await erc_721.approve(
                others[2].address, 1337, caller_address=others[1].starknet_address
            )
            await erc_721.transferFrom(
                others[1].address,
                others[2].address,
                1337,
                caller_address=others[1].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(others[2].address)
            sender_balance = await erc_721.balanceOf(others[1].address)

            assert approved == ZERO_ADDRESS
            assert owner == others[2].address
            assert receiver_balance == 1
            assert sender_balance == 0

        async def test_should_transfer_from_self(self, erc_721, other, owner):
            await erc_721.mint(
                owner.address, 1337, caller_address=owner.starknet_address
            )
            await erc_721.transferFrom(
                owner.address,
                other.address,
                1337,
                caller_address=owner.starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(other.address)
            sender_balance = await erc_721.balanceOf(owner.address)

            assert approved == ZERO_ADDRESS
            assert owner == other.address
            assert receiver_balance == 1
            assert sender_balance == 0

        async def test_transfer_from_approve_all(self, erc_721, others):
            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_address=others[0].starknet_address
            )

            await erc_721.transferFrom(
                others[0].address,
                others[1].address,
                1337,
                caller_address=others[0].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(others[1].address)
            sender_balance = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert owner == others[1].address
            assert receiver_balance == 1
            assert sender_balance == 0

        async def test_should_fail_to_transfer_from_unowned(self, erc_721, others):
            with pytest.raises(Exception) as e:
                await erc_721.transferFrom(
                    others[0].address,
                    others[1].address,
                    1337,
                    caller_address=others[0].starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_transfer_from_wrong_from(self, erc_721, others):
            await erc_721.mint(
                others[1].address, 1337, caller_address=others[1].starknet_address
            )
            with pytest.raises(Exception) as e:
                await erc_721.transferFrom(
                    others[0].address,
                    others[2].address,
                    1337,
                    caller_address=others[0].starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_transfer_from_to_zero(self, erc_721, other):
            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )
            with pytest.raises(Exception) as e:
                await erc_721.transferFrom(
                    other.address,
                    ZERO_ADDRESS,
                    1337,
                    caller_address=other.starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_transfer_from_not_owner(self, erc_721, others):
            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )
            with pytest.raises(Exception) as e:
                await erc_721.transferFrom(
                    others[0].address,
                    others[2].address,
                    1337,
                    caller_address=others[1].starknet_address,
                )
            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 147028384"

    class TestSafeTransferFrom:
        async def test_should_safe_transfer_from_to_EOA(self, erc_721, others):
            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_address=others[0].starknet_address
            )

            await erc_721.safeTransferFrom(
                others[0].address,
                others[1].address,
                1337,
                caller_address=others[0].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(others[1].address)
            sender_balance = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert owner == others[1].address
            assert receiver_balance == 1
            assert sender_balance == 0

        async def test_should_safe_transfer_from_to_ERC721Recipient(
            self, erc_721, erc_721_recipient, others
        ):
            recipient_address = erc_721_recipient.evm_contract_address

            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_address=others[0].starknet_address
            )

            await erc_721.safeTransferFrom(
                others[0].address,
                recipient_address,
                1337,
                caller_address=others[1].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(recipient_address)
            sender_balance = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert owner == recipient_address
            assert receiver_balance == 1
            assert sender_balance == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == others[1].address
            assert recipient_from == others[0].address
            assert recipient_token_id == 1337
            assert recipient_data == b""

        async def test_should_safe_transfer_from_to_ERC721Recipient_with_data(
            self, erc_721, erc_721_recipient, others
        ):
            recipient_address = erc_721_recipient.evm_contract_address

            await erc_721.mint(
                others[0].address, 1337, caller_address=others[0].starknet_address
            )

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_address=others[0].starknet_address
            )

            data = b"testing 123"

            await erc_721.safeTransferFrom2(
                others[0].address,
                recipient_address,
                1337,
                data,
                caller_address=others[1].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(recipient_address)
            sender_balance = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert owner == recipient_address
            assert receiver_balance == 1
            assert sender_balance == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == others[1].address
            assert recipient_from == others[0].address
            assert recipient_token_id == 1337
            assert recipient_data == data

        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient(
            self, erc_721, erc_721_nonrecipient, other
        ):
            recipient_address = erc_721_nonrecipient.evm_contract_address

            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    1337,
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient_with_data(
            self, erc_721, erc_721_nonrecipient, other
        ):
            recipient_address = erc_721_nonrecipient.evm_contract_address

            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient(
            self, erc_721, erc_721_reverting_recipient, other
        ):
            recipient_address = erc_721_reverting_recipient.evm_contract_address

            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    1337,
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient_with_data(
            self, erc_721, erc_721_reverting_recipient, other
        ):
            recipient_address = erc_721_reverting_recipient.evm_contract_address

            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other
        ):
            recipient_address = (
                erc_721_recipient_with_wrong_return_data.evm_contract_address
            )

            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )
            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    1337,
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 3405692655"

        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData_with_data(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other
        ):
            recipient_address = (
                erc_721_recipient_with_wrong_return_data.evm_contract_address
            )

            await erc_721.mint(
                other.address, 1337, caller_address=other.starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 3405692655"

    class TestSafeMint:
        async def test_should_safe_mint_to_EOA(self, erc_721, other):
            await erc_721.safeMint(
                other.address, 1337, caller_address=other.starknet_address
            )

            balance = await erc_721.balanceOf(other.address)
            owner = await erc_721.ownerOf(1337)

            assert balance == 1
            assert owner == other.address

        async def test_should_safe_mint_to_ERC721Recipient(
            self, erc_721, erc_721_recipient, owner
        ):
            recipient_address = erc_721_recipient.evm_contract_address

            await erc_721.safeMint(
                recipient_address, 1337, caller_address=owner.starknet_address
            )

            balance = await erc_721.balanceOf(recipient_address)
            nft_owner = await erc_721.ownerOf(1337)

            assert balance == 1
            assert ft_owner == recipient_address

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == owner.address
            assert recipient_from == ZERO_ADDRESS
            assert recipient_data == b""

        async def test_should_safe_mint_to_ERC721Recipient_with_data(
            self, erc_721, erc_721_recipient, owner
        ):
            recipient_address = erc_721_recipient.evm_contract_address
            data = b"testing 123"

            await erc_721.safeMint2(
                recipient_address,
                1337,
                data,
                caller_address=owner.starknet_address,
            )

            balance = await erc_721.balanceOf(recipient_address)
            nft_owner = await erc_721.ownerOf(1337)

            assert balance == 1
            assert nft_owner == recipient_address

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == owner.address
            assert recipient_from == ZERO_ADDRESS
            assert recipient_token_id == 1337
            assert recipient_data == data

        async def test_should_fail_to_safe_mint_to_NonERC721Recipient(
            self, erc_721, erc_721_nonrecipient, other
        ):
            recipient_address = erc_721_nonrecipient.evm_contract_address

            with pytest.raises(Exception) as e:
                await erc_721.safeMint(
                    recipient_address,
                    1337,
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_mint_to_NonERC721Recipient_with_data(
            self, erc_721, erc_721_nonrecipient, other
        ):
            recipient_address = erc_721_nonrecipient.evm_contract_address

            with pytest.raises(Exception) as e:
                await erc_721.safeMint2(
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient(
            self, erc_721, erc_721_reverting_recipient, other
        ):
            recipient_address = erc_721_reverting_recipient.evm_contract_address

            with pytest.raises(Exception) as e:
                await erc_721.safeMint(
                    recipient_address,
                    1337,
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient_with_data(
            self, erc_721, erc_721_reverting_recipient, other
        ):
            recipient_address = erc_721_reverting_recipient.evm_contract_address

            with pytest.raises(Exception) as e:
                await erc_721.safeMint2(
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other
        ):
            recipient_address = (
                erc_721_recipient_with_wrong_return_data.evm_contract_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeMint(
                    recipient_address,
                    1337,
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 3405692655"

        async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData_with_data(
            self, addresses, erc_721, erc_721_recipient_with_wrong_return_data, other
        ):
            recipient_address = (
                erc_721_recipient_with_wrong_return_data.evm_contract_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeMint2(
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=other.starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            # TODO: update with https://github.com/sayajin-labs/kakarot/issues/416
            assert message == "Kakarot: Reverted with reason: 0"
