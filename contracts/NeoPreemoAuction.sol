// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./access/Ownable.sol";
import "./utils/SafeMath.sol";
import "./tokens/NeoPreemo.sol";
import "./NeoPreemoBase.sol";
import "./INeoPreemoAuction.sol";


contract NeoPreemoAuction is NeoPreemoBase, INeoPreemoAuction {

    using SafeMath for uint256;

    enum AuctionStatus{ DEFAULT, FORAUCTION, SOLD, MINTED, CLOSED }

    struct Auction {
        SaleType auctionType;
        AuctionStatus status;
        address payable owner;
        address payable creator;
        uint256 startingPrice;
        uint256 currentBidPrice;
        uint256 platformCommission;
        uint256 creatorCommission;
        address payable currentBuyer;
    }

    // Mapping of Token Id to current Auction struct, resell will empty existing auction struct
    mapping(uint256 => Auction) tokenCurrentAuction;

    constructor(address _tokenContract, address _platformwallet)  NeoPreemoBase(_tokenContract, _platformwallet) {
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(tokenCurrentAuction[tokenId].owner == _msgSender(), "NeoPreemoAuction: caller is not the toke owner");
        _;
    }

    modifier auctionExist(uint256 tokenId) {
        require(tokenCurrentAuction[tokenId].owner != address(0), "NeoPreemoAuction: Auction does not exist");
        _;
    }

    modifier auctionIsOpen(uint256 tokenId) {
        require(tokenCurrentAuction[tokenId].status == AuctionStatus.FORAUCTION, "NeoPreemoAuction: Auction is not open");
        _;
    }

    function _exists(uint256 tokenId) internal view override virtual returns (bool) {
        return tokenDetails[tokenId].tokenCreator != address(0);
    }

    function tokenURI(uint256 _tokenId) public view override auctionExist(_tokenId) returns (string memory) {
        return tokenDetails[_tokenId].tokenUri;
    }

    function price(uint256 _tokenId) public view override auctionExist(_tokenId) returns (uint256) {
        return tokenCurrentAuction[_tokenId].currentBidPrice;
    }

    function buyer(uint256 _tokenId) public view override auctionExist(_tokenId) returns (address) {
        return tokenCurrentAuction[_tokenId].currentBuyer;
    }

    function status(uint256 _tokenId) public view auctionExist(_tokenId) returns (AuctionStatus) {
        return tokenCurrentAuction[_tokenId].status;
    }

    function startingPrice(uint256 _tokenId) external override view returns(uint256){
        return tokenCurrentAuction[_tokenId].startingPrice;
    }

    function saleType(uint256 _tokenId) public view override auctionExist(_tokenId) returns (SaleType) {
        return tokenCurrentAuction[_tokenId].auctionType;
    }

    function setPrice(uint256 _tokenId, uint256 _price) public override auctionExist(_tokenId) auctionIsOpen(_tokenId) onlyTokenOwner(_tokenId) {
        require(tokenCurrentAuction[_tokenId].currentBuyer == address(0), "NeoPreemoAuction: Bid started, price cannot be changed");
        tokenCurrentAuction[_tokenId].startingPrice = _price;
        emit SetPrice(_tokenId, _price, _msgSender());
    }

    function listArtwork(uint256 _tokenId, string memory _uri, address payable _creator, uint256 _price) public override onlyOwner {
        require(!_isTokenMinted(_tokenId) && !_exists(_tokenId), "NeoPreemoAuction: token already minted or listed");
        _createAuction(_tokenId, _uri, _creator, _creator, _price, SaleType.INITIAL);
    }

    function resellArtwork(uint256 _tokenId, uint256 _price) public override{
        require(_isTokenMinted(_tokenId), "NeoPreemoAuction: token not minted");
        require(NeoPreemo(tokenContract).getApproved(_tokenId) == address(this), "NeoPreemoAuction: token not approved for auction");
        address payable creator = payable(NeoPreemo(tokenContract).creatorOf(_tokenId));
        address payable tokenOwner = payable(NeoPreemo(tokenContract).ownerOf(_tokenId));
        require(tokenOwner == _msgSender(), "NeoPreemoAuction: caller not the token owner");
        string memory uri = NeoPreemo(tokenContract).tokenURI(_tokenId);
        _createAuction(_tokenId, uri, creator, tokenOwner, _price, SaleType.RESELL);
    }

    function _createAuction(uint256 _tokenId, string memory _uri, address payable _creator, address payable _owner, uint256 _price, SaleType _type) private {
        require(_creator != address(0), "NeoPreemoAuction: token owner address cannot be 0");
        require(_price > 0, "NeoPreemoSale: price cannot set to 0");
        tokenDetails[_tokenId].tokenUri = _uri;
        tokenDetails[_tokenId].tokenCreator = _creator;
        tokenCurrentAuction[_tokenId] = Auction(_type, AuctionStatus.FORAUCTION, _owner, _creator, _price, 0, 0, 0, payable(address(0)));
        if(_type == SaleType.INITIAL) {
            emit ArtworkListed(_tokenId, _uri, _creator, _price);
        } else {
            emit ResellCreated(_tokenId, _uri, _owner, _price);
        }
    }

    function isValidBid(uint256 _tokenId) private view returns (bool) {
        return msg.value >= tokenCurrentAuction[_tokenId].startingPrice && msg.value > tokenCurrentAuction[_tokenId].currentBidPrice;
    }

    function bid(uint256 _tokenId) public override payable auctionExist(_tokenId) auctionIsOpen(_tokenId) {
        require(isValidBid(_tokenId), "Invalid Ether amount sent.");
        Auction storage tmpAuction = tokenCurrentAuction[_tokenId];
        require(_msgSender() != tmpAuction.owner, "Buyer is the same as the owner");
        tmpAuction.currentBidPrice = msg.value;
        tmpAuction.currentBuyer = payable(_msgSender());

        if(tmpAuction.currentBuyer != address(0)) {
            tmpAuction.currentBuyer.transfer(tmpAuction.currentBidPrice);
        }

        emit Bid(msg.sender, msg.value, _tokenId); 
    }

    function acceptBid(uint256 _tokenId) public override auctionExist(_tokenId) auctionIsOpen(_tokenId) onlyOwner{
        Auction storage tmpAuction = tokenCurrentAuction[_tokenId];
        
        // payout logic
        if(tmpAuction.currentBuyer != address(0) && tmpAuction.currentBidPrice != 0) {
             // transfer resell commission for the artist
            if(tmpAuction.auctionType == SaleType.RESELL) {
                tmpAuction.platformCommission = tmpAuction.currentBidPrice.mul(resellRate).div(100);
                tmpAuction.creatorCommission = tmpAuction.currentBidPrice.mul(_getTokenResellRate(_tokenId)).div(100);
                tmpAuction.creator.transfer(tmpAuction.creatorCommission);
            } else {
                tmpAuction.platformCommission = tmpAuction.currentBidPrice.mul(initialRate).div(100);
            }
           
            platformWallet.transfer(tmpAuction.platformCommission);
            tmpAuction.owner.transfer(tmpAuction.currentBidPrice.sub(tmpAuction.platformCommission).sub(tmpAuction.creatorCommission));
            tmpAuction.status = AuctionStatus.SOLD;
        } else {
            tmpAuction.status = AuctionStatus.CLOSED;
        }
        
        // Mint token
        if(tmpAuction.auctionType == SaleType.INITIAL) {
            _mintToken(_tokenId);
        } else {
            NeoPreemo(tokenContract).transferFrom(tmpAuction.owner, tmpAuction.currentBuyer, _tokenId);
        }

        emit AcceptBid(tmpAuction.currentBuyer, tmpAuction.owner, tmpAuction.currentBidPrice, _tokenId);
    }

    function _mintToken(uint256 _tokenId) private {
        Auction storage tmpAuction = tokenCurrentAuction[_tokenId];
        NeoPreemo(tokenContract).createTokenFor(_tokenId, tokenDetails[_tokenId].tokenUri, tmpAuction.owner, tmpAuction.currentBuyer, creatorRate);
        tokenCurrentAuction[_tokenId].status = AuctionStatus.MINTED;
    }

    function closeAuction(uint256 _tokenId) public override auctionExist(_tokenId) auctionIsOpen(_tokenId) onlyTokenOwner(_tokenId){
        require(tokenCurrentAuction[_tokenId].currentBuyer == address(0), "NeoPreemoAuction: Bid started, price cannot be changed");
        tokenCurrentAuction[_tokenId].status = AuctionStatus.CLOSED;
        emit Withdraw(_tokenId);
    }
}