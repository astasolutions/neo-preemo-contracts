// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INeoPreemoAuction {
    event Bid(address indexed _bidder, uint256 indexed _amount, uint256 indexed _tokenId);
    event AcceptBid(address indexed _bidder, address indexed _seller, uint256 _amount, uint256 indexed _tokenId);
    
    function listArtwork(uint256 _tokenId, string memory _uri, address payable _creator, uint256 _price) external ;
    function resellArtwork(uint256 _tokenId, uint256 _price) external ;
    function bid(uint256 _tokenId) external payable;
    function acceptBid(uint256 _tokenId) external;
    function closeAuction(uint256 _tokenId) external;
    function startingPrice(uint256 _tokenId) external view returns(uint256);
}