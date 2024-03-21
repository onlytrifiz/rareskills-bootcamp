- ~~Use safeTransferFrom to ensure safety~~
- Add deadlines to safe functions

###### \_update function
- ~~Overflow needed in the sums on L117~~

###### safeMint function
- ~~\_update wrong parameters~~

###### safeBurn function
- ~~Burn directly the tokens instaed of transfering them to pair and then burn~~

###### flashLoan function
- ~~Fee amount is 99.9%~~
- ~~Keccak hashing should be a constant to save gas~~
- K safety check missing 
- ~~Add nonReentrant modifier~~
- Remove transferFrom and allow more flexibility about repaying back the loan