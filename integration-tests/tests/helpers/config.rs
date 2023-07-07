use eyre::{Result};
use starknet::core::types::FieldElement;
use url::Url;


#[derive(Debug, Clone)]
pub struct StarknetConfig {
    pub starknet_rpc: Url,
    pub evm_address: FieldElement,
    pub proxy_account_class_hash: FieldElement,
}

impl StarknetConfig {
    pub fn new(
        starknet_rpc: Url,
        evm_address: FieldElement,
        proxy_account_class_hash: FieldElement,
    ) -> Self {
        StarknetConfig {
            starknet_rpc,
            evm_address,
            proxy_account_class_hash,
        }
    }

    pub fn from_env() -> Result<Self, String> {
        let starknet_rpc_url = Self::get_env_var("STARKNET_RPC_URL")?;

        let evm_address = Self::get_env_var("EVM_ADDRESS")?;
        let evm_address = FieldElement::from_hex_be(&evm_address).map_err(|_| {
            format!("EVM_ADDRESS should be provided as a hex string, got {evm_address}")
        })?;

        let proxy_account_class_hash = Self::get_env_var("PROXY_ACCOUNT_CLASS_HASH")?;
        let proxy_account_class_hash = FieldElement::from_hex_be(&proxy_account_class_hash).map_err(|_| {
            format!(
                "PROXY_ACCOUNT_CLASS_HASH should be provided as a hex string, got {proxy_account_class_hash}"
            )
        })?;

        Ok(StarknetConfig::new(
            Url::parse(starknet_rpc_url.as_str()).unwrap(),
            evm_address,
            proxy_account_class_hash,
        ))
    }

fn get_env_var(name: &str) -> Result<String, String> {
    std::env::var(name).map_err(|_| "Environment variable not found".to_string())
    }
}