import os

import pytest
import pytest_asyncio
from eth_utils import keccak

from tests.utils.constants import ZERO_ADDRESS
from tests.utils.errors import kakarot_error


@pytest_asyncio.fixture(scope="module")
async def erc_721(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "MockERC721",
        "Kakarot NFT",
        "KKNFT",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_recipient(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "ERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_reverting_recipient(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "RevertingERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_recipient_with_wrong_return_data(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "WrongReturnDataERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_non_recipient(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "Solmate",
        "NonERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest.fixture
def token_id(request):
    """
    A fixture to generate a random unique token_id for a given test function
    """
    return abs(hash(request.function.__name__))


@pytest.mark.asyncio
@pytest.mark.SolmateERC721
class TestERC721:
    class TestMetadata:
        async def test_should_set_name_and_symbol(self, erc_721):
            assert await erc_721.name() == "Kakarot NFT"
            assert await erc_721.symbol() == "KKNFT"

    class TestOwnerOf:
        async def test_owner_of_should_fail_when_token_does_not_exist(
            self, erc_721, token_id
        ):
            with kakarot_error():
                await erc_721.ownerOf(token_id)

    class TestBalanceOf:
        async def test_balance_of_should_fail_on_zero_address(self, erc_721):
            with kakarot_error():
                await erc_721.balanceOf(ZERO_ADDRESS)

    class TestMint:
        async def test_should_mint(self, erc_721, other, token_id):
            await erc_721.mint(other.address, token_id, caller_eoa=other)
            assert await erc_721.balanceOf(other.address) == 1
            assert await erc_721.ownerOf(token_id) == other.address

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_mint_to_zero_address(self, erc_721, other, token_id):
            with kakarot_error("INVALID_RECIPIENT"):
                await erc_721.mint(ZERO_ADDRESS, token_id, caller_eoa=other)

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_double_mint(self, erc_721, other, token_id):
            await erc_721.mint(
                other.address,
                token_id,
                caller_eoa=other,
            )

            with kakarot_error("ALREADY_MINTED"):
                await erc_721.mint(
                    other.address,
                    token_id,
                    caller_eoa=other,
                )

    class TestBurn:
        async def test_should_burn(self, erc_721, other, token_id):
            balance_before = await erc_721.balanceOf(other.address)

            await erc_721.mint(other.address, token_id, caller_eoa=other)
            await erc_721.burn(token_id, caller_eoa=other)

            balance_after = await erc_721.balanceOf(other.address)
            assert balance_after == balance_before

            with kakarot_error():
                await erc_721.ownerOf(token_id)

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_burn_unminted(self, erc_721, other, token_id):
            with kakarot_error("NOT_MINTED"):
                await erc_721.burn(token_id, caller_eoa=other)

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_double_burn(self, erc_721, other, token_id):
            await erc_721.mint(other.address, token_id, caller_eoa=other)

            await erc_721.burn(token_id, caller_eoa=other)

            with kakarot_error("NOT_MINTED"):
                await erc_721.burn(token_id, caller_eoa=other)

    class TestApprove:
        async def test_should_approve(self, erc_721, others, token_id):
            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])
            await erc_721.approve(others[1].address, token_id, caller_eoa=others[0])
            assert await erc_721.getApproved(token_id) == others[1].address

        async def test_should_approve_all(self, erc_721, others):
            await erc_721.setApprovalForAll(
                others[1].address, True, caller_eoa=others[0]
            )

            assert (
                await erc_721.isApprovedForAll(others[0].address, others[1].address)
                == True
            )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_approve_unminted(self, erc_721, others, token_id):
            with kakarot_error("NOT_AUTHORIZED"):
                await erc_721.approve(
                    others[1].address,
                    token_id,
                    caller_eoa=others[0],
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_approve_unauthorized(
            self, erc_721, others, token_id
        ):
            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])
            with kakarot_error("NOT_AUTHORIZED"):
                await erc_721.approve(
                    others[1].address,
                    token_id,
                    caller_eoa=others[2],
                )

    class TestTransferFrom:
        async def test_should_transfer_from(self, erc_721, others, token_id):
            await erc_721.mint(others[1].address, token_id, caller_eoa=others[0])
            await erc_721.approve(others[2].address, token_id, caller_eoa=others[1])
            await erc_721.transferFrom(
                others[1].address,
                others[2].address,
                token_id,
                caller_eoa=others[1],
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)
            receiver_balance = await erc_721.balanceOf(others[2].address)
            sender_balance = await erc_721.balanceOf(others[1].address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == others[2].address
            assert receiver_balance == 1
            assert sender_balance == 0

        async def test_should_transfer_from_self(self, erc_721, other, owner, token_id):
            receiver_balance_before = await erc_721.balanceOf(other.address)
            sender_balance_before = await erc_721.balanceOf(owner.address)

            await erc_721.mint(owner.address, token_id, caller_eoa=owner)
            await erc_721.transferFrom(
                owner.address,
                other.address,
                token_id,
                caller_eoa=owner,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)
            receiver_balance_after = await erc_721.balanceOf(other.address)
            sender_balance_after = await erc_721.balanceOf(owner.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == other.address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after == sender_balance_before

        async def test_transfer_from_approve_all(self, erc_721, others, token_id):
            receiver_balance_before = await erc_721.balanceOf(others[1].address)
            sender_balance_before = await erc_721.balanceOf(others[0].address)

            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_eoa=others[0]
            )

            await erc_721.transferFrom(
                others[0].address,
                others[1].address,
                token_id,
                caller_eoa=others[0],
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)

            receiver_balance_after = await erc_721.balanceOf(others[1].address)
            sender_balance_after = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == others[1].address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after == sender_balance_before

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_transfer_from_unowned(
            self, erc_721, others, token_id
        ):
            with kakarot_error():
                await erc_721.transferFrom(
                    others[0].address,
                    others[1].address,
                    token_id,
                    caller_eoa=others[0],
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_transfer_from_wrong_from(
            self, erc_721, others, token_id
        ):
            await erc_721.mint(others[1].address, token_id, caller_eoa=others[1])
            with kakarot_error():
                await erc_721.transferFrom(
                    others[0].address,
                    others[2].address,
                    token_id,
                    caller_eoa=others[0],
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_transfer_from_to_zero(
            self, erc_721, other, token_id
        ):
            await erc_721.mint(other.address, token_id, caller_eoa=other)
            with kakarot_error("INVALID_RECIPIENT"):
                await erc_721.transferFrom(
                    other.address,
                    ZERO_ADDRESS,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_transfer_from_not_owner(
            self, erc_721, others, token_id
        ):
            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])
            with kakarot_error("NOT_AUTHORIZED"):
                await erc_721.transferFrom(
                    others[0].address,
                    others[2].address,
                    token_id,
                    caller_eoa=others[1],
                )

    class TestSafeTransferFrom:
        async def test_should_safe_transfer_from_to_EOA(
            self, erc_721, others, token_id
        ):
            receiver_balance_before = await erc_721.balanceOf(others[1].address)
            sender_balance_before = await erc_721.balanceOf(others[0].address)

            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_eoa=others[0]
            )

            await erc_721.safeTransferFrom(
                others[0].address,
                others[1].address,
                token_id,
                caller_eoa=others[0],
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)
            receiver_balance_after = await erc_721.balanceOf(others[1].address)
            sender_balance_after = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == others[1].address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after - sender_balance_before == 0

        async def test_should_safe_transfer_from_to_ERC721Recipient(
            self, erc_721, erc_721_recipient, others, token_id
        ):
            recipient_address = erc_721_recipient.address

            receiver_balance_before = await erc_721.balanceOf(recipient_address)
            sender_balance_before = await erc_721.balanceOf(others[0].address)

            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_eoa=others[0]
            )

            await erc_721.safeTransferFrom(
                others[0].address,
                recipient_address,
                token_id,
                caller_eoa=others[1],
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)

            receiver_balance_after = await erc_721.balanceOf(recipient_address)
            sender_balance_after = await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == recipient_address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after - sender_balance_before == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == others[1].address
            assert recipient_from == others[0].address
            assert recipient_token_id == token_id
            assert recipient_data == b""

        async def test_should_safe_transfer_from_to_ERC721Recipient_with_data(
            self, erc_721, erc_721_recipient, others, token_id
        ):
            recipient_address = erc_721_recipient.address

            receiver_balance_before = await erc_721.balanceOf(recipient_address)
            sender_balance_before = await erc_721.balanceOf(others[0].address)

            await erc_721.mint(others[0].address, token_id, caller_eoa=others[0])

            await erc_721.setApprovalForAll(
                others[1].address, True, caller_eoa=others[0]
            )

            data = b"testing 123"

            await erc_721.safeTransferFrom2(
                others[0].address,
                recipient_address,
                token_id,
                data,
                caller_eoa=others[1],
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)

            receiver_balance_after = await erc_721.balanceOf(recipient_address)
            sender_balance_after = await erc_721.balanceOf(others[0].address)

            await erc_721.balanceOf(recipient_address)
            await erc_721.balanceOf(others[0].address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == recipient_address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after - sender_balance_before == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == others[1].address
            assert recipient_from == others[0].address
            assert recipient_token_id == token_id
            assert recipient_data == data

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            await erc_721.mint(other.address, token_id, caller_eoa=other)

            with kakarot_error():
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient_with_data(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            await erc_721.mint(other.address, token_id, caller_eoa=other)

            with kakarot_error():
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address
            await erc_721.mint(other.address, token_id, caller_eoa=other)

            selector = keccak(text="onERC721Received(address,address,uint256,bytes)")[
                :4
            ]
            with kakarot_error(selector):
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient_with_data(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address

            await erc_721.mint(other.address, token_id, caller_eoa=other)
            selector = keccak(text="onERC721Received(address,address,uint256,bytes)")[
                :4
            ]
            with kakarot_error(selector):
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            await erc_721.mint(other.address, token_id, caller_eoa=other)
            with kakarot_error("UNSAFE_RECIPIENT"):
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData_with_data(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            await erc_721.mint(other.address, token_id, caller_eoa=other)

            with kakarot_error("UNSAFE_RECIPIENT"):
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other,
                )

    class TestSafeMint:
        async def test_should_safe_mint_to_EOA(self, erc_721, other, token_id):
            balance_before = await erc_721.balanceOf(other.address)

            await erc_721.safeMint(other.address, token_id, caller_eoa=other)

            balance_after = await erc_721.balanceOf(other.address)
            nft_owner = await erc_721.ownerOf(token_id)

            assert balance_after - balance_before == 1
            assert nft_owner == other.address

        async def test_should_safe_mint_to_ERC721Recipient(
            self, erc_721, erc_721_recipient, owner, token_id
        ):
            recipient_address = erc_721_recipient.address

            balance_before = await erc_721.balanceOf(recipient_address)
            await erc_721.safeMint(recipient_address, token_id, caller_eoa=owner)

            balance_after = await erc_721.balanceOf(recipient_address)
            nft_owner = await erc_721.ownerOf(token_id)

            assert balance_after - balance_before == 1
            assert nft_owner == recipient_address

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == owner.address
            assert recipient_from == ZERO_ADDRESS
            assert recipient_id == token_id
            assert recipient_data == b""

        async def test_should_safe_mint_to_ERC721Recipient_with_data(
            self, erc_721, erc_721_recipient, owner, token_id
        ):
            recipient_address = erc_721_recipient.address
            data = b"testing 123"

            balance_before = await erc_721.balanceOf(recipient_address)
            await erc_721.safeMint2(
                recipient_address,
                token_id,
                data,
                caller_eoa=owner,
            )

            balance_after = await erc_721.balanceOf(recipient_address)
            nft_owner = await erc_721.ownerOf(token_id)

            assert balance_after - balance_before == 1
            assert nft_owner == recipient_address

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == owner.address
            assert recipient_from == ZERO_ADDRESS
            assert recipient_token_id == token_id
            assert recipient_data == data

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_mint_to_NonERC721Recipient(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            with kakarot_error():
                await erc_721.safeMint(
                    recipient_address,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_mint_to_NonERC721Recipient_with_data(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            with kakarot_error():
                await erc_721.safeMint2(
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address

            with kakarot_error():
                await erc_721.safeMint(
                    recipient_address,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient_with_data(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address

            with kakarot_error():
                await erc_721.safeMint2(
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            with kakarot_error():
                await erc_721.safeMint(
                    recipient_address,
                    token_id,
                    caller_eoa=other,
                )

        @pytest.mark.xfail(
            os.environ.get("STARKNET_NETWORK", "katana") == "katana",
            reason="https://github.com/dojoengine/dojo/issues/864",
        )
        async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData_with_data(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            with kakarot_error():
                await erc_721.safeMint2(
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other,
                )
