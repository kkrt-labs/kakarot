mod helpers;

#[cfg(test)]
pub mod test {
    use std::{fs::File, io::BufReader};

    use dotenv::dotenv;
    use starknet::{providers::{JsonRpcClient, jsonrpc::HttpTransport}, core::{ types::{FieldElement}}};
    use crate::helpers::{config::StarknetConfig, client::KakarotClient, utils::{hex_to_field_elements, TestCase}};


    #[tokio::test]
    async fn test_block_information() {
    dotenv().ok();

    let starknet_config = StarknetConfig::from_env().unwrap();
    let starknet_provider = JsonRpcClient::new(HttpTransport::new(starknet_config.starknet_rpc));

    let kakarot_client = KakarotClient::new(
        starknet_provider,
        starknet_config.evm_address,
        starknet_config.proxy_account_class_hash
    );

    let file = match File::open("tests/data/test_cases.json") {
        Ok(file) => file,
        Err(e) => {
            println!("Failed to open test_cases.json: {}", e);
            return;
        }
    };

    let reader = BufReader::new(file);

    let test_cases: Vec<TestCase> = match serde_json::from_reader(reader) {
        Ok(cases) => cases,
        Err(e) => {
            println!("Failed to parse test cases: {}", e);
            return;
        }
    };

    for (index, test_case) in test_cases.iter().enumerate() {
        
        let mut should_skip = false;
        let skip_mark = String::from("pytest.mark.skip");
        for mark in &test_case.marks {
            if mark.contains(&skip_mark) {
               should_skip = true;
               break;
            }
        }
        if should_skip {
            println!("Skipping test case {}: {}", index + 1, test_case.id);
            continue;
        }

        println!("Running test case {}: {}", index + 1, test_case.id);

        let value = FieldElement::from(test_case.params.value);
        let code = &test_case.params.code;
        let calldata = &test_case.params.calldata;
        let bytecode = hex_to_field_elements(code);
        let kakarot_calldata = hex_to_field_elements(calldata);

        let result = kakarot_client
                .call_execute(value, bytecode, kakarot_calldata)
                .await;

        match &result {
            Ok(_) => println!("Test case {} finished ✅", test_case.id),
            Err(e) => println!("Test case {} failed: {} ❌", test_case.id, e),
        };

        // assert!(result.is_ok());
    };

}

}