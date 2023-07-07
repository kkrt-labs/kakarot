use hex;
use serde::Deserialize;
use starknet::core::types::FieldElement;

#[derive(Debug, Deserialize)]
pub struct TestCase {
    pub params: Params,
    pub id: String,
}

#[derive(Debug, Deserialize)]
pub struct Params {
    pub value: u128,
    pub code: String,
    pub calldata: String,
}


pub fn hex_to_field_elements(hex: &str) -> Vec<FieldElement> {
    // Convert the hex string to bytes
    let bytes = hex::decode(hex).expect("Invalid hex string");

    // Convert the bytes to FieldElement
    let elements: Vec<FieldElement> = bytes.iter().map(|byte| FieldElement::from(*byte)).collect();

    elements
}
