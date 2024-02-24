// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {NFT, Token, Staking} from "src/Trio.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract TrioTest is Test, IERC721Receiver {
    NFT public nft;
    Token public token;
    Staking public staking;
    bytes32[] public merkleProof;

    function setUp() public {
        nft = new NFT();
        staking = new Staking(nft);
        token = Token(staking.token());

        merkleProof.push(0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c);
        merkleProof.push(0x8138140fea4d27ef447a72f4fcbc1ebb518cca612ea0d392b695ead7f8c99ae6);
        merkleProof.push(0x9005e06090901cdd6ef7853ac407a641787c28a78cb6327999fc51219ba3c880);
    }

    // -----------------------------
    // NFT TESTS
    // -----------------------------

    function testNFTSafeMint() public {
        nft.safeMint{value: 1 ether}(address(this), 1);
        assertEq(nft.balanceOf(address(this)), 1);
        assertEq(nft.ownerOf(1), address(this));
        assertEq(address(nft).balance, 1 ether);
    }

    function testNFTSafeMintMerkle() public {
        deal(0x0000000000000000000000000000000000000001, 1 ether);
        vm.prank(0x0000000000000000000000000000000000000001);
        nft.safeMintMerkle{value: 0.5 ether}(merkleProof, 0, 0x0000000000000000000000000000000000000001, 2);
        assertEq(nft.balanceOf(0x0000000000000000000000000000000000000001), 1);
        assertEq(nft.ownerOf(2), 0x0000000000000000000000000000000000000001);
    }

    function testNFTSafeMintMerkleAgain() public {
        testNFTSafeMintMerkle();
        vm.expectRevert("Discount already used");
        testNFTSafeMintMerkle();
    }

    function testWithdrawEthers() public {
        testNFTSafeMint();
        uint256 nftBalance = address(nft).balance;
        uint256 oldBalance = address(this).balance;
        nft.withdrawEthers();
        assertEq(nftBalance, address(this).balance - oldBalance);
    }

    // -----------------------------
    // TOKEN TESTS
    // -----------------------------

    function testTokenMint() public {
        vm.prank(address(staking));
        token.mint(address(this), 1 ether);
        assertEq(token.balanceOf(address(this)), 1 ether);
    }

    // -----------------------------
    // STAKING TESTS
    // -----------------------------

    function testDeposit() public {
        // block.timestamp = 1
        testNFTSafeMint();
        nft.approve(address(staking), 1);
        staking.deposit(address(this), 1);

        (uint256 amount, uint256 rewardDebt, uint256 tokenId) = staking.userInfo(address(this));
        assertEq(amount, 1);
        assertEq(rewardDebt, block.timestamp * staking.tokenPerSecond());
        assertEq(tokenId, 1);
    }

    function testClaim1User() public {
        testDeposit();

        skip(4); // block.timestamp = 5
        staking.claim();

        assertEq(staking.accRewardPerToken(), 5 * staking.tokenPerSecond());
        assertEq(token.balanceOf(address(this)), 4 * staking.tokenPerSecond());
    }

    function test2ndDeposit() public {
        testDeposit();
        testNFTSafeMintMerkle();

        skip(4); // block.timestamp = 5
        vm.startPrank(0x0000000000000000000000000000000000000001);
        nft.approve(address(staking), 2);
        staking.deposit(0x0000000000000000000000000000000000000001, 2);
        vm.stopPrank();

        (, uint256 rewardDebt, uint256 tokenId) = staking.userInfo(0x0000000000000000000000000000000000000001);
        assertEq(rewardDebt, block.timestamp * staking.tokenPerSecond());
        assertEq(tokenId, 2);
    }

    function testDoubleClaim() public {
        test2ndDeposit();

        skip(5); // block.timestamp = 10

        // 1st user claim
        staking.claim();
        assertEq(staking.accRewardPerToken(), 10 * staking.tokenPerSecond());

        (, uint256 rewardDebt, uint256 tokenId) = staking.userInfo(address(this));
        assertEq(rewardDebt, block.timestamp * staking.tokenPerSecond());
        assertEq(token.balanceOf(address(this)), 9 * staking.tokenPerSecond());

        // 2nd user claim
        vm.startPrank(0x0000000000000000000000000000000000000001);
        staking.claim();
        (, rewardDebt, tokenId) = staking.userInfo(0x0000000000000000000000000000000000000001);
        assertEq(rewardDebt, block.timestamp * staking.tokenPerSecond());
        assertEq(token.balanceOf(0x0000000000000000000000000000000000000001), 5 * staking.tokenPerSecond());
    }

    function testNFTWithdraw() public {
        test2ndDeposit();

        // block.timestamp = 5
        staking.withdraw(1);
        (uint256 amount,, uint256 tokenId) = staking.userInfo(address(this));
        assertEq(amount, 0);
        assertEq(tokenId, 0);
    }

    // -----------------------------
    // FALLBACK & RECEIVER
    // -----------------------------

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
