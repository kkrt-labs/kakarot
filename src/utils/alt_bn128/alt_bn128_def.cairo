// SPDX-License-Identifier: MIT

%lang starknet

// Basic definitions for the alt_bn128 elliptic curve.
// The curve is given by the equation
//   y^2 = x^3 + 3
// over the field Z/p for
// p = p(u) = 36u^4 + 36u^3 + 24u^2 + 6u + 1
// const p = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47
const P0 = 0x31ca8d3c208c16d87cfd47;
const P1 = 0x16da060561765e05aa45a1;
const P2 = 0x30644e72e131a029b8504;

// The following constants represent the size of the curve:
// n = n(u) = 36u^4 + 36u^3 + 18u^2 + 6u + 1
// const n = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001
const N0 = 0x39709143e1f593f0000001;
const N1 = 0x16da06056174a0cfa121e6;
const N2 = 0x30644e72e131a029b8504;
