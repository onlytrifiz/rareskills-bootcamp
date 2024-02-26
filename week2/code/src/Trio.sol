// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract NFT is ERC721, ERC721Royalty, Ownable2Step {
    uint256 public immutable MAX_SUPPLY;
    bytes32 public immutable merkleRoot;
    BitMaps.BitMap private _airdropList;

    event Withdraw(address addr, uint256 amount);
    event MerkleMint(address addr, uint256 tokenId);

    constructor() ERC721("NonFungibleToken", "NFT") Ownable(msg.sender) {
        _setDefaultRoyalty(address(this), 250);
        MAX_SUPPLY = 1000;
        merkleRoot = 0x897d6714686d83f84e94501e5d6f0f38c94b75381b88d1de3878b4f3d2d5014a;
    }

    function safeMintMerkle(bytes32[] memory proof, uint256 index, address to, uint256 tokenId) external payable {
        require(tokenId > 0 && tokenId <= 1000 && msg.value == 0.5 ether);
        require(!BitMaps.get(_airdropList, index), "Discount already used");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, index))));
        require(MerkleProof.verify(proof, merkleRoot, leaf));
        BitMaps.setTo(_airdropList, index, true);
        _safeMint(to, tokenId);
        emit MerkleMint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) external payable {
        require(tokenId > 0 && tokenId <= 1000 && msg.value == 1 ether);

        _safeMint(to, tokenId);
    }

    function withdrawEthers() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent,) = owner().call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit Withdraw(owner(), amount);
    }

    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

contract Token is ERC20 {
    mapping(address => bool) public minter;

    constructor() ERC20("Token", "TKN") {
        minter[msg.sender] = true;
    }

    function mint(address account, uint256 value) external {
        require(minter[msg.sender]);
        _mint(account, value);
    }
}

contract Staking is IERC721Receiver {
    NFT public nft;
    Token public token;
    uint256 public lastUpdateTime;
    uint256 public accRewardPerToken;
    uint256 public tokenPerSecond = 11574000000000;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 tokenId;
    }

    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed addr, uint256 tokenId);
    event Claim(address indexed addr, uint256 amount);
    event Withdraw(address indexed addr, uint256 tokenId);

    constructor(NFT _nft) {
        nft = _nft;
        token = new Token();
    }

    function deposit(address from, uint256 tokenId) external {
        require(userInfo[from].amount == 0); // added after meeting

        nft.safeTransferFrom(from, address(this), tokenId);
    }

    function _deposit(address from, uint256 tokenId) internal {
        accRewardPerToken += (block.timestamp - lastUpdateTime) * tokenPerSecond;
        lastUpdateTime = block.timestamp;

        userInfo[from].amount += 1;
        userInfo[from].rewardDebt += accRewardPerToken;
        userInfo[from].tokenId = tokenId;
        emit Deposit(from, tokenId);
    }

    function claim() public {
        accRewardPerToken += (block.timestamp - lastUpdateTime) * tokenPerSecond;
        lastUpdateTime = block.timestamp;

        uint256 newRewardDebt = accRewardPerToken * userInfo[msg.sender].amount;
        uint256 reward = newRewardDebt - userInfo[msg.sender].rewardDebt;
        userInfo[msg.sender].rewardDebt = newRewardDebt;

        token.mint(msg.sender, reward);
        emit Claim(msg.sender, reward);
    }

    function withdraw(uint256 tokenId) external {
        require(tokenId == userInfo[msg.sender].tokenId);
        claim();

        userInfo[msg.sender].amount -= 1;
        userInfo[msg.sender].rewardDebt = accRewardPerToken * userInfo[msg.sender].amount;
        userInfo[msg.sender].tokenId = 0;

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit Withdraw(msg.sender, tokenId);
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        require(msg.sender == address(nft));  // added after meeting  
        _deposit(from, tokenId);

        return this.onERC721Received.selector;
    }
}
