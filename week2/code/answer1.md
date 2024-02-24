##### Answer these questions How does ERC721A save gas? Where does it add cost?

**Optimization 1 - Removing duplicate storage from OpenZeppelin’s (OZ) ERC721Enumerable**

IERC721Enumerable includes redundant storage of each token’s metadata, this approach is optimized for read functions at a significant cost to write functions, which isn’t ideal given that users are much less likely to pay for read functions.

ERC721A removes this duplicate storage and tokens are serially numbered starting from 0 allows to remove some redundant storage from the base implementation and save gas on write functions, while adding a bit of cost for read functions.

**Optimization 2 - Updating the owner’s balance once per batch mint request, instead of per minted NFT**

ERC721 update the storage value balanceOf per each NFT minted, doesn't matter if multiple NFTs are minted in a single transaction, the storage variable is going to be accessed and changed one time per NFT.
So if Alice purchases 3 tokens, the value is updated 3 times (once per additional token, from 0 to 1, 1 to 2, 2 to 3).

ERC721A approach optimizes this by updating the variable just one time, at the end of the minting, instead of updating it for every single token minted.
If Alice purchases 3 tokens as in the previous scenario, the value is updated 1 time only (from 0 to 3).

**Optimization 3 - updating the owner data once per batch mint request, instead of per minted NFT**

Similar to the previous case, if there is a multiple mint in a single transaction ERC721 is going to access and update the ownerOf mapping for every single NFT minted.
So if Alice buys 3 tokens, Alice is set 3 times as the owner (each time costing us gas).

ERC721A saves the owner value just once in a way that semantically implies that Alice owns all 3 of those tokens.
If Alice mints tokens #100 and #101 and then Bob mints tokens #103. The internal owner tracker would look like this:
[100 = Alice, 101 = not set, 103 = Bob], implying that tokens with a non set owner are owned by the nearest left owner.
