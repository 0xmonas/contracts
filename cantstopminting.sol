// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 ██████╗ █████╗ ███╗   ██╗████████╗    ███████╗████████╗ ██████╗ ██████╗ 
██╔════╝██╔══██╗████╗  ██║╚══██╔══╝    ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
██║     ███████║██╔██╗ ██║   ██║       ███████╗   ██║   ██║   ██║██████╔╝
██║     ██╔══██║██║╚██╗██║   ██║       ╚════██║   ██║   ██║   ██║██╔═══╝ 
╚██████╗██║  ██║██║ ╚████║   ██║       ███████║   ██║   ╚██████╔╝██║     
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝       ╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
                                                                           
███╗   ███╗██╗███╗   ██╗████████╗██╗███╗   ██╗ ██████╗                   
████╗ ████║██║████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝                   
██╔████╔██║██║██╔██╗ ██║   ██║   ██║██╔██╗ ██║██║  ███╗                  
██║╚██╔╝██║██║██║╚██╗██║   ██║   ██║██║╚██╗██║██║   ██║                  
██║ ╚═╝ ██║██║██║ ╚████║   ██║   ██║██║ ╚████║╚██████╔╝                  
╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝                   
                                                                           
                                                                               
    "Desire is a machine, and the object of desire is another machine connected to it".                                    
                                          
                  
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract CantStopMinting is ERC721, Ownable, ReentrancyGuard, ERC2981 {
    using Strings for uint256;
    
    uint256 public initialPrice = 0.0001 ether;
    uint256 public priceMultiplier = 111;
    uint256 public priceDivisor = 100;
    
    uint256 public currentTokenId = 0;
    // optimize - activeListingId removed
    uint256 public maxPerWallet = 50;
    bool public paused = false;
    bool public emergencyStop = false;
    
    mapping(address => uint256) public walletMintCount;
    
    struct TokenData {
        uint256 bleedTime;
        string customMetadata;
    }
    
    mapping(uint256 => TokenData) public tokens;
    // optimize - isListed mapping removed
    
    event TokenMinted(uint256 indexed tokenId, uint256 price);
    event TokenPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event MetadataUpdated(uint256 indexed tokenId);
    event EmergencyPause(bool status);
    event EmergencyStop(bool status);
    
    constructor() ERC721("Cant Stop Minting", "BLOOD") Ownable(msg.sender) {
        _setDefaultRoyalty(msg.sender, 1000);
        _mintAndList(0); // optimize - parameter added
    }
    
    function buy() external payable nonReentrant {
        require(!paused && !emergencyStop, "Contract is paused or stopped");
        
        uint256 tokenId = currentTokenId; // optimize - single storage read
        require(tokenId > 0, "No active listing");
        require(walletMintCount[msg.sender] < maxPerWallet, "Wallet limit reached");
        
        uint256 price = getPrice(tokenId);
        require(msg.value >= price, "Insufficient payment");
        require(msg.value == price, "Exact payment required");
        
        walletMintCount[msg.sender]++;
        
        _transfer(address(this), msg.sender, tokenId);
        
        emit TokenPurchased(tokenId, msg.sender, price);
        
        if (!emergencyStop) {
            _mintAndList(tokenId); // optimize - memory parameter
        }
    }
    
    function _mintAndList(uint256 lastTokenId) private { // optimize - parameter added
        require(!emergencyStop, "Emergency stop active");
        
        uint256 newTokenId = lastTokenId + 1; // optimize - memory operation
        uint256 price = getPrice(newTokenId);
        
        tokens[newTokenId] = TokenData({
            bleedTime: block.timestamp,
            customMetadata: ""
        });
        
        _mint(address(this), newTokenId);
        
        currentTokenId = newTokenId; // optimize - single storage write
        
        emit TokenMinted(newTokenId, price);
    }
    
    function getPrice(uint256 tokenId) public view returns (uint256) {
        if (tokenId == 0) return 0;
        if (tokenId == 1) return initialPrice;
        
        if (tokenId > 1000) {
            return initialPrice;
        }
        
        uint256 price = initialPrice;
        
        uint256 cycle = (tokenId - 1) / 100;
        uint256 positionInCycle = ((tokenId - 1) % 100) + 1;
        
        if (cycle > 9) {
            cycle = 9;
        }
        
        for (uint256 c = 0; c < cycle; c++) {
            if (c % 2 == 0) {
                for (uint256 i = 0; i < 100 && i < 49; i++) {
                    uint256 newPrice = (price * priceMultiplier) / priceDivisor;
                    if (newPrice > price * 10) break;
                    price = newPrice;
                }
            } else {
                for (uint256 i = 0; i < 100 && i < 50; i++) {
                    price = (price * priceDivisor) / priceMultiplier;
                    if (price < initialPrice) {
                        price = initialPrice;
                    break;
                    }
                }
            }
        }
        
        if (positionInCycle > 50) {
            return initialPrice;
        }
        
        if (cycle % 2 == 0) {
            for (uint256 i = 1; i < positionInCycle; i++) {
                uint256 newPrice = (price * priceMultiplier) / priceDivisor;
                if (newPrice > price * 2) break;
                price = newPrice;
            }
        } else {
            for (uint256 i = 1; i < positionInCycle; i++) {
                price = (price * priceDivisor) / priceMultiplier;
            if (price < initialPrice) {
                price = initialPrice;
                    break;
                }
            }
        }
        
        return price;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenId > 0 && tokenId <= currentTokenId, "Token doesn't exist");
        
        TokenData memory data = tokens[tokenId];
        
        uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, data.bleedTime)));
        
        uint256 red = 180 + (seed % 76);
        uint256 green = (seed >> 8) % 50;
        uint256 blue = (seed >> 16) % 30;
        uint256 opacity = 70 + (seed >> 24) % 31;
        
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            '<rect width="400" height="400" fill="rgba(', 
            red.toString(), ',', 
            green.toString(), ',', 
            blue.toString(), ',',
            opacity.toString(), '%)" />',
            '</svg>'
        ));
        
        (uint256 cycle, string memory phase,) = this.getCycleInfo(tokenId);
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name":"', unicode'🩸', ' #', tokenId.toString(), '",',
            '"description":"Can\'t Stop Minting - Dynamic bleeding cycles",',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '",',
            '"attributes":[',
                '{"trait_type":"Token","value":"#', tokenId.toString(), '"},',
                '{"trait_type":"Cycle","value":"', cycle.toString(), '"},',
                '{"trait_type":"Phase","value":"', phase, '"},',
                '{"trait_type":"Mint Time","value":"', data.bleedTime.toString(), '"}',
                bytes(data.customMetadata).length > 0 ? 
                    string(abi.encodePacked(',"custom":', data.customMetadata)) : 
                    '',
            ']}'
        ))));
        
        return string(abi.encodePacked('data:application/json;base64,', json));
    }
    
    function updateMetadata(uint256 tokenId, string calldata metadata) external onlyOwner {
        require(tokenId > 0 && tokenId <= currentTokenId, "Invalid token");
        tokens[tokenId].customMetadata = metadata;
        emit MetadataUpdated(tokenId);
    }
    
    function batchUpdateMetadata(
        uint256[] calldata tokenIds, 
        string[] calldata metadatas
    ) external onlyOwner {
        require(tokenIds.length == metadatas.length, "Length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] > 0 && tokenIds[i] <= currentTokenId, "Invalid token");
            tokens[tokenIds[i]].customMetadata = metadatas[i];
            emit MetadataUpdated(tokenIds[i]);
        }
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        payable(owner()).transfer(balance);
    }
    
    function emergencyPause() external onlyOwner {
        paused = true; // optimize - removed isListed manipulation
        emit EmergencyPause(true);
    }
    
    function emergencyUnpause() external onlyOwner {
        require(!emergencyStop, "Cannot unpause while emergency stopped");
        paused = false; // optimize - removed isListed manipulation
        emit EmergencyPause(false);
    }
    
    function emergencyStopAll() external onlyOwner {
        emergencyStop = true;
        paused = true; // optimize - removed isListed manipulation
        emit EmergencyStop(true);
    }
    
    function emergencyResumeAll() external onlyOwner {
        emergencyStop = false;
        paused = false;
        if (currentTokenId == 0) { // optimize - simplified condition
            _mintAndList(0);
        }
        emit EmergencyStop(false);
    }
    
    function setMaxPerWallet(uint256 _max) external onlyOwner {
        require(_max > 0, "Invalid limit");
        maxPerWallet = _max;
    }
    
    function setInitialPrice(uint256 _price) external onlyOwner {
        require(_price > 0, "Price must be greater than 0");
        initialPrice = _price;
    }
    
    function setPriceMultiplier(uint256 _multiplier) external onlyOwner {
        require(_multiplier > 100, "Multiplier must be greater than 100");
        priceMultiplier = _multiplier;
    }
    
    function setPriceDivisor(uint256 _divisor) external onlyOwner {
        require(_divisor > 0, "Divisor must be greater than 0");
        priceDivisor = _divisor;
    }
    
    function getCurrentPrice() external view returns (uint256) {
        return getPrice(currentTokenId); // optimize - direct access
    }
    
    function getActiveTokenId() external view returns (uint256) {
        return currentTokenId; // optimize - direct access
    }
    
    function getRemainingMints(address wallet) external view returns (uint256) {
        return maxPerWallet - walletMintCount[wallet];
    }
    
    function totalSupply() external view returns (uint256) {
        return currentTokenId;
    }
    
    function getCycleInfo(uint256 tokenId) external pure returns (uint256 cycle, string memory phase, uint256 positionInCycle) {
        cycle = (tokenId - 1) / 100;
        phase = cycle % 2 == 0 ? "Bleeding" : "Clotting";
        positionInCycle = ((tokenId - 1) % 100) + 1;
    }
    
    function getEmergencyStatus() external view returns (bool isPaused, bool isStopped) {
        return (paused, emergencyStop);
    }
    
    // optimize - new function to check if token is listed
    function isTokenListed(uint256 tokenId) external view returns (bool) {
        return tokenId == currentTokenId && tokenId > 0 && !paused && !emergencyStop;
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC2981) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
    
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }
    
    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }
    
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }
    
    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        return super._update(to, tokenId, auth);
    }
}
