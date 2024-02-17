**Markdown file 1:** Create a markdown file about what problems ERC777 and ERC1363 solves. Why was ERC1363 introduced, and what issues are there with ERC777?

**Answer**
    
### ERC-20
    
ERC-20 Standard is the most common one currently in use for fungible tokens, not just because it was the first standard being proposed but also because it is quite simple and straight-forward, which makes it easily adoptable and manageable.
But, as we know, limiting the functionality of something on one side is great, because it reduces the chances of bugs and unexpected behaviors, but on the other side doesn’t allow it to be suitable for many use-cases, especially the most complex ones.
    
The main problems with ERC-20 are:
    
- The ability of permanently lose the tokens if they are mistakenly sent to a smart contract address which doesn’t have any function to drain and recover tokens.
- The `transfer()` and `transferFrom()` functions are not able to carry data and thus a smart contract can’t know if it has received an ERC20 token. This would force a sender to make 2 transactions, the first to send the token and the second to actually notify the smart contract and perform the wanted operation (like get something purchased).
- In a scenario in which someone wants to revoke an allowance previously given (for example for a monthly subscription), the person who is seeing his allowance reduced by a transaction currently sitting in the mempool could try to frontun it by spending all the remaining funds.
In a scenario in which someone wants just to increase/reduce the allowance (e.g. from `50` to `10`), this could led to a double-spend, in which first all the remaining allowance is spent (`50`), and then in the block after the transaction got confirmed he will be able to spend the new allowance (`10`), for a total of `60`.
    
For this reason, many new token standards trying to improve and increase ERC-20 functionalities have been proposed in the following years, two of the most attention-worthy are ERC-777 and ERC-1363.
    
### ERC-777
    
ERC-777 introduces a new way to interact with a token contract, while maintaining a backward compatibility with ERC-20.
    
The main upgrades introduced by ERC-777 are:
    
- **Operators:** EOA or smart contracts which can send/burn tokens on behalf of the user who gave them the permission. This enables a more complex authentication scheme which goes beyond the ERC-20 approval system.
- `**send()` function:** ERC-777 while maintaining the `transfer()` function introduces a new `send()` function with an extra `bytes32` parameter called data. This allows to carry data with a token transfer which may contain the instructions for an operation to perform, avoiding the 2 steps required in the case of a regular ERC-20 transfer.
- **Transfer hooks**: **`tokensToSend`** is called on the sender's side before a token transfer occurs. This allows the EOA or smart contract initiating the transfer, to execute logic before the tokens are deducted from their balance. This can include validation checks, logging, or other preparatory steps before the actual transfer.
`**tokensReceived**` is called on the receiver’s side when the tokens have been received but the transaction has not been finalized yet. This can be used to reject tokens or perform specific logic such as update internal accounting etc..
These hooks**,** in order to work, must have been registered by the the contract which is interacting with the ERC-777 token on the **ERC-1820 registry.**
    
Unfortunately, the useful ability of sending/receiving data and trigger other actions allowed ERC-7777 to be subject to reentrancy attacks.
    
### ERC-1363
    
ERC-1363 mitigates some of the problem of ERC-20, while avoiding the over-complexity of ERC-777.
    
- The `transfer()` function in ERC-1363 behaves like a normal ERC-20, thus doesn’t have any reentrancy risk.
- It prevents the token loss if the tokens are sent with `transferAndCall` or `transferFromAndCall` (it is not possible to send tokens to smart contracts without ERC1363 Receiver)
- It allows to executing code on a recipient contract thanks to `transferAndCall` or `transferFromAndCall` functions in a single transaction, thanks to an extra `bytes32` parameter called data.
- It allows to executing code on a spender contract thanks to `approveAndCall` function in a single transaction, thanks to an extra `bytes32` parameter called data.