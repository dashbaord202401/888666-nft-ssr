// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./NFT.sol";

contract Market is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemsIds;
    Counters.Counter private  _itemsSold;
    Counters.Counter private  _itemsDeleted;

    // owner of the marketplace
    address payable owner;
    // price for putting something to sale in the Marketplace
    uint256 listingPrice = 0.001 ether;

    constructor() {
        owner = payable(msg.sender);
    }

    /* Returns the listing price of the contract */
    // function getListingPrice() public view returns (uint256) {
    //   return listingPrice;
    // }

    struct MarketItem {
        uint256 itemId;
        address NFTContract;
        uint256 tokenId;
        address payable creator;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address creator,
        address seller,
        address owner,
        uint256 price
    );

    event ProductUpdated (
        uint256 indexed itemId,
        uint256 indexed oldPrice,
        uint256 indexed newPrice
    );

    event MarketItemDeleted(uint256 itemId);

    event ProductSold(
        uint256 indexed itemId,
        address indexed NFTContract,
        uint256 indexed tokenId,
        address creator,
        address seller,
        address owner,
        uint256 price
    );

    event ProductListed(
        uint256 indexed itemId
    );

    modifier onlyProductOrMarketPlaceOwner(uint256 id) {
        if (idToMarketItem[id].owner != address(0)) {
            require(idToMarketItem[id].owner == msg.sender);
        } else {
            require(idToMarketItem[id].owner == msg.sender || msg.sender == owner);
        }
        _;
    }

    modifier onlyProductSeller(uint256 id) {
        require(idToMarketItem[id].owner == address(0) && idToMarketItem[id].seller == msg.sender, "Only the product can do this operation");
        _;
    }

    modifier  onlyItemOwner(uint256 id) {
        require(idToMarketItem[id].owner == msg.sender,  "Only product owner can do this operation");
        _;
    }

    function getListingPrice () public view returns (uint256) {
        return listingPrice;
    }

    function createMarketItem(address NFTContract, uint256 tokenId, uint256 price) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Listing fee required");

        _itemsIds.increment();
        uint256 itemId = _itemsIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            NFTContract,
            tokenId,
            payable (msg.sender),
            payable (msg.sender),
            payable (address(0)),
            price,
            false
        );

        IERC721(NFTContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            NFTContract,
            tokenId,
            msg.sender,
            msg.sender,
            address(0),
            price
        );
    }

    function updateMarketItemPrice(uint256 id, uint256 newPrice) public payable nonReentrant {
        MarketItem storage item = idToMarketItem[id];

        uint256 oldPrice = item.price;
        item.price = newPrice;

        emit ProductUpdated(id, oldPrice, newPrice);
    }

    function createMarketSale(address NFTContract, uint256 id) public payable nonReentrant {
        
        uint256 price = idToMarketItem[id].price;
        uint256 tokenId = idToMarketItem[id].tokenId;

        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        idToMarketItem[id].seller.transfer(msg.value);
        IERC721(NFTContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[id].owner = payable (msg.sender);
        idToMarketItem[id].sold = true;
        _itemsSold.increment();

        //regards the marketplace with the listingPrice
        payable (owner).transfer(listingPrice);

        emit ProductSold(idToMarketItem[id].itemId, idToMarketItem[id].NFTContract, idToMarketItem[id].tokenId, idToMarketItem[id].creator, idToMarketItem[id].seller, payable (msg.sender), idToMarketItem[id].price);
    }

    function puItemToResell(address NFTContract, uint256 itemId, uint256 newPrice) public payable nonReentrant onlyItemOwner(itemId) {
        uint256 tokenId = idToMarketItem[0].tokenId;

        require(newPrice > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        NFT tokenContract = NFT(NFTContract);

        tokenContract.transferFrom(msg.sender, address(this), tokenId);

        address payable oldOwner = idToMarketItem[itemId].owner;

        idToMarketItem[itemId].owner = payable (address(this));
        idToMarketItem[itemId].seller = oldOwner;
        idToMarketItem[itemId].price = newPrice;
        idToMarketItem[itemId].sold = false;

        _itemsSold.decrement();

        emit ProductListed(itemId);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemsIds.current();
        uint256 unsoldItemCount = _itemsIds.current() - _itemsSold.current() - _itemsDeleted.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++)  {
            if(idToMarketItem[i + 1].owner == address(this) && idToMarketItem[i + 1].sold == false && idToMarketItem[i + 1].tokenId != 0) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function fetchSingleItem(uint256 id) public view returns (MarketItem memory) {
        return idToMarketItem[id];
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemsIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for(uint256 i = 0; i < totalItemCount; i++) {
            if(idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for(uint256 i = 1; i < totalItemCount; i++) {
            if(idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem memory currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function fetchAuthorsCreations(address author) public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemsIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for(uint256 i = 0; i < totalItemCount; i++) {
            if(idToMarketItem[i + 1].creator == author && !idToMarketItem[i + 1].sold) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for(uint256 i = 0; i < totalItemCount; i++) {
           if(idToMarketItem[i + 1].creator == author && !idToMarketItem[i + 1].sold) {
                uint256 currentId = i + 1;
                MarketItem memory currentItem = idToMarketItem[currentId];
                items[currentId] = currentItem;
                currentIndex += 1;
           }
        }

        return items;
    }

}