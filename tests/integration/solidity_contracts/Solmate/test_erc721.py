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

    class TestOwnerOf:
        async def test_owner_of_should_fail_when_token_is_unminted(
            self, addresses, erc_721
        ):
            with pytest.raises(Exception) as e:
                await erc_721.ownerOf(1337)

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 147028384"

    # class TestBalanceOf:
    #     async def test_balance_of_should_fail_on_zero_address(self, addresses, erc_721):
    #         with pytest.raises(Exception) as e:
    #             await erc_721.balanceOf(zero_address)

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    # class TestMint:
    #     async def test_should_mint(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         balance = await erc_721.balanceOf(addresses[1].address)
    #         owner = await erc_721.ownerOf(1337)

    #         assert balance == 1
    #         assert owner == addresses[1].address

    #     async def test_should_fail_mint_to_zero_address(self, addresses, erc_721):
    #         with pytest.raises(Exception) as e:
    #             await erc_721.mint(
    #                 zero_address, 1337, caller_address=addresses[1].starknet_address
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_double_mint(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address,
    #             1337,
    #             caller_address=addresses[1].starknet_address,
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.mint(
    #                 addresses[1].address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    # class TestBurn:
    #     async def test_should_burn(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )
    #         await erc_721.burn(1337, caller_address=addresses[1].starknet_address)

    #         balance = await erc_721.balanceOf(addresses[1].address)

    #         assert balance == 0

    #         with pytest.raises(Exception) as e:
    #             await erc_721.ownerOf(1337)

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_burn_unminted(self, addresses, erc_721):
    #         with pytest.raises(Exception) as e:
    #             await erc_721.burn(1337, caller_address=addresses[1].starknet_address)

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_double_burn(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         await erc_721.burn(1337, caller_address=addresses[1].starknet_address)

    #         with pytest.raises(Exception) as e:
    #             await erc_721.burn(1337, caller_address=addresses[1].starknet_address)

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    # class TestAprrove:
    #     async def test_should_approve(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         await erc_721.approve(
    #             addresses[2].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         approved = await erc_721.getApproved(1337)
    #         assert approved == addresses[2].address

    #     async def test_should_approve_all(self, addresses, erc_721):
    #         await erc_721.setApprovalForAll(
    #             addresses[2].address, True, caller_address=addresses[1].starknet_address
    #         )

    #         is_approved_for_all = await erc_721.isApprovedForAll(
    #             addresses[1].address, addresses[2].address
    #         )

    #         assert is_approved_for_all == True

    #     async def test_should_fail_to_approve_unminted(self, addresses, erc_721):
    #         with pytest.raises(Exception) as e:
    #             await erc_721.approve(
    #                 addresses[2].address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_approve_unauthorized(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.approve(
    #                 addresses[2].address,
    #                 1337,
    #                 caller_address=addresses[3].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    # class TestTransferFrom:
    #     async def test_should_transfer_from(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[2].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         await erc_721.approve(
    #             addresses[1].address, 1337, caller_address=addresses[2].starknet_address
    #         )

    #         await erc_721.transferFrom(
    #             addresses[2].address,
    #             addresses[3].address,
    #             1337,
    #             caller_address=addresses[1].starknet_address,
    #         )

    #         approved = await erc_721.getApproved(1337)
    #         owner = await erc_721.ownerOf(1337)
    #         receiver_balance = await erc_721.balanceOf(addresses[3].address)
    #         sender_balance = await erc_721.balanceOf(addresses[2].address)

    #         assert approved == zero_address
    #         assert owner == addresses[3].address
    #         assert receiver_balance == 1
    #         assert sender_balance == 0

    #     async def test_should_transfer_from_self(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[0].address, 1337, caller_address=addresses[0].starknet_address
    #         )

    #         await erc_721.transferFrom(
    #             addresses[0].address,
    #             addresses[1].address,
    #             1337,
    #             caller_address=addresses[0].starknet_address,
    #         )

    #         approved = await erc_721.getApproved(1337)
    #         owner = await erc_721.ownerOf(1337)
    #         receiver_balance = await erc_721.balanceOf(addresses[1].address)
    #         sender_balance = await erc_721.balanceOf(addresses[0].address)

    #         assert approved == zero_address
    #         assert owner == addresses[1].address
    #         assert receiver_balance == 1
    #         assert sender_balance == 0

    #     async def test_should_transfer_from_approve_all(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         await erc_721.setApprovalForAll(
    #             addresses[3].address, True, caller_address=addresses[1].starknet_address
    #         )

    #         await erc_721.transferFrom(
    #             addresses[1].address,
    #             addresses[2].address,
    #             1337,
    #             caller_address=addresses[3].starknet_address,
    #         )

    #         approved = await erc_721.getApproved(1337)
    #         owner = await erc_721.ownerOf(1337)
    #         receiver_balance = await erc_721.balanceOf(addresses[2].address)
    #         sender_balance = await erc_721.balanceOf(addresses[1].address)

    #         assert approved == zero_address
    #         assert owner == addresses[2].address
    #         assert receiver_balance == 1
    #         assert sender_balance == 0

    #     async def test_should_fail_to_transfer_from_unowned(self, addresses, erc_721):
    #         with pytest.raises(Exception) as e:
    #             await erc_721.transferFrom(
    #                 addresses[1].address,
    #                 addresses[2].address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_transfer_from_wrong_from(
    #         self, addresses, erc_721
    #     ):
    #         await erc_721.mint(
    #             addresses[2].address, 1337, caller_address=addresses[2].starknet_address
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.transferFrom(
    #                 addresses[1].address,
    #                 addresses[3].address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_transfer_from_to_zero(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.transferFrom(
    #                 addresses[1].address,
    #                 zero_address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    #     async def test_should_fail_to_transfer_from_not_owner(self, addresses, erc_721):
    #         await erc_721.mint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.transferFrom(
    #                 addresses[1].address,
    #                 addresses[3].address,
    #                 1337,
    #                 caller_address=addresses[2].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 147028384"

    class TestSafeTransferFrom:
        async def test_should_safe_transfer_from_to_EOA(self, addresses, erc_721):
            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            await erc_721.setApprovalForAll(
                addresses[3].address, True, caller_address=addresses[1].starknet_address
            )

            await erc_721.safeTransferFrom(
                addresses[1].address,
                addresses[2].address,
                1337,
                caller_address=addresses[3].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(addresses[2].address)
            sender_balance = await erc_721.balanceOf(addresses[1].address)

            assert approved == zero_address
            assert owner == addresses[2].address
            assert receiver_balance == 1
            assert sender_balance == 0

        async def test_should_safe_transfer_from_to_ERC721Recipient(
            self, addresses, erc_721, erc_721_recipient
        ):
            recipient_address = erc_721_recipient.evm_contract_address

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            await erc_721.setApprovalForAll(
                addresses[2].address, True, caller_address=addresses[1].starknet_address
            )

            await erc_721.safeTransferFrom(
                addresses[1].address,
                recipient_address,
                1337,
                caller_address=addresses[2].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(recipient_address)
            sender_balance = await erc_721.balanceOf(addresses[1].address)

            assert approved == zero_address
            assert owner == recipient_address
            assert receiver_balance == 1
            assert sender_balance == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == addresses[2].address
            assert recipient_from == addresses[1].address
            assert recipient_token_id == 1337
            assert recipient_data == b""

        async def test_should_safe_transfer_from_to_ERC721Recipient_with_data(
            self, addresses, erc_721, erc_721_recipient
        ):
            recipient_address = erc_721_recipient.evm_contract_address

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            await erc_721.setApprovalForAll(
                addresses[2].address, True, caller_address=addresses[1].starknet_address
            )

            data = b"testing 123"

            await erc_721.safeTransferFrom2(
                addresses[1].address,
                recipient_address,
                1337,
                data,
                caller_address=addresses[2].starknet_address,
            )

            approved = await erc_721.getApproved(1337)
            owner = await erc_721.ownerOf(1337)
            receiver_balance = await erc_721.balanceOf(recipient_address)
            sender_balance = await erc_721.balanceOf(addresses[1].address)

            assert approved == zero_address
            assert owner == recipient_address
            assert receiver_balance == 1
            assert sender_balance == 0

            recipient_operator = await erc_721_recipient.operator()
            recipient_from = await erc_721_recipient.from_()
            recipient_token_id = await erc_721_recipient.id()
            recipient_data = await erc_721_recipient.data()

            assert recipient_operator == addresses[2].address
            assert recipient_from == addresses[1].address
            assert recipient_token_id == 1337
            assert recipient_data == data

        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient(
            self, addresses, erc_721, erc_721_nonrecipient
        ):
            recipient_address = erc_721_nonrecipient.evm_contract_address

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom(
                    addresses[1].address,
                    recipient_address,
                    1337,
                    caller_address=addresses[1].starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_NonERC721Recipient_with_data(
            self, addresses, erc_721, erc_721_nonrecipient
        ):
            recipient_address = erc_721_nonrecipient.evm_contract_address

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom2(
                    addresses[1].address,
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=addresses[2].starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 147028384"

        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient(
            self, addresses, erc_721, erc_721_reverting_recipient
        ):
            recipient_address = erc_721_reverting_recipient.evm_contract_address

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom(
                    addresses[1].address,
                    recipient_address,
                    1337,
                    caller_address=addresses[1].starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_RevertingERC721Recipient_with_data(
            self, addresses, erc_721, erc_721_reverting_recipient
        ):
            recipient_address = erc_721_reverting_recipient.evm_contract_address

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom2(
                    addresses[1].address,
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=addresses[1].starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 0"

        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData(
            self, addresses, erc_721, erc_721_recipient_with_wrong_return_data
        ):
            recipient_address = (
                erc_721_recipient_with_wrong_return_data.evm_contract_address
            )

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom(
                    addresses[1].address,
                    recipient_address,
                    1337,
                    caller_address=addresses[1].starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 3405692655"

        async def test_should_fail_to_safe_transfer_from_to_ERC721RecipientWithWrongReturnData_with_data(
            self, addresses, erc_721, erc_721_recipient_with_wrong_return_data
        ):
            recipient_address = (
                erc_721_recipient_with_wrong_return_data.evm_contract_address
            )

            await erc_721.mint(
                addresses[1].address, 1337, caller_address=addresses[1].starknet_address
            )

            with pytest.raises(Exception) as e:
                await erc_721.safeTransferFrom2(
                    addresses[1].address,
                    recipient_address,
                    1337,
                    b"testing 123",
                    caller_address=addresses[1].starknet_address,
                )

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: Reverted with reason: 3405692655"

    # class TestSafeMint:
    #     async def test_should_safe_mint_to_EOA(self, addresses, erc_721):
    #         await erc_721.safeMint(
    #             addresses[1].address, 1337, caller_address=addresses[1].starknet_address
    #         )

    #         balance = await erc_721.balanceOf(addresses[1].address)
    #         owner = await erc_721.ownerOf(1337)

    #         assert balance == 1
    #         assert owner == addresses[1].address

    #     async def test_should_safe_mint_to_ERC721Recipient(
    #         self, addresses, erc_721, erc_721_recipient
    #     ):
    #         recipient_address = erc_721_recipient.evm_contract_address

    #         await erc_721.safeMint(
    #             recipient_address, 1337, caller_address=addresses[0].starknet_address
    #         )

    #         balance = await erc_721.balanceOf(recipient_address)
    #         owner = await erc_721.ownerOf(1337)

    #         assert balance == 1
    #         assert owner == recipient_address

    #         recipient_operator = await erc_721_recipient.operator()
    #         recipient_from = await erc_721_recipient.from_()
    #         recipient_token_id = await erc_721_recipient.id()
    #         recipient_data = await erc_721_recipient.data()

    #         assert recipient_operator == addresses[0].address
    #         assert recipient_from == zero_address
    #         assert recipient_token_id == 1337
    #         assert recipient_data == b""

    #     async def test_should_safe_mint_to_ERC721Recipient_with_data(
    #         self, addresses, erc_721, erc_721_recipient
    #     ):
    #         recipient_address = erc_721_recipient.evm_contract_address
    #         data = b"testing 123"

    #         await erc_721.safeMint2(
    #             recipient_address,
    #             1337,
    #             data,
    #             caller_address=addresses[0].starknet_address,
    #         )

    #         balance = await erc_721.balanceOf(recipient_address)
    #         owner = await erc_721.ownerOf(1337)

    #         assert balance == 1
    #         assert owner == recipient_address

    #         recipient_operator = await erc_721_recipient.operator()
    #         recipient_from = await erc_721_recipient.from_()
    #         recipient_token_id = await erc_721_recipient.id()
    #         recipient_data = await erc_721_recipient.data()

    #         assert recipient_operator == addresses[0].address
    #         assert recipient_from == zero_address
    #         assert recipient_token_id == 1337
    #         assert recipient_data == data

    #     async def test_should_fail_to_safe_mint_to_NonERC721Recipient(
    #         self, addresses, erc_721, erc_721_nonrecipient
    #     ):
    #         recipient_address = erc_721_nonrecipient.evm_contract_address

    #         with pytest.raises(Exception) as e:
    #             await erc_721.safeMint(
    #                 recipient_address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 0"

    #     async def test_should_fail_to_safe_mint_to_NonERC721Recipient_with_data(
    #         self, addresses, erc_721, erc_721_nonrecipient
    #     ):
    #         recipient_address = erc_721_nonrecipient.evm_contract_address

    #         with pytest.raises(Exception) as e:
    #             await erc_721.safeMint2(
    #                 recipient_address,
    #                 1337,
    #                 b"testing 123",
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 0"

    #     async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient(
    #         self, addresses, erc_721, erc_721_reverting_recipient
    #     ):
    #         recipient_address = erc_721_reverting_recipient.evm_contract_address

    #         with pytest.raises(Exception) as e:
    #             await erc_721.safeMint(
    #                 recipient_address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 0"

    #     async def test_should_fail_to_safe_mint_to_RevertingERC721Recipient_with_data(
    #         self, addresses, erc_721, erc_721_reverting_recipient
    #     ):
    #         recipient_address = erc_721_reverting_recipient.evm_contract_address

    #         with pytest.raises(Exception) as e:
    #             await erc_721.safeMint2(
    #                 recipient_address,
    #                 1337,
    #                 b"testing 123",
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 0"

    #     async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData(
    #         self, addresses, erc_721, erc_721_recipient_with_wrong_return_data
    #     ):
    #         recipient_address = (
    #             erc_721_recipient_with_wrong_return_data.evm_contract_address
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.safeMint(
    #                 recipient_address,
    #                 1337,
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 3405692655"

    #     async def test_should_fail_to_safe_mint_to_ERC721RecipientWithWrongReturnData_with_data(
    #         self, addresses, erc_721, erc_721_recipient_with_wrong_return_data
    #     ):
    #         recipient_address = (
    #             erc_721_recipient_with_wrong_return_data.evm_contract_address
    #         )

    #         with pytest.raises(Exception) as e:
    #             await erc_721.safeMint2(
    #                 recipient_address,
    #                 1337,
    #                 b"testing 123",
    #                 caller_address=addresses[1].starknet_address,
    #             )

    #         message = re.search(r"Error message: (.*)", e.value.message)[1]
    #         assert message == "Kakarot: Reverted with reason: 0"
