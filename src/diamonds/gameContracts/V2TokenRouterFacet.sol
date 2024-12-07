// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@/notDiamonds/gameContracts/IAtlasExpToken.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {LibRouter} from "../libraries/LibRouter.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {LibERC721} from "../libraries/LibERC721.sol";
import {LibERC20} from "../libraries/LibERC20.sol";
import {TokenRouter} from "@HyperLane/token/libs/TokenRouter.sol";

contract TokenRouterFacetV2 is TokenRouter {
    modifier requireTokenFacet() {
        require(LibERC721.diamondStorage().initialized || LibERC20.diamondStorage().initialized, "NFT facet not found");
        _;
    }

    modifier requireDataInterface() {
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        require(dsDataInterface.initialized, "DataInterfaceFacet not found");
        _;
    }

    modifier enter(uint32 _destinationDomain) {
        uint256 bridgingFees = _GasRouter_quoteDispatch(_destinationDomain, "", address(hook));
        require(msg.value == LibDataInterface.mintingFeesToEth() + bridgingFees, "fees not paid");
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(!ds.locked, "Contract is locked");
        ds.locked = true;
        _;
        ds.locked = false;
    }

    constructor(address _mailbox) TokenRouter(_mailbox) {}

    function ownerOf(uint256 tokenId) public view requireTokenFacet returns (address) {
        address owner = LibERC721._ownerOf(tokenId);
        return owner;
    }

    function setGas(uint32 domain, uint256 gas) external {
        LibDiamond.enforceIsContractOwner();
        _setDestinationGas(domain, gas);
    }

    /**
     * @notice Register the address of a Router contract for the same Application on a remote chain
     * @param _domain The domain of the remote Application Router
     * @param _router The address of the remote Application Router
     */
    function enrollRemoteRouter(uint32 _domain, bytes32 _router) external override {
        LibDiamond.enforceIsContractOwner();
        _enrollRemoteRouter(_domain, _router);
    }

    /**
     * @notice Batch version of `enrollRemoteRouter`
     * @param _domains The domains of the remote Application Routers
     * @param _addresses The addresses of the remote Application Routers
     */
    function enrollRemoteRouters(uint32[] calldata _domains, bytes32[] calldata _addresses) external override {
        LibDiamond.enforceIsContractOwner();
        require(_domains.length == _addresses.length, "!length");
        uint256 length = _domains.length;
        for (uint256 i = 0; i < length; i += 1) {
            _enrollRemoteRouter(_domains[i], _addresses[i]);
        }
    }

    function balanceOf(address owner) external view override returns (uint256) {
        return LibERC721._balanceOf(owner);
    }

    function getDestinationGas(uint32 domain) external view returns (uint256) {
        return destinationGas[domain];
    }

    function transferRemote(uint32 _destination, bytes32 _recipient, uint256 _amountOrId, bool _isERC20)
        external
        payable
        requireTokenFacet
        requireDataInterface
        enter(_destination)
        returns (bytes32 messageId)
    {
        LibRouter.HyperLaneDiamondStorage storage ds = LibRouter.diamondStorage();
        require(
            (LibERC20.diamondStorage().initialized && _isERC20) || (LibERC721.diamondStorage().initialized && !_isERC20),
            "Required token isn't initialized"
        );

        ds.erc20Transfer = _isERC20;
        if (_isERC20) {
            require(LibERC20._balanceOf(msg.sender) >= _amountOrId, "Not enough balance");
        } else {
            require(LibERC721._ownerOf(_amountOrId) == msg.sender, "Not owner of token");
        }
        uint256 requiredGas = _GasRouter_quoteDispatch(_destination, "", address(hook));
        return _transferRemote(_destination, _recipient, _amountOrId, requiredGas);
    }

    function _burnERC20(uint256 tokenId) internal {
        LibERC20._burn(msg.sender, tokenId);
    }

    function _burnERC721(uint256 tokenId) internal {
        LibERC721._burn(tokenId);
    }

    function _safeMintERC721(address to, uint256 tokenId) internal {
        LibERC721._mint(to, tokenId);
    }

    function _safeMintERC20(address to, uint256 tokenId) internal {
        LibERC20._mint(to, tokenId);
    }

    function transferRemote(uint32, bytes32, uint256) external payable override returns (bytes32) {
        revert("Not implemented");
    }

    function transferRemote(uint32, bytes32, uint256, bytes calldata, address)
        external
        payable
        override
        returns (bytes32)
    {
        revert("Not implemented");
    }

    /**
     * @dev Burns `_amount` of token from `msg.sender` balance.
     * @inheritdoc TokenRouter
     */
    function _transferFromSender(uint256 _amount) internal override returns (bytes memory) {
        LibRouter.HyperLaneDiamondStorage storage dsRouter = LibRouter.diamondStorage();
        bool isERC20 = dsRouter.erc20Transfer;
        if (isERC20) {
            _burnERC20(_amount);
            dsRouter.erc20Transfer = false;
            return bytes("0xERC20"); // no metadata
        } else {
            _burnERC721(_amount);
            dsRouter.erc20Transfer = false;
            return bytes("0xERC721"); // no metadata
        }
    }

    /**
     * @dev Mints `_amount` of token to `_recipient` balance.
     * @inheritdoc TokenRouter
     */
    function _transferTo(
        address _recipient,
        uint256 _amount,
        bytes calldata _metadata // no metadata
    ) internal virtual override {
        if (keccak256(_metadata) == keccak256(bytes("0xERC20"))) {
            _safeMintERC20(_recipient, _amount);
        } else if (keccak256(_metadata) == keccak256(bytes("0xERC721"))) {
            _safeMintERC721(_recipient, _amount);
        } else {
            revert("No supported interfaces");
        }
    }
}
