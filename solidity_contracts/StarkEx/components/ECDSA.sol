// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../third_party/EllipticCurve.sol";

library ECDSA {
    using EllipticCurve for uint256;
    uint256 constant FIELD_PRIME =
        0x800000000000011000000000000000000000000000000000000000000000001;
    uint256 constant ALPHA = 1;
    uint256 constant BETA =
        3141592653589793238462643383279502884197169399375105820974944592307816406665;
    uint256 constant EC_ORDER =
        3618502788666131213697322783095070105526743751716087489154079457884512865583;
    uint256 constant N_ELEMENT_BITS_ECDSA = 251;
    uint256 constant EC_GEN_X = 0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca;
    uint256 constant EC_GEN_Y = 0x5668060aa49730b7be4801df46ec62de53ecd11abe43a32873000c36e8dc1f;

    function verify(
        uint256 msgHash,
        uint256 r,
        uint256 s,
        uint256 pubX,
        uint256 pubY
    ) internal pure {
        require(msgHash % EC_ORDER == msgHash, "msgHash out of range");
        require((1 <= s) && (s < EC_ORDER), "s out of range");
        uint256 w = s.invMod(EC_ORDER);
        require((1 <= r) && (r < (1 << N_ELEMENT_BITS_ECDSA)), "r out of range");
        require((1 <= w) && (w < (1 << N_ELEMENT_BITS_ECDSA)), "w out of range");

        // Verify that pub is a valid point (y^2 = x^3 + x + BETA).
        {
            uint256 x3 = mulmod(mulmod(pubX, pubX, FIELD_PRIME), pubX, FIELD_PRIME);
            uint256 y2 = mulmod(pubY, pubY, FIELD_PRIME);
            require(
                y2 == addmod(addmod(x3, pubX, FIELD_PRIME), BETA, FIELD_PRIME),
                "INVALID_STARK_KEY"
            );
        }

        // Verify signature.
        uint256 b_x;
        uint256 b_y;
        {
            (uint256 zG_x, uint256 zG_y) = msgHash.ecMul(EC_GEN_X, EC_GEN_Y, ALPHA, FIELD_PRIME);

            (uint256 rQ_x, uint256 rQ_y) = r.ecMul(pubX, pubY, ALPHA, FIELD_PRIME);

            (b_x, b_y) = zG_x.ecAdd(zG_y, rQ_x, rQ_y, ALPHA, FIELD_PRIME);
        }
        (uint256 res_x, ) = w.ecMul(b_x, b_y, ALPHA, FIELD_PRIME);

        require(res_x == r, "INVALID_STARK_SIGNATURE");
    }
}
