
INTRO
Ethereum Virtual Machine (EVM) lies at the heart of every Ethereum activity.
You can see it as the Operating System (OS) of Ethereum. But, as you don’t need to know how an OS works to use your laptop, you don’t need to know how EVM works to use Ethereum. That is surely why you’re reading this. 

Kakarot is an implementation of the EVM in Starknet.

The TL;DR
The reason Ethereum Protocol exists is to maintain the Ethereum Virtual Machine. It is hard to imagine the future of Starknet without its own implementation of EVM, this is why we are building it.
Here it is what every Ethereum user should kn
EVM is a stack-based Virtual Machine that executes bytecode.
Executing bytecode costs Gas. If you want, you technically can know how much Gas is needed by splitting the bytecode that will be executed into operations and adding the cost of all those operations (see https://ethereum.org/en/developers/docs/evm/opcodes).

DEEP DIVE:
If you want to deepdive into the subject here are some resources you may like:
https://takenobu-hs.github.io/downloads/ethereum_evm_illustrated.pdf
https://ethereum.org/en/developers/docs/evm
https://ethereum.org/en/developers/tutorials/yellow-paper-evm/#942-exceptional-halt
