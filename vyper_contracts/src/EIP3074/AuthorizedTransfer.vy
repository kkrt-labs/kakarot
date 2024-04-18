# pragma version ~=0.4.0rc2

from ethereum.ercs import IERC20

# counter to keep track of the number of invokes
counter: public(uint256)

# authorise this contract to spend the tokens on behalf of the user
@external
def authorizeInvoke(sender: address, sig: Bytes[97], token: IERC20, receiver: address, amount: uint256):
    self.counter += 1
    authorize(sender, sig)
    authcall token.approve(receiver, amount)
    authcall token.transfer(receiver, amount)
