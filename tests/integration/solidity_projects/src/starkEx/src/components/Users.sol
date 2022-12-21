// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "./ECDSA.sol";
import "./MainStorage.sol";
import "../libraries/LibConstants.sol";

/**
  Users of the Stark Exchange are identified within the exchange by their Stark Key which is a
  public key defined over a Stark-friendly elliptic curve that is different from the standard
  Ethereum elliptic curve.

  The Stark-friendly elliptic curve used is defined as follows:

  .. math:: y^2 = (x^3 + \alpha \cdot x + \beta) \% p

  where:

  .. math:: \alpha = 1
  .. math:: \beta = 3141592653589793238462643383279502884197169399375105820974944592307816406665
  .. math:: p = 3618502788666131213697322783095070105623107215331596699973092056135872020481

  User registration is the mechanism that associates an Ethereum address with a StarkKey
  within the main contract context.

  User registrations that were done on previous versions (up to v3.0) are still supported.
  However, in most cases, there is no need to register a user.
  The only flows that require user registration are the anti-concorship flows:
  forced actions and deposit cancellation.

  User registration is performed by calling :sol:func:`registerEthAddress` with the selected
  Stark Key, representing an `x` coordinate on the Stark-friendly elliptic curve,
  and the `y` coordinate of the key on the curve (due to the nature of the curve,
  only two such possible `y` coordinates exist).

  The registration is accepted if the following holds:

  1. The key registered is not zero and has not been registered in the past by the user or anyone else.
  2. The key provided represents a valid point on the Stark-friendly elliptic curve.
  3. The linkage between the provided Ethereum address and the selected Stark Key is signed using
     the privte key of the selected Stark Key.

  If the above holds, the Ethereum address is registered by the contract, mapping it to the Stark Key.
*/
abstract contract Users is MainStorage, LibConstants {
    event LogUserRegistered(address ethKey, uint256 starkKey, address sender);

    function isOnCurve(uint256 starkKey) private view returns (bool) {
        uint256 xCubed = mulmod(mulmod(starkKey, starkKey, K_MODULUS), starkKey, K_MODULUS);
        return isQuadraticResidue(addmod(addmod(xCubed, starkKey, K_MODULUS), K_BETA, K_MODULUS));
    }

    function registerSender(uint256 starkKey, bytes calldata starkSignature) external {
        registerEthAddress(msg.sender, starkKey, starkSignature);
    }

    function registerEthAddress(
        address ethKey,
        uint256 starkKey,
        bytes calldata starkSignature
    ) public {
        // Validate keys and availability.
        require(starkKey != 0, "INVALID_STARK_KEY");
        require(starkKey < K_MODULUS, "INVALID_STARK_KEY");
        require(ethKey != ZERO_ADDRESS, "INVALID_ETH_ADDRESS");
        require(ethKeys[starkKey] == ZERO_ADDRESS, "STARK_KEY_UNAVAILABLE");
        require(isOnCurve(starkKey), "INVALID_STARK_KEY");
        require(starkSignature.length == 32 * 3, "INVALID_STARK_SIGNATURE_LENGTH");

        bytes memory sig = starkSignature;
        (uint256 r, uint256 s, uint256 StarkKeyY) = abi.decode(sig, (uint256, uint256, uint256));

        uint256 msgHash = uint256(
            keccak256(abi.encodePacked("UserRegistration:", ethKey, starkKey))
        ) % ECDSA.EC_ORDER;

        ECDSA.verify(msgHash, r, s, starkKey, StarkKeyY);

        // Update state.
        ethKeys[starkKey] = ethKey;

        // Log new user.
        emit LogUserRegistered(ethKey, starkKey, msg.sender);
    }

    function fieldPow(uint256 base, uint256 exponent) internal view returns (uint256) {
        // NOLINTNEXTLINE: low-level-calls reentrancy-events reentrancy-no-eth.
        (bool success, bytes memory returndata) = address(5).staticcall(
            abi.encode(0x20, 0x20, 0x20, base, exponent, K_MODULUS)
        );
        require(success, string(returndata));
        return abi.decode(returndata, (uint256));
    }

    function isQuadraticResidue(uint256 fieldElement) private view returns (bool) {
        return 1 == fieldPow(fieldElement, ((K_MODULUS - 1) / 2));
    }
}
