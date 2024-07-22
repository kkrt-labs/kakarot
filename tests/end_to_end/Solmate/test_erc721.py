import pytest
import pytest_asyncio
from eth_utils import keccak

from kakarot_scripts.utils.kakarot import deploy
from tests.utils.constants import ZERO_ADDRESS
from tests.utils.errors import evm_error


@pytest_asyncio.fixture(scope="module")
async def erc_721(owner):
    return await deploy(
        "Solmate",
        "MockERC721",
        "Kakarot NFT",
        "KKNFT",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_recipient(owner):
    return await deploy(
        "Solmate",
        "ERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_reverting_recipient(owner):
    return await deploy(
        "Solmate",
        "RevertingERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_recipient_with_wrong_return_data(owner):
    return await deploy(
        "Solmate",
        "WrongReturnDataERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture(scope="module")
async def erc_721_non_recipient(owner):
    return await deploy(
        "Solmate",
        "NonERC721Recipient",
        caller_eoa=owner.starknet_contract,
    )


@pytest.fixture
def token_id(request):
    """
    Generate a random unique token_id for a given test function.
    """
    return abs(hash(request.function.__name__))


@pytest.mark.asyncio(scope="session")
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
            with evm_error():
                await erc_721.ownerOf(token_id)

    class TestBalanceOf:
        async def test_balance_of_should_fail_on_zero_address(self, erc_721):
            with evm_error():
                await erc_721.balanceOf(ZERO_ADDRESS)

    class TestMint:
        async def test_should_mint(self, erc_721, other, token_id):
            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )
            assert await erc_721.balanceOf(other.address) == 1
            assert await erc_721.ownerOf(token_id) == other.address

        async def test_should_fail_mint_to_zero_address(self, erc_721, other, token_id):
            with evm_error("INVALID_RECIPIENT"):
                await erc_721.mint(
                    ZERO_ADDRESS, token_id, caller_eoa=other.starknet_contract
                )

        async def test_should_fail_to_double_mint(self, erc_721, other, token_id):
            await erc_721.mint(
                other.address,
                token_id,
                caller_eoa=other.starknet_contract,
            )

            with evm_error("ALREADY_MINTED"):
                await erc_721.mint(
                    other.address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

    class TestBurn:
        async def test_should_burn(self, erc_721, other, token_id):
            balance_before = await erc_721.balanceOf(other.address)

            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )
            await erc_721.burn(token_id, caller_eoa=other.starknet_contract)

            balance_after = await erc_721.balanceOf(other.address)
            assert balance_after == balance_before

            with evm_error():
                await erc_721.ownerOf(token_id)

        async def test_should_fail_to_burn_unminted(self, erc_721, other, token_id):
            with evm_error("NOT_MINTED"):
                await erc_721.burn(token_id, caller_eoa=other.starknet_contract)

        async def test_should_fail_to_double_burn(self, erc_721, other, token_id):
            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )

            await erc_721.burn(token_id, caller_eoa=other.starknet_contract)

            with evm_error("NOT_MINTED"):
                await erc_721.burn(token_id, caller_eoa=other.starknet_contract)

    class TestApprove:
        async def test_should_approve(self, erc_721, from_wallet, to_wallet, token_id):
            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )
            await erc_721.approve(
                to_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )
            assert await erc_721.getApproved(token_id) == to_wallet.address

        async def test_should_approve_all(self, erc_721, from_wallet, to_wallet):
            await erc_721.setApprovalForAll(
                to_wallet.address, True, caller_eoa=from_wallet.starknet_contract
            )

            assert (
                await erc_721.isApprovedForAll(from_wallet.address, to_wallet.address)
                is True
            )

        async def test_should_fail_to_approve_unminted(
            self, erc_721, from_wallet, to_wallet, token_id
        ):
            with evm_error("NOT_AUTHORIZED"):
                await erc_721.approve(
                    to_wallet.address,
                    token_id,
                    caller_eoa=from_wallet.starknet_contract,
                )

        async def test_should_fail_to_approve_unauthorized(
            self, erc_721, other, from_wallet, to_wallet, token_id
        ):
            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )
            with evm_error("NOT_AUTHORIZED"):
                await erc_721.approve(
                    to_wallet.address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

    class TestTransferFrom:
        async def test_should_transfer_from(
            self, erc_721, other, from_wallet, to_wallet, token_id
        ):
            await erc_721.mint(
                to_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )
            await erc_721.approve(
                other.address, token_id, caller_eoa=to_wallet.starknet_contract
            )
            receiver_balance_prev = await erc_721.balanceOf(other.address)
            sender_balance_prev = await erc_721.balanceOf(to_wallet.address)
            await erc_721.transferFrom(
                to_wallet.address,
                other.address,
                token_id,
                caller_eoa=other.starknet_contract,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)
            receiver_balance = await erc_721.balanceOf(other.address)
            sender_balance = await erc_721.balanceOf(to_wallet.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == other.address
            assert receiver_balance - receiver_balance_prev == 1
            assert sender_balance - sender_balance_prev == -1

        async def test_should_transfer_from_self(self, erc_721, other, owner, token_id):
            receiver_balance_before = await erc_721.balanceOf(other.address)
            sender_balance_before = await erc_721.balanceOf(owner.address)

            await erc_721.mint(
                owner.address, token_id, caller_eoa=owner.starknet_contract
            )
            await erc_721.transferFrom(
                owner.address,
                other.address,
                token_id,
                caller_eoa=owner.starknet_contract,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)
            receiver_balance_after = await erc_721.balanceOf(other.address)
            sender_balance_after = await erc_721.balanceOf(owner.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == other.address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after == sender_balance_before

        async def test_transfer_from_approve_all(
            self, erc_721, from_wallet, to_wallet, token_id
        ):
            receiver_balance_before = await erc_721.balanceOf(to_wallet.address)
            sender_balance_before = await erc_721.balanceOf(from_wallet.address)

            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.setApprovalForAll(
                to_wallet.address, True, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.transferFrom(
                from_wallet.address,
                to_wallet.address,
                token_id,
                caller_eoa=from_wallet.starknet_contract,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)

            receiver_balance_after = await erc_721.balanceOf(to_wallet.address)
            sender_balance_after = await erc_721.balanceOf(from_wallet.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == to_wallet.address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after == sender_balance_before

        async def test_should_fail_to_transfer_from_unowned(
            self, erc_721, from_wallet, to_wallet, token_id
        ):
            with evm_error():
                await erc_721.transferFrom(
                    from_wallet.address,
                    to_wallet.address,
                    token_id,
                    caller_eoa=from_wallet.starknet_contract,
                )

        async def test_should_fail_to_transfer_from_wrong_from(
            self, erc_721, from_wallet, to_wallet, other, token_id
        ):
            await erc_721.mint(
                to_wallet.address, token_id, caller_eoa=to_wallet.starknet_contract
            )
            with evm_error():
                await erc_721.transferFrom(
                    from_wallet.address,
                    other.address,
                    token_id,
                    caller_eoa=from_wallet.starknet_contract,
                )

        async def test_should_fail_to_transfer_from_to_zero(
            self, erc_721, other, token_id
        ):
            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )
            with evm_error("INVALID_RECIPIENT"):
                await erc_721.transferFrom(
                    other.address,
                    ZERO_ADDRESS,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_transfer_from_not_owner(
            self, erc_721, from_wallet, to_wallet, other, token_id
        ):
            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )
            await erc_721.setApprovalForAll(
                to_wallet.address, False, caller_eoa=from_wallet.starknet_contract
            )
            with evm_error("NOT_AUTHORIZED"):
                await erc_721.transferFrom(
                    from_wallet.address,
                    other.address,
                    token_id,
                    caller_eoa=to_wallet.starknet_contract,
                )

    class TestSafeTransferFrom:
        async def test_should_safe_transfer_from_to_EOA(
            self, erc_721, from_wallet, to_wallet, token_id
        ):
            receiver_balance_before = await erc_721.balanceOf(to_wallet.address)
            sender_balance_before = await erc_721.balanceOf(from_wallet.address)

            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.setApprovalForAll(
                to_wallet.address, True, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.safeTransferFrom(
                from_wallet.address,
                to_wallet.address,
                token_id,
                caller_eoa=from_wallet.starknet_contract,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)
            receiver_balance_after = await erc_721.balanceOf(to_wallet.address)
            sender_balance_after = await erc_721.balanceOf(from_wallet.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == to_wallet.address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after - sender_balance_before == 0

        async def test_should_safe_transfer_from_to_ERC721Recipient(
            self, erc_721, erc_721_recipient, from_wallet, to_wallet, token_id
        ):
            recipient_address = erc_721_recipient.address

            receiver_balance_before = await erc_721.balanceOf(recipient_address)
            sender_balance_before = await erc_721.balanceOf(from_wallet.address)

            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.setApprovalForAll(
                to_wallet.address, True, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.safeTransferFrom(
                from_wallet.address,
                recipient_address,
                token_id,
                caller_eoa=to_wallet.starknet_contract,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)

            receiver_balance_after = await erc_721.balanceOf(recipient_address)
            sender_balance_after = await erc_721.balanceOf(from_wallet.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == recipient_address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after - sender_balance_before == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == to_wallet.address
            assert recipient_from == from_wallet.address
            assert recipient_token_id == token_id
            assert recipient_data == b""

        async def test_should_safe_transfer_from_to_ERC721Recipient_with_data(
            self, erc_721, erc_721_recipient, from_wallet, to_wallet, token_id
        ):
            recipient_address = erc_721_recipient.address

            receiver_balance_before = await erc_721.balanceOf(recipient_address)
            sender_balance_before = await erc_721.balanceOf(from_wallet.address)

            await erc_721.mint(
                from_wallet.address, token_id, caller_eoa=from_wallet.starknet_contract
            )

            await erc_721.setApprovalForAll(
                to_wallet.address, True, caller_eoa=from_wallet.starknet_contract
            )

            data = b"testing 123"

            await erc_721.safeTransferFrom2(
                from_wallet.address,
                recipient_address,
                token_id,
                data,
                caller_eoa=to_wallet.starknet_contract,
            )

            approved = await erc_721.getApproved(token_id)
            nft_owner = await erc_721.ownerOf(token_id)

            receiver_balance_after = await erc_721.balanceOf(recipient_address)
            sender_balance_after = await erc_721.balanceOf(from_wallet.address)

            await erc_721.balanceOf(recipient_address)
            await erc_721.balanceOf(from_wallet.address)

            assert approved == ZERO_ADDRESS
            assert nft_owner == recipient_address
            assert receiver_balance_after - receiver_balance_before == 1
            assert sender_balance_after - sender_balance_before == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == to_wallet.address
            assert recipient_from == from_wallet.address
            assert recipient_token_id == token_id
            assert recipient_data == data

        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )

            with evm_error():
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient_with_data(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )

            with evm_error():
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address
            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )

            selector = keccak(text="onERC721Received(address,address,uint256,bytes)")[
                :4
            ]
            with evm_error(selector):
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient_with_data(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address

            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )
            selector = keccak(text="onERC721Received(address,address,uint256,bytes)")[
                :4
            ]
            with evm_error(selector):
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )
            with evm_error("UNSAFE_RECIPIENT"):
                await erc_721.safeTransferFrom(
                    other.address,
                    recipient_address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData_with_data(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            await erc_721.mint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )

            with evm_error("UNSAFE_RECIPIENT"):
                await erc_721.safeTransferFrom2(
                    other.address,
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other.starknet_contract,
                )

    class TestSafeMint:
        async def test_should_safe_mint_to_EOA(self, erc_721, other, token_id):
            balance_before = await erc_721.balanceOf(other.address)

            await erc_721.safeMint(
                other.address, token_id, caller_eoa=other.starknet_contract
            )

            balance_after = await erc_721.balanceOf(other.address)
            nft_owner = await erc_721.ownerOf(token_id)

            assert balance_after - balance_before == 1
            assert nft_owner == other.address

        async def test_should_safe_mint_to_ERC721Recipient(
            self, erc_721, erc_721_recipient, owner, token_id
        ):
            recipient_address = erc_721_recipient.address

            balance_before = await erc_721.balanceOf(recipient_address)
            await erc_721.safeMint(
                recipient_address, token_id, caller_eoa=owner.starknet_contract
            )

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
                caller_eoa=owner.starknet_contract,
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

        async def test_should_fail_to_safe_mint_to_NonERC721Recipient(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            with evm_error():
                await erc_721.safeMint(
                    recipient_address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_mint_to_NonERC721Recipient_with_data(
            self, erc_721, erc_721_non_recipient, other, token_id
        ):
            recipient_address = erc_721_non_recipient.address

            with evm_error():
                await erc_721.safeMint2(
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address

            with evm_error():
                await erc_721.safeMint(
                    recipient_address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient_with_data(
            self, erc_721, erc_721_reverting_recipient, other, token_id
        ):
            recipient_address = erc_721_reverting_recipient.address

            with evm_error():
                await erc_721.safeMint2(
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            with evm_error():
                await erc_721.safeMint(
                    recipient_address,
                    token_id,
                    caller_eoa=other.starknet_contract,
                )

        async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData_with_data(
            self, erc_721, erc_721_recipient_with_wrong_return_data, other, token_id
        ):
            recipient_address = erc_721_recipient_with_wrong_return_data.address

            with evm_error():
                await erc_721.safeMint2(
                    recipient_address,
                    token_id,
                    b"testing 123",
                    caller_eoa=other.starknet_contract,
                )
