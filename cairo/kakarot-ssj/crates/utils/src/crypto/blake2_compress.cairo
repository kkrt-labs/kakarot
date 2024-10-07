use alexandria_data_structures::vec::{Felt252Vec, VecTrait};
use core::num::traits::{BitSize, WrappingAdd};
use crate::math::WrappingBitshift;

const SIGMA_LINE_1: [usize; 16] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
const SIGMA_LINE_2: [usize; 16] = [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3];
const SIGMA_LINE_3: [usize; 16] = [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4];
const SIGMA_LINE_4: [usize; 16] = [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8];
const SIGMA_LINE_5: [usize; 16] = [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13];
const SIGMA_LINE_6: [usize; 16] = [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9];
const SIGMA_LINE_7: [usize; 16] = [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11];
const SIGMA_LINE_8: [usize; 16] = [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10];
const SIGMA_LINE_9: [usize; 16] = [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5];
const SIGMA_LINE_10: [usize; 16] = [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0];

const IV_DATA: [
    u64
    ; 8] = [
    0x6a09e667f3bcc908,
    0xbb67ae8584caa73b,
    0x3c6ef372fe94f82b,
    0xa54ff53a5f1d36f1,
    0x510e527fade682d1,
    0x9b05688c2b3e6c1f,
    0x1f83d9abfb41bd6b,
    0x5be0cd19137e2179,
];

/// SIGMA from [spec](https://datatracker.ietf.org/doc/html/rfc7693#section-2.7)
fn SIGMA() -> Span<Span<usize>> {
    [
        SIGMA_LINE_1.span(),
        SIGMA_LINE_2.span(),
        SIGMA_LINE_3.span(),
        SIGMA_LINE_4.span(),
        SIGMA_LINE_5.span(),
        SIGMA_LINE_6.span(),
        SIGMA_LINE_7.span(),
        SIGMA_LINE_8.span(),
        SIGMA_LINE_9.span(),
        SIGMA_LINE_10.span(),
    ].span()
}

/// got IV from [here](https://en.wikipedia.org/wiki/BLAKE_(hash_function))
fn IV() -> Span<u64> {
    IV_DATA.span()
}

fn rotate_right(value: u64, n: u32) -> u64 {
    if n == 0 {
        value // No rotation needed
    } else {
        let bits = BitSize::<u64>::bits(); // The number of bits in a u64
        let n = n % bits; // Ensure n is less than 64

        let res = value.wrapping_shr(n) | value.wrapping_shl((bits - n));
        res
    }
}

/// compression function: [see](https://datatracker.ietf.org/doc/html/rfc7693#section-3.2)
/// # Parameters
/// * `rounds` - number of rounds for mixing
/// * `h` - state vector
/// * `m` - message block, padded with 0s to full block size
/// * `t` - 2w-bit counter
/// * `f` - final block indicator flag
/// # Returns
/// updated state vector
pub fn compress(rounds: usize, h: Span<u64>, m: Span<u64>, t: Span<u64>, f: bool) -> Span<u64> {
    let mut v = VecTrait::<Felt252Vec, u64>::new();
    for _ in 0..16_u8 {
        v.push(0);
    };

    let IV = IV();

    let mut i = 0;
    loop {
        if (i == h.len()) {
            break;
        }

        v.set(i, *h[i]);
        v.set(i + h.len(), *IV[i]);

        i += 1;
    };

    v.set(12, v[12] ^ *t[0]);
    v.set(13, v[13] ^ *t[1]);

    if f {
        v.set(14, ~v[14]);
    }

    let mut i = 0;
    loop {
        if i == rounds {
            break;
        }

        let s = *(SIGMA()[i % 10]);

        g(ref v, 0, 4, 8, 12, *m[*s[0]], *m[*s[1]]);
        g(ref v, 1, 5, 9, 13, *m[*s[2]], *m[*s[3]]);
        g(ref v, 2, 6, 10, 14, *m[*s[4]], *m[*s[5]]);
        g(ref v, 3, 7, 11, 15, *m[*s[6]], *m[*s[7]]);

        g(ref v, 0, 5, 10, 15, *m[*s[8]], *m[*s[9]]);
        g(ref v, 1, 6, 11, 12, *m[*s[10]], *m[*s[11]]);
        g(ref v, 2, 7, 8, 13, *m[*s[12]], *m[*s[13]]);
        g(ref v, 3, 4, 9, 14, *m[*s[14]], *m[*s[15]]);

        i += 1;
    };

    let mut result: Array<u64> = Default::default();

    let mut i = 0;
    loop {
        if (i == 8) {
            break;
        }

        result.append(*h[i] ^ (v[i] ^ v[i + 8]));

        i += 1;
    };

    result.span()
}


/// Mixing Function G
/// It mixes input words into four words indexed by "a", "b", "c", and "d" in the working vector,
/// see [spec](https://datatracker.ietf.org/doc/html/rfc7693#section-3.1)
///
/// # Parameters
/// * `v` - working vector
/// * `a`- index of word v[a]
/// * `b`- index of word v[b]
/// * `c`- index of word v[c]
/// * `d`- index of word v[d]
/// * `x` - input word x to be used for mixing
/// * `y` - input word y to be used for mixing
fn g(ref v: Felt252Vec<u64>, a: usize, b: usize, c: usize, d: usize, x: u64, y: u64) {
    let mut v_a = v[a];
    let mut v_b = v[b];
    let mut v_c = v[c];
    let mut v_d = v[d];

    let tmp = v_a.wrapping_add(v_b);
    v_a = tmp.wrapping_add(x);
    v_d = rotate_right(v_d ^ v_a, 32);
    v_c = v_c.wrapping_add(v_d);
    v_b = rotate_right(v_b ^ v_c, 24);

    let tmp = v_a.wrapping_add(v_b);
    v_a = tmp.wrapping_add(y);
    v_d = rotate_right(v_d ^ v_a, 16);
    v_c = v_c.wrapping_add(v_d);
    v_b = rotate_right(v_b ^ v_c, 63);

    v.set(a, v_a);
    v.set(b, v_b);
    v.set(c, v_c);
    v.set(d, v_d);
}
