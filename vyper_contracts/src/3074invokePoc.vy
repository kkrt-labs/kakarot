# pragma version ~=0.4.0rc2

from ethereum.ercs import IERC20

# counter to keep track of the number of invokes
counter: public(uint256)

# authorise this contract to spend the tokens on behalf of the user
@external
def autherizeInvoke(sig: Bytes[97]):
    authorize(self, sig)

# invoke the token transfer on behalf of the user
@external
def invoke(token: IERC20, receiver: address, amount: uint256):
    self.counter += 1
    authcall token.approve(receiver, amount)
    authcall token.transfer(receiver, amount)

# add a function that returns a value
@external
def getCounter() -> uint256 :
    return self.counter