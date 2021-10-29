// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./access/Ownable.sol";
import "./utils/SafeMath.sol";
import "./tokens/NeoPreemo.sol";
import "./NeoPreemoBase.sol";
import "./INeoPreemoSale.sol";


contract NeoPreemoSale is NeoPreemoBase, INeoPreemoSale {
    using SafeMath for uint256;

    struct Sale {
        SaleType saleType;
        SaleStatus status;
        address payable owner;
        address payable creator;
        uint256 price;
        uint256 platformCommission;
        uint256 creatorCommission;
        address payable buyer;
        uint256 maxEdition;
        uint256 mintedEdition;
    }

    // Mapping of Token Id to current Sale struct, resell will empty existing sale struct
    mapping(uint256 => Sale) tokenCurrentSale;

    constructor(address _tokenContract, address _platformwallet) NeoPreemoBase(_tokenContract, _platformwallet){
    }

    modifier saleExist(uint256 tokenId) {
        require(tokenCurrentSale[tokenId].owner != address(0), "NeoPreemoSale: Sale does not exist");
        _;
    }

     modifier onlyTokenOwner(uint256 tokenId) {
        require(tokenCurrentSale[tokenId].owner == _msgSender(), "NeoPreemoSale: caller is not the toke owner");
        _;
    }

    modifier saleIsOpen(uint256 tokenId) {
        require(tokenCurrentSale[tokenId].status == SaleStatus.FORSALE, "NeoPreemoSale: Sale is not open");
        _;
    }

    // Check if the sale exist on this contract, not if the token exist on token contract
    function _exists(uint256 tokenId) internal view override virtual returns (bool) {
        return tokenDetails[tokenId].tokenCreator != address(0);
    }

    function tokenURI(uint256 _tokenId) public view override saleExist(_tokenId) returns (string memory) {
        return tokenDetails[_tokenId].tokenUri;
    }

    function price(uint256 _tokenId) public view override saleExist(_tokenId) returns (uint256) {
        return tokenCurrentSale[_tokenId].price;
    }

    function buyer(uint256 _tokenId) public view override saleExist(_tokenId) returns (address) {
        return tokenCurrentSale[_tokenId].buyer;
    }

    function status(uint256 _tokenId) public view saleExist(_tokenId) returns (SaleStatus) {
        return tokenCurrentSale[_tokenId].status;
    }

    function saleType(uint256 _tokenId) public view override saleExist(_tokenId) returns (SaleType) {
        return tokenCurrentSale[_tokenId].saleType;
    }

    function mintedEdition(uint256 _tokenId) public view saleExist(_tokenId) returns (uint256) {
        return tokenCurrentSale[_tokenId].mintedEdition;
    }

    function setPrice(uint256 _tokenId, uint256 _price) public override saleExist(_tokenId) saleIsOpen(_tokenId) onlyTokenOwner(_tokenId) {
        require(_price > 0, "NeoPreemoSale: price cannot set to 0");
        tokenCurrentSale[_tokenId].price = _price;
        emit SetPrice(_tokenId, _price, _msgSender());
    }

    function listArtwork(uint256 _tokenId, string memory _uri, address payable _creator, uint256 _price, uint256 _editions) public override onlyOwner {
        require(!_isTokenMinted(_tokenId) && !_exists(_tokenId), "NeoPreemoSale: token already minted or listed");
        _createSale(_tokenId, _uri, _creator, _creator, _price, SaleType.INITIAL, _editions);
    }

    function resellArtwork(uint256 _tokenId, uint256 _price) public override{
        require(_isTokenMinted(_tokenId), "NeoPreemoSale: token not minted");
        require(NeoPreemo(tokenContract).getApproved(_tokenId) == address(this), "NeoPreemoSale: token not approved for sale");
        
        address payable creator = payable(NeoPreemo(tokenContract).creatorOf(_tokenId));
        address payable tokenOwner = payable(NeoPreemo(tokenContract).ownerOf(_tokenId));

        require(tokenOwner == _msgSender(), "NeoPreemoSale: caller not the token owner");
        string memory uri = NeoPreemo(tokenContract).tokenURI(_tokenId);
        _createSale(_tokenId, uri, tokenOwner, creator, _price, SaleType.RESELL, 1);
    }

    function _createSale(uint256 _tokenId, string memory _uri, address payable _owner, address payable _creator,  uint256 _price, SaleType _type, uint256 _editions) private {
        require(_creator != address(0), "NeoPreemoAuction: token owner address cannot be 0");
        require(_price > 0, "NeoPreemoSale: price cannot set to 0");
        require(_editions > 0 && _editions < 10000, "NeoPreemoSale: number of editions should between 1 and 9999");
        tokenDetails[_tokenId].tokenUri = _uri;
        tokenDetails[_tokenId].tokenCreator = _creator;
        tokenCurrentSale[_tokenId] = Sale(_type, SaleStatus.FORSALE, _owner, _creator, _price, 0, 0, payable(address(0)), _editions, 0);
        if(_type == SaleType.INITIAL) {
            emit ArtworkListed(_tokenId, _uri, _creator, _price);
        } else {
            emit ResellCreated(_tokenId, _uri, _owner, _price);
        }
    }

    function purchase(uint256 _tokenId) public override payable saleExist(_tokenId) saleIsOpen(_tokenId) {
        Sale storage tmpSale = tokenCurrentSale[_tokenId];
        require(msg.value >= tmpSale.price, "NeoPreemoSale: insuficient ether value sent");
        require(_msgSender() != tmpSale.owner, "Buyer is the same as the owner");

        // payout logic
        tmpSale.buyer = payable(_msgSender());
        if(tmpSale.saleType == SaleType.RESELL) {
            tmpSale.platformCommission = msg.value.mul(resellRate).div(100);
            tmpSale.creatorCommission = msg.value.mul(_getTokenResellRate(_tokenId)).div(100);
            tmpSale.creator.transfer(tmpSale.creatorCommission);
        } else {
            tmpSale.platformCommission = msg.value.mul(initialRate).div(100);
        }
        platformWallet.transfer(tmpSale.platformCommission);
        tmpSale.owner.transfer(msg.value.sub(tmpSale.platformCommission).sub(tmpSale.creatorCommission));

        uint256 tokenEditionId = _tokenId;
        
        if(tmpSale.saleType == SaleType.INITIAL) {
            if(tmpSale.maxEdition > 1) {
                tmpSale.mintedEdition = tmpSale.mintedEdition.add(1);
                tokenEditionId = _tokenId.mul(10000).add(tmpSale.mintedEdition);
                if(tmpSale.mintedEdition == tmpSale.maxEdition) {
                    tmpSale.status = SaleStatus.SOLD;
                }
            } else {
                tmpSale.status = SaleStatus.SOLD;
            }
            if(tmpSale.mintedEdition == 1) {
                _mintToken(_tokenId, tokenEditionId, true);
            } else {
                _mintToken(_tokenId, tokenEditionId, false);
            }
            
        } else {
            NeoPreemo(tokenContract).transferFrom(tmpSale.owner, _msgSender(), _tokenId);
        }

        emit Purchased(tokenEditionId, _msgSender(), msg.value);
    }

    function _mintToken(uint256 _artworkId, uint256 _tokenEditionId, bool _isOriginal) private {
        // Mint Logic
        Sale storage tmpSale = tokenCurrentSale[_artworkId];
        NeoPreemo(tokenContract).createTokenForEdition(_tokenEditionId, tokenDetails[_artworkId].tokenUri, tmpSale.owner, tmpSale.buyer, _isOriginal, creatorRate);
    }

    function closeSale(uint256 _tokenId) public override saleExist(_tokenId) saleIsOpen(_tokenId){
        require( tokenCurrentSale[_tokenId].owner == _msgSender() || owner() == _msgSender(), "NeoPreemoSale: caller is not the owner.");
        tokenCurrentSale[_tokenId].status = SaleStatus.CLOSED;
        emit Withdraw(_tokenId);
    }

}