// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INeoPreemoSale {

    event Purchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    function listArtwork(uint256 _tokenId, string memory _uri, address payable _creator, uint256 _price, uint256 _editions) external;
    function resellArtwork(uint256 _tokenId, uint256 _price) external ;
    function purchase(uint256 _tokenId) external payable;
    function closeSale(uint256 _tokenId) external;
}