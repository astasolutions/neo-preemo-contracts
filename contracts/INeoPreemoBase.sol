// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INeoPreemoBase {

    enum SaleStatus{ DEFAULT, FORSALE, SOLD, CLOSED }
    enum SaleType { INITIAL, RESELL }

    event ArtworkListed(uint256 indexed tokenId, string uri, address indexed creator, uint256 price);
    event ResellCreated(uint256 indexed tokenId, string uri, address indexed owner, uint256 price);
    event SetPrice(uint256 indexed tokenId, uint256 price, address indexed creator);
    event Withdraw(uint256 indexed tokenId);
    event SetCommission(uint256 commission);
    event SetPlatformWallet(address platformWallet);

    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function price(uint256 _tokenId) external view returns (uint256);
    function buyer(uint256 _tokenId) external view returns (address);
    function saleType(uint256 _tokenId) external view returns (SaleType);
    function setCreatorCommission(uint256 _percentage) external;
    function getCreatorCommission() external view returns (uint);
    function setPrice(uint256 _tokenId, uint256 _price) external;
    function setPlatformWallet(address payable _platformWallet) external;
}