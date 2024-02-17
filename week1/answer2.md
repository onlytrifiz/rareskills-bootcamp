**Markdown file 2:** Why does the SafeERC20 program exist and when should it be used?

**Answer**
    
As explained in the previous answer, the ERC-20 has several potential issues, that we could summarize with:
    
- The ability of permanently lose the tokens if they are mistakenly sent to a smart contract address.
- The `transfer()` and transferFrom() functions are not able to carry data and don’t revert.
- The `approve()` function design could led to a race-condition in which the spender try to front-run the approval transaction and double-spend the allowance.
    
A mitigation to all the above issues could be the usage of SafeERC20:
    
- Thanks to `safeIncreaseAllowance()` and `safeDecreaseAllowance()` can prevent double-spend attempts from malicious actors.
- `safeTransfer()` and `safeTransferFrom()` are able to revert if the returned boolean value is false or if it cannot be interpreted as a valid boolean. In addition they are able handle cases in which tokens with a special behaviour don’t return any value, by interpreting non-reverting calls as successful.
- `forceApprove()` is compatible with tokens which implement a special behaviour such as USDT, which requires the allowance to be set to 0 before being changed. It checks if the token returns a boolean value and if not, it uses a fallback in which it first resets the allowance to zero and then sets it to the new value.
- Thanks to `transferAndCallRelaxed()`, `transferFromAndCallRelaxed()` and `approveAndCallRelaxed()` can leverage the benefits of ERC-1363 while maintaining the flexibility of the regular ERC-20 functions thanks to a fallback used in the case in which the recipient is an EOA.