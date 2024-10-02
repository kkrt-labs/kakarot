use core::starknet::secp256_trait::{Signature};
use crate::eth_transaction::tx_type::TxType;
use crate::traits::BoolIntoNumeric;

/// Deserializes a signature from a span of felt252 values.
///
/// # Arguments
///
/// * `signature` - A span of felt252 values representing the signature components.
/// * `chain_id` - The chain ID used for EIP-155 signature recovery.
///
/// # Returns
///
/// * `Option<Signature>` - The deserialized signature if successful, or None if deserialization
/// fails.
pub fn deserialize_signature(signature: Span<felt252>, chain_id: u64) -> Option<Signature> {
    let r_low: u128 = (*signature.at(0)).try_into()?;
    let r_high: u128 = (*signature.at(1)).try_into()?;

    let s_low: u128 = (*signature.at(2)).try_into()?;
    let s_high: u128 = (*signature.at(3)).try_into()?;

    let v: u128 = (*signature.at(4)).try_into()?;

    let odd_y_parity = if v == 0 {
        false
    } else if v == 1 {
        true
    } else {
        compute_y_parity(v, chain_id)?
    };

    Option::Some(
        Signature {
            r: u256 { low: r_low, high: r_high },
            s: u256 { low: s_low, high: s_high },
            y_parity: odd_y_parity,
        }
    )
}

/// Computes the y-parity value for EIP-155 signature recovery.
///
/// # Arguments
///
/// * `v` - The v value from the signature.
/// * `chain_id` - The chain ID used for EIP-155 signature recovery.
///
/// # Returns
///
/// * `Option<bool>` - The computed y-parity value if valid, or None if invalid.
fn compute_y_parity(v: u128, chain_id: u64) -> Option<bool> {
    let y_parity = v - (chain_id.into() * 2 + 35);
    if (y_parity == 0 || y_parity == 1) {
        return Option::Some(y_parity == 1);
    }

    return Option::None;
}

/// Serializes a transaction signature into an array of felt252 values.
///
/// # Arguments
///
/// * `sig` - The signature to serialize.
/// * `tx_type` - The transaction type (Legacy, EIP-2930, or EIP-1559).
/// * `chain_id` - The chain ID used for EIP-155 signature recovery.
///
/// # Returns
///
/// * `Array<felt252>` - The serialized signature as an array of felt252 values.
pub fn serialize_transaction_signature(
    sig: Signature, tx_type: TxType, chain_id: u64
) -> Array<felt252> {
    let mut res: Array<felt252> = array![
        sig.r.low.into(), sig.r.high.into(), sig.s.low.into(), sig.s.high.into()
    ];

    let value = match tx_type {
        TxType::Legacy(_) => { sig.y_parity.into() + 2 * chain_id + 35 },
        TxType::Eip2930(_) | TxType::Eip1559(_) => { sig.y_parity.into() }
    };

    res.append(value.into());
    res
}

/// Deserializes a span of felt252 values into an array of bytes.
///
/// # Arguments
///
/// * `self` - A span of felt252 values to deserialize.
///
/// # Returns
///
/// * `Option<Array<u8>>` - The deserialized bytes if successful, or None if deserialization fails.
pub fn deserialize_bytes(self: Span<felt252>) -> Option<Array<u8>> {
    let mut bytes: Array<u8> = Default::default();

    for item in self {
        let v: Option<u8> = (*item).try_into();

        match v {
            Option::Some(v) => { bytes.append(v); },
            Option::None => { break; }
        }
    };

    // it means there was an error in the above loop
    if (bytes.len() != self.len()) {
        Option::None
    } else {
        Option::Some(bytes)
    }
}

/// Serializes a span of bytes into an array of felt252 values.
///
/// # Arguments
///
/// * `self` - A span of bytes to serialize.
///
/// # Returns
///
/// * `Array<felt252>` - The serialized bytes as an array of felt252 values.
pub fn serialize_bytes(self: Span<u8>) -> Array<felt252> {
    let mut array: Array<felt252> = Default::default();

    for item in self {
        let value: felt252 = (*item).into();
        array.append(value);
    };

    array
}

#[cfg(test)]
mod tests {
    use core::starknet::secp256_trait::Signature;
    use crate::constants::CHAIN_ID;
    use crate::eth_transaction::tx_type::TxType;
    use crate::serialization::{deserialize_signature, serialize_transaction_signature};

    #[test]
    fn test_serialize_transaction_signature() {
        // generated via ./scripts/compute_rlp_encoding.ts
        // inputs:
        //          to: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
        //          value: 1
        //          gasLimit: 1
        //          gasPrice: 1
        //          nonce: 1
        //          chainId: 1263227476
        //          data: 0xabcdef
        //          tx_type: 0 for signature_0, 1 for signature_1, 2 for signature_2

        // tx_type = 0, v: 0x9696a4cb
        let signature_0 = Signature {
            r: 0x306c3f638450a95f1f669481bf8ede9b056ef8d94259a3104f3a28673e02823d,
            s: 0x41ea07e6d3d02773e380e752e5b3f9d28aca3882ee165e56b402cca0189967c9,
            y_parity: false
        };

        // tx_type = 1
        let signature_1 = Signature {
            r: 0x615c33039b7b09e3d5aa3cf1851c35abe7032f92111cc95ef45f83d032ccff5d,
            s: 0x30b5f1a58abce1c7d45309b7a3b0befeddd1aee203021172779dd693a1e59505,
            y_parity: false
        };

        // tx_type = 2
        let signature_2 = Signature {
            r: 0xbc485ed0b43483ebe5fbff90962791c015755cc03060a33360b1b3e823bb71a4,
            s: 0x4c47017509e1609db6c2e8e2b02327caeb709c986d8b63099695105432afa533,
            y_parity: false
        };

        let expected_signature_0: Span<felt252> = [
            signature_0.r.low.into(),
            signature_0.r.high.into(),
            signature_0.s.low.into(),
            signature_0.s.high.into(),
            0x9696a4cb
        ].span();

        let expected_signature_1: Span<felt252> = [
            signature_1.r.low.into(),
            signature_1.r.high.into(),
            signature_1.s.low.into(),
            signature_1.s.high.into(),
            0x0_felt252,
        ].span();

        let expected_signature_2: Span<felt252> = [
            signature_2.r.low.into(),
            signature_2.r.high.into(),
            signature_2.s.low.into(),
            signature_2.s.high.into(),
            0x0_felt252,
        ].span();

        let result = serialize_transaction_signature(signature_0, TxType::Legacy, CHAIN_ID).span();
        assert_eq!(result, expected_signature_0);

        let result = serialize_transaction_signature(signature_1, TxType::Eip2930, CHAIN_ID).span();
        assert_eq!(result, expected_signature_1);

        let result = serialize_transaction_signature(signature_2, TxType::Eip1559, CHAIN_ID).span();
        assert_eq!(result, expected_signature_2);
    }

    #[test]
    fn test_deserialize_transaction_signature() {
        // generated via ./scripts/compute_rlp_encoding.ts
        // using json inputs
        //          to: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
        //          value: 1
        //          gasLimit: 1
        //          gasPrice: 1
        //          nonce: 1
        //          chainId: 1263227476
        //          data: 0xabcdef
        //          tx_type: 0 for signature_0, 1 for signature_1, 2 for signature_2

        // tx_type = 0, v: 0x9696a4cb
        let signature_0 = Signature {
            r: 0x5e5202c7e9d6d0964a1f48eaecf12eef1c3cafb2379dfeca7cbd413cedd4f2c7,
            s: 0x66da52d0b666fc2a35895e0c91bc47385fe3aa347c7c2a129ae2b7b06cb5498b,
            y_parity: false
        };

        // tx_type = 1
        let signature_1 = Signature {
            r: 0xbced8d81c36fe13c95b883b67898b47b4b70cae79e89fa27856ddf8c533886d1,
            s: 0x3de0109f00bc3ed95ffec98edd55b6f750cb77be8e755935dbd6cfec59da7ad0,
            y_parity: true
        };

        // tx_type = 2
        let signature_2 = Signature {
            r: 0x0f9a716653c19fefc240d1da2c5759c50f844fc8835c82834ea3ab7755f789a0,
            s: 0x71506d904c05c6e5ce729b5dd88bcf29db9461c8d72413b864923e8d8f6650c0,
            y_parity: true
        };

        // tx_type = 2 with false y parity - cf input_eip1559_y_parity_false.json
        let signature_3 = Signature {
            r: 0x782ce82b688abbf13a5e7536b27be67d2795a28b9d4bf819120c17630d88e609,
            s: 0x43b90a3315977fe71c9b3687a89857544158e23c5045e7a5852bae03323c9898,
            y_parity: false
        };

        let signature_0_felt252_arr: Array<felt252> = array![
            signature_0.r.low.into(),
            signature_0.r.high.into(),
            signature_0.s.low.into(),
            signature_0.s.high.into(),
            0x9696a4cb
        ];

        let signature_1_felt252_arr: Array<felt252> = array![
            signature_1.r.low.into(),
            signature_1.r.high.into(),
            signature_1.s.low.into(),
            signature_1.s.high.into(),
            0x1
        ];

        let signature_2_felt252_arr: Array<felt252> = array![
            signature_2.r.low.into(),
            signature_2.r.high.into(),
            signature_2.s.low.into(),
            signature_2.s.high.into(),
            0x1
        ];

        let signature_3_felt252_arr: Array<felt252> = array![
            signature_3.r.low.into(),
            signature_3.r.high.into(),
            signature_3.s.low.into(),
            signature_3.s.high.into(),
            0x0
        ];

        let result: Signature = deserialize_signature(signature_0_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_0);

        let result: Signature = deserialize_signature(signature_1_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_1);

        let result: Signature = deserialize_signature(signature_2_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_2);

        let result: Signature = deserialize_signature(signature_3_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_3);
    }
}
