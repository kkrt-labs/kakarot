use core::starknet::EthAddress;
use crate::math::Bitshift;
use crate::traits::EthAddressIntoU256;

#[generate_trait]
pub impl EthAddressExImpl of EthAddressExTrait {
    const BYTES_USED: u8 = 20;
    /// Converts an EthAddress to an array of bytes.
    ///
    /// # Returns
    ///
    /// * `Array<u8>` - A 20-byte array representation of the EthAddress.
    fn to_bytes(self: EthAddress) -> Array<u8> {
        let value: u256 = self.into();
        let mut bytes: Array<u8> = Default::default();
        for i in 0
            ..Self::BYTES_USED {
                let val = value.shr(8_u32 * (Self::BYTES_USED.into() - i.into() - 1));
                bytes.append((val & 0xFF).try_into().unwrap());
            };

        bytes
    }

    /// Converts a 20-byte array into an EthAddress.
    ///
    /// # Arguments
    ///
    /// * `input` - A `Span<u8>` of length 20 representing the bytes of an Ethereum address.
    ///
    /// # Returns
    ///
    /// * `Option<EthAddress>` - `Some(EthAddress)` if the conversion succeeds, `None` if the input
    /// length is not 20.
    fn from_bytes(input: Span<u8>) -> Option<EthAddress> {
        let len = input.len();
        if len != 20 {
            return Option::None;
        }
        let offset: u32 = len - 1;
        let mut result: u256 = 0;
        for i in 0
            ..len {
                let byte: u256 = (*input.at(i)).into();
                result += byte.shl((8 * (offset - i)));
            };
        result.try_into()
    }
}

#[cfg(test)]
mod tests {
    use core::starknet::EthAddress;
    use super::EthAddressExTrait;
    #[test]
    fn test_eth_address_to_bytes() {
        let eth_address: EthAddress = 0x1234567890123456789012345678901234567890
            .try_into()
            .unwrap();
        let bytes = eth_address.to_bytes();
        assert_eq!(
            bytes.span(),
            [
                0x12,
                0x34,
                0x56,
                0x78,
                0x90,
                0x12,
                0x34,
                0x56,
                0x78,
                0x90,
                0x12,
                0x34,
                0x56,
                0x78,
                0x90,
                0x12,
                0x34,
                0x56,
                0x78,
                0x90
            ].span()
        );
    }

    #[test]
    fn test_eth_address_from_bytes() {
        let bytes = [
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90
        ].span();
        let eth_address = EthAddressExTrait::from_bytes(bytes);
        assert_eq!(
            eth_address,
            Option::Some(0x1234567890123456789012345678901234567890.try_into().unwrap())
        );
    }

    #[test]
    fn test_eth_address_from_bytes_invalid_length() {
        let bytes = [
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12
        ];
        let eth_address = EthAddressExTrait::from_bytes(bytes.span());
        assert_eq!(eth_address, Option::None);
    }
}
