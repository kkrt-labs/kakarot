%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.math import unsigned_div_rem
from utils.pow2 import pow2
from starkware.cairo.common.math_cmp import is_le_felt
from utils.utils import Helpers
from starkware.cairo.common.uint256 import Uint256



// Gets a Byte given a felt with 31 Bytes
func get_byte_in_array{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(offset:felt,felt_packed_code:felt,return_byte_length:felt) -> felt {
        //Calculate the len in bits
        let return_bits_length : felt = return_byte_length*8;
        // Calculate the offset
        let width: felt = 248 - offset * 8 - return_bits_length;
        // Get the range
        let range: felt = pow2(width);
        // Calculate the length of bits
        let mask_len : felt = pow2(return_bits_length);
        // Get the "11111" for the bits that will be filtered
        let mask_len_filter : felt = mask_len - 1;
        // Generate the mask, with the "mask_len_filter"(11111's) and the range ('1000000000')
        let mask : felt = mask_len_filter*range;
        // Get the filtered Bytes
        let filtered_value : felt = bitwise_and(felt_packed_code,mask);
        // Unpad the filtered bytes
        let opcode :felt = filtered_value/range;

        return (opcode);

}
// Define if code given will be given + 1 and also the new_array_len if it will be total, or new_aray_len -1
func slice_bytes_loop_translator{        
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*}(code_offset:felt, code_len:felt, code:felt*, new_array_len:felt, new_array:felt*){
        alloc_locals;

        let (local res, local rem) = unsigned_div_rem(code_offset+new_array_len, 31);
        let is_res_less_than_code_len:felt = is_le_felt(res,code_len-1);

        local value;

        if (is_res_less_than_code_len == 1){
            assert value = [code + res];
        } else {
            assert value = 0;
        }

        let byte : felt = get_byte_in_array(offset=rem,felt_packed_code=value,return_byte_length=1);

        assert new_array[new_array_len] = byte;

        if(new_array_len == 0){
            return();
        }

        slice_bytes_loop_translator(code_offset=code_offset,code_len=code_len,code=code,new_array_len=new_array_len-1,new_array=new_array);

        return ();
}


func get_uint256_in_array{        
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*} ( offset : felt, code_len:felt ,code:felt*, len:felt) -> Uint256 {

        alloc_locals;
        if(len == 32){ 

            // construct high
            let high: felt =  get_felt_in_array_with_len(offset=offset, code_len=code_len, code=code, len=16);
            // construct low
            let low: felt = get_felt_in_array_with_len(offset=offset+16, code_len=code_len,code=code,len=16);
            // transform to uint256
            let final_uint256 : Uint256 = Uint256(low=low,high=high);
            // return utin256
            return(final_uint256);
        
        
        } else {
            let final_data : felt = get_felt_in_array_with_len(offset=offset, code_len=code_len,code=code, len=len);

            let final_uint256 : Uint256 = Helpers.to_uint256(final_data);

            return (final_uint256);

        } 
    }

func get_felt_in_array_with_len{        
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*} ( offset : felt, code_len:felt , code:felt*, len:felt) -> felt{

        let (offset_res, offset_rem) = unsigned_div_rem(offset,31);
        let (res, rem) = unsigned_div_rem(offset_rem + len,31);

        if (res == 1){
            // Get data from rem all the way to 31 - rem - data1
            let data1 : felt = get_byte_in_array(offset=offset_rem, felt_packed_code=[code + offset_res] , return_byte_length= (31 - offset_rem));
            // Get data of [code + 1]  from 0 all the way to rem - data2
            let data1_mask : felt = pow2(rem*8);
            let data1_with_mask : felt = data1 * data1_mask;
            let data2_with_mask : felt = get_byte_in_array(offset=0, felt_packed_code=[code + offset_res + 1] , return_byte_length = rem);
            let final_data : felt  = data1_with_mask + data2_with_mask;
            // let final_uint256 : Uint256 = Uint256(final_data);
            return (final_data);

        } else {
            let final_data : felt = get_byte_in_array(offset=offset_rem, felt_packed_code=[code + offset_res] , return_byte_length=len);

            return (final_data);
    }

}



func pack_array_bytes{syscall_ptr: felt*, pedersen_ptr:HashBuiltin*, range_check_ptr, bitwise_ptr:BitwiseBuiltin*}(code_len: felt, code: felt*,new_array:felt*, len:felt){
        alloc_locals;

        let value = pack_31bytes_to_felt(val=code + len*31);

        assert [new_array + len] = value;

        if(len == 0){
            return();
        }
        
        pack_array_bytes(code_len=code_len, code=code, new_array=new_array, len = len -1);

        return();

}

func pack_31bytes_to_felt{syscall_ptr: felt*, pedersen_ptr:HashBuiltin*, range_check_ptr, bitwise_ptr:BitwiseBuiltin*}(val:felt*) -> felt{
    
        let value: felt = [val]*256**30 + [val + 1]*256**29 + [val + 2]*256**28+ [val + 3]*256**27 + [val + 4]*256**26+ [val + 5]*256**25+ [val + 6]*256**24+ [val + 7]*256**23+ [val + 8]*256**22+ [val + 9]*256**21+ [val + 10]*256**20+ [val + 11]*256**19+ [val + 12]*256**18+ [val + 13]*256**17 + [val + 14]*256**16 + [val + 15]*256**15 + [val + 16]*256**14 + [val + 17]*256**13 + [val + 18]*256**12+ [val + 19]*256**11+ [val + 20]*256**10+ [val + 21]*256**9+ [val + 22]*256**8+ [val + 23]*256**7+ [val + 24]*256**6+ [val + 25]*256**5+ [val + 26]*256**4 + [val + 27]*256**3+ [val + 28]*256**2 + [val + 29]*256 + [val + 30];

        return (value);
}

        

