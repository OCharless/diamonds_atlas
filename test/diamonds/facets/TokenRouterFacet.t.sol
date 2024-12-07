// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Diamond, DiamondArgs} from "@/diamonds/Diamond.sol";
import {DiamondInit} from "@/diamonds/Initializer.sol";
import {DiamondCutFacet} from "@/diamonds/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@/diamonds/facets/DiamondLoupeFacet.sol";

import {IDiamond} from "@/diamonds/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@/diamonds/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@/diamonds/interfaces/IDiamondCut.sol";
import {HelperContract} from "../HelperContract.sol";
import {INFTFacet} from "@/diamonds/interfaces/INFTFacet.sol";
import {AtlasNFTFacet} from "@/diamonds/gameContracts/AtlasNFTFacet.sol";
import {AtlasERC20Facet} from "@/diamonds/gameContracts/AtlasERC20Facet.sol";
import {MockMailbox} from "@HyperLane/mock/MockMailbox.sol";
import {DataInterfaceFacet} from "@/diamonds/gameContracts/DataInterfaceFacet.sol";
import {LevelingFacet} from "@/diamonds/gameContracts/LevelingFacet.sol";
import {TokenRouterFacetV2} from "@/diamonds/gameContracts/V2TokenRouterFacet.sol";

contract TokenRouterFacetTest is Test, HelperContract {
    MockMailbox originMailbox;
    MockMailbox destinationMailbox;

    DiamondInit public init;
    DiamondCutFacet public cut;
    DiamondLoupeFacet public loupe;
    IDiamondLoupe public diamondLoupe;
    Diamond public diamond;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public {
        init = new DiamondInit();
        cut = new DiamondCutFacet();
        loupe = new DiamondLoupeFacet();

        init.init();
        bytes4 initSelector = init.init.selector;
        DiamondArgs memory args =
            DiamondArgs({owner: address(this), init: address(init), initCalldata: abi.encode(initSelector)});
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](2);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(cut),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondCutFacet")
        });
        diamondCut[1] = IDiamond.FacetCut({
            facetAddress: address(loupe),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        diamond = new Diamond(diamondCut, args);
        diamondLoupe = IDiamondLoupe(address(diamond));

        _mailBoxSetup();
    }

    function test_addTokenRouterFacetV2() public {
        TokenRouterFacetV2 tokenRouterFacet = new TokenRouterFacetV2(address(originMailbox));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256,bool)"));
        selectors[1] = tokenRouterFacet.setGas.selector;
        selectors[2] = tokenRouterFacet.enrollRemoteRouter.selector;
        selectors[3] = tokenRouterFacet.quoteGasPayment.selector;
        selectors[4] = tokenRouterFacet.handle.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(tokenRouterFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));

        diamondCutFacet.diamondCut(diamondCut, address(0), bytes("0x"));

        bytes4 selector = bytes4(keccak256("transferRemote(uint32,bytes32,uint256,bool)"));
        IDiamondLoupe diamondLoupeFacet = IDiamondLoupe(address(diamond));
        address facet = diamondLoupeFacet.facetAddress(selector);
        assertEq(facet, address(tokenRouterFacet), "TokenRouterFacetV2 not added");
        bytes4[] memory selectors_ = diamondLoupeFacet.facetFunctionSelectors(address(tokenRouterFacet));
        assertEq(selectors_[0], selectors[0], "burn not added");
        assertEq(selectors_[1], selectors[1], "mint selectors not added");
        assertEq(selectors_[2], selectors[2], "ownerOf selectors not added");
        assertEq(selectors_[3], selectors[3], "balanceOf selectors not added");
    }

    function test_ShouldBridgeEachTokenType() public {
        AtlasERC20Facet atlasERC20 = _addAtlasERC20Facet();
        AtlasNFTFacet atlasNFT = _addAtlasNFTFacet();
        DataInterfaceFacet dataInterface = _addDataInterfaceFacet();
        _addTokenRouterFacetV2();
        address receiver = _createMockDiamond();
        _addERC20FacetToDiamond(receiver, address(atlasERC20));
        _addNFTFacetToDiamond(receiver, address(atlasNFT));
        _addDataInterfaceFacetToDiamond(receiver, address(dataInterface));
        _addTokenRouterFacetToDiamond(receiver, address(new TokenRouterFacetV2(address(destinationMailbox))));
        atlasERC20 = AtlasERC20Facet(address(diamond));
        atlasNFT = AtlasNFTFacet(address(diamond));
        dataInterface = DataInterfaceFacet(address(diamond));
        TokenRouterFacetV2 tokenRouterMain = TokenRouterFacetV2(address(diamond));
        AtlasNFTFacet atlasNFTAlt = AtlasNFTFacet(address(receiver));
        TokenRouterFacetV2 tokenRouterAlt = TokenRouterFacetV2(address(receiver));

        uint256 fees = dataInterface.getFees().mintingFees;
        atlasNFT.mint{value: fees}();
        assertEq(atlasNFT.balanceOf(address(this)), 1, "Balance should be 1");
        uint256 tokenId = atlasNFT.tokensOfOwner(address(this))[0];
        assertEq(atlasNFT.ownerOf(tokenId), address(this), "Owner should be address(this)");
        assertEq(atlasNFTAlt.balanceOf(address(this)), 0, "Balance should be 0");
        atlasNFTAlt.mint{value: fees}();
        assertEq(atlasNFTAlt.balanceOf(address(this)), 1, "Balance should be 1");
        uint256 tokenIdAlt = atlasNFTAlt.tokensOfOwner(address(this))[0];
        assertEq(tokenIdAlt, 100_000, "ID should be 100_000");
        uint256 tokenIdMain = atlasNFT.tokensOfOwner(address(this))[0];
        assertEq(tokenIdMain, 0, "ID should be 0");

        tokenRouterMain.setGas(2, 330_000);
        tokenRouterAlt.setGas(2, 330_000);
        bytes32(uint256(uint160(address(tokenRouterAlt))));
        tokenRouterMain.enrollRemoteRouter(2, bytes32(uint256(uint160(address(tokenRouterAlt)))));
        tokenRouterAlt.enrollRemoteRouter(1, bytes32(uint256(uint160(address(tokenRouterMain)))));
        uint256 bfees = tokenRouterMain.quoteGasPayment(2);
        tokenRouterMain.transferRemote{value: fees + bfees}(
            2, bytes32(uint256(uint160(address(this)))), tokenIdMain, false
        );
        destinationMailbox.processNextInboundMessage();
        assertEq(atlasNFT.balanceOf(address(this)), 0, "Balance should be 0");
        assertEq(atlasNFTAlt.balanceOf(address(this)), 2, "Balance should be 2");
        assertEq(atlasNFTAlt.ownerOf(tokenId), address(this), "Owner should be address(this)");
        tokenRouterAlt.transferRemote{value: fees + bfees}(
            1, bytes32(uint256(uint160(address(this)))), tokenIdAlt, false
        );
        originMailbox.processNextInboundMessage();
        assertEq(atlasNFTAlt.balanceOf(address(this)), 1, "Balance should be 1");
        assertEq(atlasNFT.balanceOf(address(this)), 1, "Balance should be 1");
        assertEq(atlasNFT.ownerOf(tokenIdAlt), address(this), "Owner should be address(this)");

        // assertEq(atlasERC20.balanceOfERC20(address(this)), 1 ether * 1 ether, "Balance should be 1 ether");
        // assertEq(atlasERC20Alt.balanceOfERC20(address(this)), 1 ether * 1 ether, "Balance should be 1 ether");
        // tokenRouterMain.transferRemote{value: fees + bfees}(
        //     2, bytes32(uint256(uint160(address(this)))), (1 ether / 2) * 1 ether, true
        // );
        // destinationMailbox.processNextInboundMessage();
        // assertEq(atlasERC20.balanceOfERC20(address(this)), (1 ether / 2) * 1 ether, "Balance should be 0.5 ether");
        // assertEq(atlasERC20Alt.balanceOfERC20(address(this)), (3 ether / 2) * 1 ether, "Balance should be 1.5 ether");
        //ERC721 balance should not change
        assertEq(atlasNFTAlt.balanceOf(address(this)), 1, "Balance should be 1");
        assertEq(atlasNFT.balanceOf(address(this)), 1, "Balance should be 1");
    }

    function _addTokenRouterFacetV2() internal returns (TokenRouterFacetV2) {
        TokenRouterFacetV2 tokenRouterFacet = new TokenRouterFacetV2(address(originMailbox));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256,bool)"));
        selectors[1] = tokenRouterFacet.setGas.selector;
        selectors[2] = tokenRouterFacet.enrollRemoteRouter.selector;
        selectors[3] = tokenRouterFacet.quoteGasPayment.selector;
        selectors[4] = tokenRouterFacet.handle.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(tokenRouterFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));

        diamondCutFacet.diamondCut(diamondCut, address(0), bytes("0x"));

        return tokenRouterFacet;
    }

    function _addAtlasERC20Facet() internal returns (AtlasERC20Facet) {
        AtlasERC20Facet atlasERC20Facet = new AtlasERC20Facet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = atlasERC20Facet.balanceOfERC20.selector;
        selectors[1] = atlasERC20Facet.transfer.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(atlasERC20Facet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));

        bytes memory data = abi.encodeWithSelector(atlasERC20Facet.initialize.selector, 18, "ATP", "Atlas Token");

        diamondCutFacet.diamondCut(diamondCut, address(atlasERC20Facet), data);

        return atlasERC20Facet;
    }

    function _addAtlasNFTFacet() internal returns (AtlasNFTFacet) {
        AtlasNFTFacet atlasNFTFacet = new AtlasNFTFacet();
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = atlasNFTFacet.burn.selector;
        selectors[1] = atlasNFTFacet.mint.selector;
        selectors[2] = atlasNFTFacet.ownerOf.selector;
        selectors[3] = atlasNFTFacet.balanceOf.selector;
        selectors[4] = atlasNFTFacet.tokensOfOwner.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(atlasNFTFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));

        bytes memory data = abi.encodeWithSelector(atlasNFTFacet.initialize.selector, 0, 100_000, 0, "testToken", "TTT");

        diamondCutFacet.diamondCut(diamondCut, address(atlasNFTFacet), data);

        return atlasNFTFacet;
    }

    function _addDataInterfaceFacet() internal returns (DataInterfaceFacet) {
        DataInterfaceFacet dataInterface = new DataInterfaceFacet();
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = dataInterface.getFees.selector;
        selectors[1] = dataInterface.commitCost.selector;
        selectors[2] = dataInterface.ownerSetFightingFees.selector;
        selectors[3] = dataInterface.ownerSetMintingFees.selector;
        selectors[4] = dataInterface.initialize.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(dataInterface),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));
        diamondCutFacet.diamondCut(
            diamondCut, address(dataInterface), abi.encodeWithSelector(dataInterface.initialize.selector)
        );

        return (dataInterface);
    }

    function _addLevelingFacet() private returns (LevelingFacet) {
        LevelingFacet newFacet = new LevelingFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](2);
        selectorsArray[0] = newFacet.levelUp.selector;
        selectorsArray[1] = newFacet.levelDown.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        (uint256[] memory lvlToExp, uint256[] memory lvlToRew) = _buildLvlArrays();

        bytes memory data = abi.encodeWithSelector(newFacet.initialize.selector, lvlToExp, lvlToRew);

        facetCut.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }

    function _addERC20FacetToDiamond(address _diamond, address facet) private returns (AtlasERC20Facet) {
        AtlasERC20Facet newFacet = AtlasERC20Facet(facet);
        IDiamondCut diamondCutFacet = IDiamondCut(address(_diamond));

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = newFacet.balanceOfERC20.selector;
        selectors[1] = newFacet.transfer.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        bytes memory data = abi.encodeWithSelector(newFacet.initialize.selector, 18, "ATP", "Atlas Token");
        diamondCutFacet.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }

    function _addNFTFacetToDiamond(address _diamond, address facet) private returns (AtlasNFTFacet) {
        AtlasNFTFacet newFacet = AtlasNFTFacet(facet);
        IDiamondCut diamondCutFacet = IDiamondCut(address(_diamond));

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = newFacet.burn.selector;
        selectors[1] = newFacet.mint.selector;
        selectors[2] = newFacet.ownerOf.selector;
        selectors[3] = newFacet.balanceOf.selector;
        selectors[4] = newFacet.tokensOfOwner.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        bytes memory data =
            abi.encodeWithSelector(newFacet.initialize.selector, 100_000, 200_000, 0, "testToken", "TTT");
        diamondCutFacet.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }

    function _addDataInterfaceFacetToDiamond(address _diamond, address facet) private returns (DataInterfaceFacet) {
        DataInterfaceFacet newFacet = DataInterfaceFacet(facet);
        IDiamondCut diamondCutFacet = IDiamondCut(address(_diamond));

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = newFacet.getFees.selector;
        selectors[1] = newFacet.commitCost.selector;
        selectors[2] = newFacet.ownerSetFightingFees.selector;
        selectors[3] = newFacet.ownerSetMintingFees.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        diamondCutFacet.diamondCut(diamondCut, address(newFacet), abi.encodeWithSelector(newFacet.initialize.selector));

        return newFacet;
    }

    function _addTokenRouterFacetToDiamond(address _diamond, address facet) private returns (TokenRouterFacetV2) {
        TokenRouterFacetV2 newFacet = TokenRouterFacetV2(facet);
        IDiamondCut diamondCutFacet = IDiamondCut(address(_diamond));

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256,bool)"));
        selectors[1] = newFacet.setGas.selector;
        selectors[2] = newFacet.enrollRemoteRouter.selector;
        selectors[3] = newFacet.quoteGasPayment.selector;
        selectors[4] = newFacet.handle.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        diamondCutFacet.diamondCut(diamondCut, address(0), bytes("0x"));

        return newFacet;
    }

    function _createMockDiamond() public returns (address) {
        DiamondInit _init = new DiamondInit();
        DiamondCutFacet _cut = new DiamondCutFacet();
        DiamondLoupeFacet _loupe = new DiamondLoupeFacet();

        bytes4 initSelector = _init.init.selector;
        DiamondArgs memory args =
            DiamondArgs({owner: address(this), init: address(_init), initCalldata: abi.encode(initSelector)});

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](2);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(_cut),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondCutFacet")
        });
        diamondCut[1] = IDiamond.FacetCut({
            facetAddress: address(_loupe),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        Diamond _diamond = new Diamond(diamondCut, args);

        return address(_diamond);
    }

    function _mailBoxSetup() private {
        originMailbox = new MockMailbox(1);
        destinationMailbox = new MockMailbox(2);
        originMailbox.addRemoteMailbox(2, destinationMailbox);
        destinationMailbox.addRemoteMailbox(1, originMailbox);
    }
}
