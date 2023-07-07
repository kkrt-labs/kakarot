use eyre::Result;
use starknet::core::types::{BlockId, BlockTag, FieldElement, FunctionCall};
use starknet::providers::jsonrpc::{HttpTransport, JsonRpcClient};
use starknet::{macros::selector, providers::Provider};
use std::error::Error;

pub const EXECUTE: FieldElement = selector!("execute");

pub struct KakarotClient<StarknetClient>
where
    StarknetClient: Provider,
{
    pub starknet_provider: StarknetClient,
    pub kakarot_address: FieldElement,
    pub proxy_account_class_hash: FieldElement,
}

impl KakarotClient<JsonRpcClient<HttpTransport>> {
    pub fn new(starknet_provider: JsonRpcClient<HttpTransport>, kakarot_address: FieldElement, proxy_account_class_hash:FieldElement) -> Self {
        Self {
            starknet_provider,
            kakarot_address,
            proxy_account_class_hash,
        }
    }

    pub async fn call_execute(
        &self,
        value: FieldElement,
        bytecode: Vec<FieldElement>,
        kakarot_calldata: Vec<FieldElement>,
    ) -> Result<Vec<FieldElement>, Box<dyn Error>> {
        let kakarot_calldata_len = FieldElement::from(kakarot_calldata.len());
        let bytecode_len = FieldElement::from(bytecode.len());

        let mut execute_arguments = vec![];
        execute_arguments.push(value); //value

        execute_arguments.push(bytecode_len); //bytecode_len
        for bytecode_byte in bytecode {
            //bytecode
            execute_arguments.push(bytecode_byte);
        }

        execute_arguments.push(kakarot_calldata_len); //kakarot_calldata_len
        for calldata_bytes in kakarot_calldata {
            //kakarot_calldata
            execute_arguments.push(calldata_bytes);
        }

        let starknet_block_id = BlockId::Tag(BlockTag::Latest);

        let request = FunctionCall {
            contract_address: self.kakarot_address,
            entry_point_selector: EXECUTE,
            calldata: execute_arguments,
        };

        let call_result: Vec<FieldElement> = self
            .starknet_provider
            .call(request, starknet_block_id)
            .await?;

        Ok(call_result)
    }

}
