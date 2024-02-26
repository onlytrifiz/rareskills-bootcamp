##### Revisit the solidity events tutorial. How can OpenSea quickly determine which NFTs an address owns if most NFTs don’t use ERC721 enumerable? Explain how you would accomplish this if you were creating an NFT marketplace

Everytime an ERC721 is transferred (including mints and burns) it emits a Transfer event:
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
Given that all the parameters are indexed, it quite easy to query the blockchain and understand who is holding which NFT, or counting how many NFTs are currently held by an address.

If I was creating a NFT marketplace, I could accomplish this simply by listening the events and building an off-chain database to quickly retrieve any information, avoiding to query the blockchain multiple times per second.
