// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./access/Ownable.sol";
import "./utils/SafeMath.sol";
import "./tokens/NeoPreemo.sol";
import "./INeoPreemoBase.sol";


abstract contract NeoPreemoBase  is INeoPreemoBase, Ownable {

    address tokenContract;

    address payable platformWallet;

    uint initialRate;

    uint resellRate;

    uint creatorRate;

    struct TokenDetail {
        string tokenUri;
        address tokenCreator;
    }

    mapping(uint256 => TokenDetail) tokenDetails;

    constructor(address _tokenContract, address _platformwallet) {
        tokenContract = _tokenContract;
        platformWallet = payable(_platformwallet);
        initialRate = 20;
        creatorRate = 10;
        resellRate = 5;
    }


    function _isTokenMinted(uint256 tokenId) internal view returns (bool) {
        return NeoPreemo(tokenContract).exists(tokenId);
    }

    // Check if the sale exist on this contract, not if the token exist on token contract
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return tokenDetails[tokenId].tokenCreator != address(0);
    }

    function tokenURI(uint256 _tokenId) public view override virtual returns (string memory) {
        return tokenDetails[_tokenId].tokenUri;
    }

    function setCreatorCommission(uint256 _percentage)  public override onlyOwner {
        creatorRate = _percentage;
        emit SetCommission(creatorRate);
    }

    function getCreatorCommission() public view override returns (uint) {
        return creatorRate;
    }

    function _getTokenResellRate(uint256 _tokenId) internal virtual view returns (uint256) {
        return NeoPreemo(tokenContract).tokenSellRate(_tokenId);
    }

    function setPlatformWallet(address payable _platformWallet) public override onlyOwner {
        platformWallet = _platformWallet;
        emit SetPlatformWallet(platformWallet);
    }

}