from textwrap import wrap

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy


@pytest_asyncio.fixture(scope="package")
async def p256_verify_invoker(new_eoa):
    deployer = await new_eoa(0.1)
    return await deploy(
        "RIP7212",
        "RIP7212Invoker",
        caller_eoa=deployer.starknet_contract,
    )


@pytest.mark.asyncio(scope="package")
@pytest.mark.RIP7212
class TestRIP7212:
    class TestRIP7212Integration:
        async def test_should_verify_secp256r1_signature(
            self, p256_verify_invoker, owner
        ):

            # input data from <https://github.com/ulerdogan/go-ethereum/blob/75062a6998e4e3fbb4cdb623b8b02e79e7b8f965/core/vm/contracts_test.go#L401-L410>
            input_data = (
                "4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d"
                "a73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac"
                "36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60"
                "4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3"
                "7618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
            )
            msg_hash, r_, s_, x_, y_ = ["0x" + word for word in wrap(input_data, 64)]
            is_valid = await p256_verify_invoker.p256verify(
                msg_hash,
                r_,
                s_,
                x_,
                y_,
                caller_eoa=owner.starknet_contract,
            )
            assert is_valid
