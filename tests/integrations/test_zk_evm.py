from textwrap import wrap

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.integrations.test_cases import (
    params_erc20,
    params_execute,
    params_execute_at_address,
)
from tests.utils.utils import traceit


@pytest_asyncio.fixture(scope="module")
async def zk_evm(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
) -> StarknetContract:
    return await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[
            1,
            eth.contract_address,
            contract_account_class.class_hash,
        ],
    )


@pytest_asyncio.fixture(scope="module", autouse=True)
async def set_account_registry(
    zk_evm: StarknetContract, account_registry: StarknetContract
):
    await account_registry.transfer_ownership(zk_evm.contract_address).execute(
        caller_address=1
    )
    await zk_evm.set_account_registry(
        registry_address_=account_registry.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=zk_evm.contract_address
    )


@pytest.mark.asyncio
class TestZkEVM:
    @staticmethod
    def int_to_uint256(value):
        low = value & ((1 << 128) - 1)
        high = value >> 128
        return low, high

    @staticmethod
    def hex_string_to_bytes_array(h: str):
        if len(h) % 2 != 0:
            raise ValueError(f"Provided string has an odd length {len(h)}")
        return [int(b, 16) for b in wrap(h, 2)]

    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, zk_evm: StarknetContract, params: dict, request):
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute(
                value=int(params["value"]),
                bytecode=self.hex_string_to_bytes_array(params["code"]),
                calldata=self.hex_string_to_bytes_array(params["calldata"]),
            ).call(caller_address=1)

        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        assert res.result.stack == [
            Uint256(*self.int_to_uint256(int(s)))
            for s in (params["stack"].split(",") if params["stack"] else [])
        ]

        assert res.result.memory == self.hex_string_to_bytes_array(params["memory"])
        events = params.get("events")
        if events:
            assert [
                [
                    event.keys,
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events

    @pytest_asyncio.fixture(scope="module")
    async def erc_20(self, zk_evm: StarknetContract) -> dict:
        constructor_bytecode = self.hex_string_to_bytes_array(
            "608060405234801561001057600080fd5b5060405161080d38038061080d83398101604081905261002f91610197565b815161004290600090602085019061005e565b50805161005690600190602084019061005e565b505050610248565b82805461006a906101f7565b90600052602060002090601f01602090048101928261008c57600085556100d2565b82601f106100a557805160ff19168380011785556100d2565b828001600101855582156100d2579182015b828111156100d25782518255916020019190600101906100b7565b506100de9291506100e2565b5090565b5b808211156100de57600081556001016100e3565b600082601f830112610107578081fd5b81516001600160401b038082111561012157610121610232565b6040516020601f8401601f191682018101838111838210171561014657610146610232565b604052838252858401810187101561015c578485fd5b8492505b8383101561017d5785830181015182840182015291820191610160565b8383111561018d57848185840101525b5095945050505050565b600080604083850312156101a9578182fd5b82516001600160401b03808211156101bf578384fd5b6101cb868387016100f7565b935060208501519150808211156101e0578283fd5b506101ed858286016100f7565b9150509250929050565b60028104600182168061020b57607f821691505b6020821081141561022c57634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052604160045260246000fd5b6105b6806102576000396000f3fe"
        )
        contract_bytecode = self.hex_string_to_bytes_array(
            "608060405234801561001057600080fd5b50600436106100935760003560e01c806340c10f191161006657806340c10f19146100fe57806370a082311461011357806395d89b4114610126578063a9059cbb1461012e578063dd62ed3e1461014157610093565b806306fdde0314610098578063095ea7b3146100b657806318160ddd146100d657806323b872dd146100eb575b600080fd5b6100a0610154565b6040516100ad91906104a4565b60405180910390f35b6100c96100c4366004610470565b6101e2565b6040516100ad9190610499565b6100de61024c565b6040516100ad91906104f7565b6100c96100f9366004610435565b610252565b61011161010c366004610470565b610304565b005b6100de6101213660046103e2565b61033d565b6100a061034f565b6100c961013c366004610470565b61035c565b6100de61014f366004610403565b6103a9565b600080546101619061052f565b80601f016020809104026020016040519081016040528092919081815260200182805461018d9061052f565b80156101da5780601f106101af576101008083540402835291602001916101da565b820191906000526020600020905b8154815290600101906020018083116101bd57829003601f168201915b505050505081565b3360008181526004602090815260408083206001600160a01b038716808552925280832085905551919290917f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259061023b9086906104f7565b60405180910390a350600192915050565b60025481565b6001600160a01b038316600090815260046020908152604080832033845290915281205460001981146102ae576102898382610518565b6001600160a01b03861660009081526004602090815260408083203384529091529020555b6001600160a01b038516600090815260036020526040812080548592906102d6908490610518565b9091555050506001600160a01b03831660009081526003602052604090208054830190555060019392505050565b80600260008282546103169190610500565b90915550506001600160a01b03909116600090815260036020526040902080549091019055565b60036020526000908152604090205481565b600180546101619061052f565b3360009081526003602052604081208054839190839061037d908490610518565b9091555050506001600160a01b0382166000908152600360205260409020805482019055600192915050565b600460209081526000928352604080842090915290825290205481565b80356001600160a01b03811681146103dd57600080fd5b919050565b6000602082840312156103f3578081fd5b6103fc826103c6565b9392505050565b60008060408385031215610415578081fd5b61041e836103c6565b915061042c602084016103c6565b90509250929050565b600080600060608486031215610449578081fd5b610452846103c6565b9250610460602085016103c6565b9150604084013590509250925092565b60008060408385031215610482578182fd5b61048b836103c6565b946020939093013593505050565b901515815260200190565b6000602080835283518082850152825b818110156104d0578581018301518582016040015282016104b4565b818111156104e15783604083870101525b50601f01601f1916929092016040019392505050565b90815260200190565b600082198211156105135761051361056a565b500190565b60008282101561052a5761052a61056a565b500390565b60028104600182168061054357607f821691505b6020821081141561056457634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052601160045260246000fdfea26469706673582212204e53876a7abf080ce7b38dffe1572ec4843a83c565efd2feeb856984b5af6fb764736f6c63430008000033"
            "0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000074b616b61726f74000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003534a4e0000000000000000000000000000000000000000000000000000000000"
        )
        bytecode = [*constructor_bytecode, *contract_bytecode]

        with traceit.context("deploy kakarot erc20"):
            tx = await zk_evm.deploy(bytecode=bytecode).execute(caller_address=1)
        return {
            "constructor_bytecode": constructor_bytecode,
            "contract_bytecode": contract_bytecode,
            "tx": tx,
        }

    async def test_deploy(
        self,
        starknet: Starknet,
        erc_20: dict,
        contract_account_class: DeclaredClass,
    ):
        starknet_contract_address = erc_20["tx"].result.starknet_contract_address
        contract_account = StarknetContract(
            starknet.state,
            contract_account_class.abi,
            starknet_contract_address,
            erc_20["tx"],
        )
        stored_bytecode = (await contract_account.bytecode().call()).result.bytecode
        assert stored_bytecode == erc_20["contract_bytecode"][: len(stored_bytecode)]

    @pytest.mark.parametrize(
        "params",
        params_execute_at_address,
    )
    async def test_execute_at_address(
        self,
        zk_evm: StarknetContract,
        erc_20: dict,
        params: dict,
        request,
    ):
        state = zk_evm.state.copy()
        with traceit.context(request.node.callspec.id):
            res = await zk_evm.execute_at_address(
                address=erc_20["tx"].result.evm_contract_address,
                value=params["value"],
                calldata=self.hex_string_to_bytes_array(params["calldata"]),
            ).execute(caller_address=2)

        assert res.result.return_data == self.hex_string_to_bytes_array(
            params["return_value"]
        )
        zk_evm.state = state

    @pytest.mark.parametrize(
        "params",
        params_erc20,
    )
    async def test_erc20(self, zk_evm: StarknetContract, erc_20: dict, params, request):
        evm_contract_address = erc_20["tx"].result.evm_contract_address
        state = zk_evm.state.copy()
        with traceit.context(request.node.callspec.id):

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["mint"]),
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["approve"]),
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["allowance"]),
            ).execute(caller_address=2)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["transferFrom"]),
            ).execute(caller_address=1)

            await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["transfer"]),
            ).execute(caller_address=1)

            res = await zk_evm.execute_at_address(
                address=evm_contract_address,
                value=0,
                calldata=self.hex_string_to_bytes_array(params["balanceOf"]),
            ).execute(caller_address=1)

        assert res.result.return_data == self.hex_string_to_bytes_array(
            params["return_value"]
        )
        zk_evm.state = state
