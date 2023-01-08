// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.pow import pow
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.uint256 import word_reverse_endian

// The namespace handling all RLP computation
namespace RLP {

  // The type returned when data is RLP decoded
  struct Field {
    data_len: felt,
    data: felt*,
    is_list: felt, // when is TRUE the data must be RLP decoded
  }

  // @notice transform muliple bytes into a single felt
  // @param data_len The lenght of the bytes
  // @param data The pointer to the bytes array
  // @param n used for recursion, set to 0
  // @return n the resultant felt
  func bytes_to_felt{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(
    data_len: felt,
    data: felt*,
    n: felt
  ) -> (n:felt) {
    if(data_len == 0) {
      return (n=n);
    }
    let e: felt = data_len - 1;
    let byte: felt = data[data_len-1];
    let (res) = pow(256, e);
    return bytes_to_felt(data_len=data_len-1,data=data,n=n+byte*res);
  }

  // @notice transform muliple bytes into a single felt (big endian)
  // @param data_len The lenght of the bytes
  // @param data The pointer to the bytes array
  // @param n used for recursion, set to 0
  // @return n the resultant felt in big endian
  func bytes_to_felt_big{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(
    data_len: felt,
    data: felt*,
    n: felt
  ) -> (n:felt) {
    if(data_len == 0) {
      return (n=n);
    }
    let e: felt = data_len - 1;
    let byte: felt = data[0];
    let (res) = pow(256, e);
    return bytes_to_felt_big(data_len=data_len-1,data=data+1,n=n+byte*res);
  }

  // @notice transforms a sequence of bytes to groups of 64 bits (little endian)
  // @param data_len The lenght of the bytes
  // @param data The pointer to the first byte in array
  // @param words_len Used for recursion, set to 0
  // @param words A pointer to an empty array, will be filled with the words
  // @return words_len The number of words created
  func bytes_to_words{
       syscall_ptr: felt*,
       pedersen_ptr: HashBuiltin*,
       bitwise_ptr: BitwiseBuiltin*,
       range_check_ptr
  }(
    data_len: felt,
    data: felt*,
    words_len: felt,
    words: felt*
  ) -> (words_len:felt) {
   alloc_locals;
   if(data_len == 0) {
     return (words_len=words_len);
   }
   let is_le_7 = is_le(data_len, 7);
   if(is_le_7 == 1) {
      let (n: felt) = bytes_to_felt(data_len=data_len, data=data, n=0);
      assert [words] = n;
      return bytes_to_words(data_len=0,data=data+data_len,words_len=words_len+1,words=words+1);
   }else{
      let (n: felt) = bytes_to_felt(data_len=8,data=data,n=0);
      assert [words] = n;
      return bytes_to_words(data_len=data_len-8,data=data+8,words_len=words_len+1,words=words+1);     
   }
  }

  // @notice transforms bytes to an uint256
  // @param data_len The lenght of the bytes
  // @param data The pointer to the first byte in array
  // @return high The high 128 bits
  // @return low The low 128 bits
  func bytes_to_uint256{
       syscall_ptr: felt*,
       pedersen_ptr: HashBuiltin*,
       bitwise_ptr: BitwiseBuiltin*,
       range_check_ptr
  }(
    data_len: felt,
    data: felt*,
  ) -> (res: Uint256) {
   alloc_locals;
   let (n: felt) = bytes_to_felt_big(data_len=16,data=data,n=0);
   local high = n;
   let (n: felt) = bytes_to_felt_big(data_len=16,data=data+16,n=0);
   local low = n;
   return (res=Uint256(low=low,high=high));
  }

  // @notice reads the next byte in the buffer_ptr and increments it
  // @implicit_param buffer_ptr Pointer to an array of bytes
  // @return byte The read byte
  func read_byte{ 
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
      buffer_ptr: felt*
  }() -> (byte:felt) {
      tempvar byte = [buffer_ptr];
      let buffer_ptr = buffer_ptr + 1;
      return (byte=byte);
  }

  // @notice decodes RLP data see this: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp
  // @param data_len The lenght of the bytes
  // @param data The pointer to the first byte in array
  // @param fields A pointer to an empty array of fields, will be filled with found fields
  func decode_rlp{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(
    data_len: felt,
    data: felt*,
    fields: Field*
  ) -> () {
    alloc_locals;
    if(data_len == 0) {
      return ();
    }
    let buffer_ptr = data;
    with buffer_ptr{
        let (byte: felt) = read_byte();
        let is_le_127: felt = is_le(byte, 127);
        if(is_le_127 == 1) {
            assert [fields] = Field(
              data_len=1,
              data=buffer_ptr-1,
              is_list=0
            );
            return decode_rlp(data_len=data_len-1,data=buffer_ptr, fields=fields + Field.SIZE);
        }
        let is_le_183 = is_le(byte, 183); // a max 55 bytes long string
        if(is_le_183 == 1) {
            let string_len = byte - 128;
            assert [fields] = Field(
              data_len=string_len,
              data=buffer_ptr,
              is_list=0
            );
            return decode_rlp(data_len=data_len-1-string_len,data=buffer_ptr+string_len,fields=fields + Field.SIZE);
        }
        let is_le_191 = is_le(byte,191); // string longer than 55 bytes
        if (is_le_191 == 1) {
            local len_len = byte - 183;
            let (dlen) = bytes_to_felt(data_len=len_len,data=buffer_ptr,n=0);
            let buffer_ptr = buffer_ptr + len_len;
            assert [fields] = Field(
              data_len=dlen,
              data=buffer_ptr,
              is_list=0
            );
            return decode_rlp(data_len=data_len-1-len_len-dlen,data=buffer_ptr+dlen,fields=fields + Field.SIZE);
        }
        let is_le_247 = is_le(byte, 247); // list 0-55 bytes long
        if(is_le_247 == 1) {
              local list_len = byte - 192;
              assert [fields] = Field(
                data_len=list_len,
                data=buffer_ptr,
                is_list=1
              );
              return decode_rlp(data_len=data_len-1-list_len,data=buffer_ptr+list_len,fields=fields + Field.SIZE);
        }
        let is_le_255 = is_le(byte, 255); // list > 55 bytes
        if(is_le_255 == 1) {
            local list_len_len = byte - 247;
            let (dlen) = bytes_to_felt(data_len=list_len_len,data=buffer_ptr,n=0);
            let buffer_ptr = buffer_ptr + list_len_len;
            assert [fields] = Field(
                data_len=dlen,
                data=buffer_ptr,
                is_list=1
            );
            return decode_rlp(data_len=data_len-1-list_len_len-dlen,data=buffer_ptr+dlen,fields=fields + Field.SIZE);
        }
        return ();
    }
  }

  // @notice fills an array with another array
  // @param recipient A pointer to an empty array
  // @param data_len The lenght of the bytes to copy from
  // @param data The pointer to the first byte in the array to copy from 
  func fill_array{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(
    recipient: felt*,
    data_len: felt,
    data: felt*
  ) -> () {
    if(data_len == 0) {
      return ();
    }

    assert [recipient] = [data];
    return fill_array(recipient+1, data_len-1, data+1);
  }

  // @notice Returns the lenght in bytes of a felt
  // @param len The felt to get the length in bytes
  // @return byte_len The length in bytes
  func bytes_len{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(len: felt) -> (byte_len: felt){
    // get ready for ugly code
    let fit = is_le(len, 255);
    if(fit == 1) {
      return (byte_len=1);
    }
    let fit = is_le(len, 65535);
    if(fit == 1) {
      return (byte_len=2);
    }
    let fit = is_le(len, 16777215);
    if(fit == 1) {
      return (byte_len=3);
    }
    let fit = is_le(len, 4294967295);
    if(fit == 1) {
      return (byte_len=4);
    }
    let fit = is_le(len, 1099511627775);
    if(fit == 1) {
      return (byte_len=5);
    }
    let fit = is_le(len, 281474976710655);
    if(fit == 1) {
      return (byte_len=6);
    }
    let fit = is_le(len, 72057594037927935);
    if(fit == 1) {
      return (byte_len=7);
    }
    let fit = is_le(len, 18446744073709551615);
    if(fit == 1) {
      return (byte_len=8);
    }
    return (byte_len=0);
  }

  // @dev returns an array representing the value by the remainders of the 16 division
  // @dev example: 1000 => [8, 14, 3]
  // @param rs_len Used for recursion, set to 0
  // @param rs Pointer to the array that will receive the remainders
  // @param v The initial value
  // @return rs_len The final length of the remainders array
  func to_base_16{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(rs_len: felt, rs: felt*, v: felt) -> (rs_len:felt) {
    let (q, r) = unsigned_div_rem(v, 16);
    let is_le_16 = is_le(q,16);
    assert [rs] = r;
    if(is_le_16 == 1){
      let rs = rs + 1;
      assert [rs] = q;
      return (rs_len=rs_len+2);
    }
    return to_base_16(rs_len+1, rs+1,q);
  }

  // @notice transforms an array of 16'th remainders to bytes
  // @param bytes The pointer which will be filled with the bytes
  // @param rs_len The length of the remainders array
  // @param rs The array of remainders
  func to_bytes{
     syscall_ptr: felt*,
     pedersen_ptr: HashBuiltin*,
     bitwise_ptr: BitwiseBuiltin*,
     range_check_ptr,
  }(
    bytes: felt*,
    rs_len: felt,
    rs: felt*
  ) -> () {
    if(rs_len == 0) {
      return ();
    }
    let (q, r) = unsigned_div_rem(rs_len, 2);
    if(r == 0){
        assert [bytes] = rs[rs_len-1]*16 + rs[rs_len-2];
        return to_bytes(bytes, rs_len-2, rs);
    }else{
        assert [bytes] = rs[rs_len-1];
        return to_bytes(bytes, rs_len-1,rs);
    }
}


  // @notice encodes data into an rlp list
  // @dev data must be rlp encoded before using this function
  // @param data_len The lenght of the bytes to copy from
  // @param data The pointer to the first byte in the array to copy from 
  // @param rlp The pointer receiving the rlp encoded list
  // @return rlp_len The length of the encoded list in bytes
  func encode_rlp_list{
      syscall_ptr: felt*,
      pedersen_ptr: HashBuiltin*,
      bitwise_ptr: BitwiseBuiltin*,
      range_check_ptr,
  }(
    data_len: felt,
    data: felt*,
    rlp: felt*
  ) -> (rlp_len: felt) {
    alloc_locals;
    let is_le_55 = is_le(data_len, 55);
    if(is_le_55 == 1) {
      assert rlp[0] = 0xc0 + data_len;
      fill_array(rlp+1, data_len, data);
      return (rlp_len=data_len+1);
    }else{
      let (byte_len) = bytes_len(data_len); 
      assert rlp[0] = 0xf7  + byte_len;
      let (local rs: felt*) = alloc();
      let (rs_len) = to_base_16(0, rs, data_len);
      let (local bytes: felt*) = alloc();
      to_bytes(bytes, rs_len, rs);
      fill_array(rlp+1, byte_len, bytes);
      fill_array(rlp+1+byte_len, data_len, data);
      return (rlp_len=data_len+1);
    }
  }
}
