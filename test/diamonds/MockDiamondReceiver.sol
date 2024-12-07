// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Diamond, DiamondArgs} from "@/diamonds/Diamond.sol";
import {DiamondInit} from "@/diamonds/Initializer.sol";
import {DiamondCutFacet} from "@/diamonds/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@/diamonds/facets/DiamondLoupeFacet.sol";

import {IDiamond} from "@/diamonds/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@/diamonds/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@/diamonds/interfaces/IDiamondCut.sol";
import {HelperContract} from "./HelperContract.sol";
import {INFTFacet} from "@/diamonds/interfaces/INFTFacet.sol";
import {DataInterfaceFacet} from "@/diamonds/gameContracts/DataInterfaceFacet.sol";
import {TokenRouterFacetV2} from "@/diamonds/gameContracts/V2TokenRouterFacet.sol";
import {AtlasNFTFacet} from "@/diamonds/gameContracts/AtlasNFTFacet.sol";
import {LevelingFacet} from "@/diamonds/gameContracts/LevelingFacet.sol";
import {MockMailbox} from "@HyperLane/mock/MockMailbox.sol";

contract MockDiamondReceiver is HelperContract {
    MockMailbox originMailbox;

    DiamondInit public init;
    DiamondCutFacet public cut;
    DiamondLoupeFacet public loupe;
    IDiamondLoupe public diamondLoupe;
    Diamond public diamond;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    constructor() {
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

        originMailbox = new MockMailbox(2);
        originMailbox.addRemoteMailbox(1, new MockMailbox(1));
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        _addLevelingFacet();
    }

    function sendBack(uint256 tokenID) public {
        TokenRouterFacetV2 nftFacet = TokenRouterFacetV2(payable(address(diamond)));
        bytes32 recipient = bytes32(uint256(uint160(msg.sender)));
        nftFacet.transferRemote(1, recipient, tokenID);
    }

    function _addAtlasNFTFacet() private returns (AtlasNFTFacet) {
        AtlasNFTFacet newFacet = new AtlasNFTFacet();

        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);

        bytes4[] memory selectorsArray = new bytes4[](3);
        selectorsArray[0] = newFacet.mint.selector;
        selectorsArray[1] = newFacet.balanceOf.selector;
        selectorsArray[2] = newFacet.ownerOf.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        bytes memory data =
            abi.encodeWithSignature("initialize(uint256,uint256,string,string)", 0, 100_000, "testToken", "TTT");

        facetCut.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }

    function _addDataInterfaceFacet() private returns (DataInterfaceFacet) {
        DataInterfaceFacet newFacet = new DataInterfaceFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);

        bytes4[] memory selectorsArray = new bytes4[](2);
        selectorsArray[0] = newFacet.getFees.selector;
        selectorsArray[1] = newFacet.commitCost.selector;

        bytes memory data = abi.encodeWithSelector(newFacet.initialize.selector);

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }

    function _addLevelingFacet() private returns (LevelingFacet) {
        LevelingFacet newFacet = new LevelingFacet();

        //TODO : Add expTokenFacet rework
        // IDiamondCut facetCut = IDiamondCut(address(diamond));
        // IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);

        // AtlasExpToken expToken = new AtlasExpToken(address(originMailbox));
        // expToken.initialize(1 ether * 1 ether, "AEXPToken", "APT", address(0), address(0), address(this));
        // expToken.setHero(address(diamond));
        // bytes4[] memory selectorsArray = new bytes4[](2);
        // selectorsArray[0] = newFacet.levelUp.selector;
        // selectorsArray[1] = newFacet.levelDown.selector;

        // diamondCut[0] = IDiamond.FacetCut({
        //     facetAddress: address(newFacet),
        //     action: IDiamond.FacetCutAction.Add,
        //     functionSelectors: selectorsArray
        // });

        // (uint256[] memory lvlToExp, uint256[] memory lvlToRew) = _buildLvlArrays();

        // bytes memory data = abi.encodeWithSelector(newFacet.initialize.selector, address(expToken), lvlToExp, lvlToRew);

        // facetCut.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }

    function _addTokenRouterFacetV2() private returns (TokenRouterFacetV2) {
        TokenRouterFacetV2 newFacet = new TokenRouterFacetV2(address(originMailbox));
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](5);
        selectorsArray[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256)"));
        selectorsArray[1] = newFacet.setGas.selector;
        selectorsArray[2] = newFacet.enrollRemoteRouter.selector;
        selectorsArray[3] = newFacet.quoteGasPayment.selector;
        selectorsArray[4] = newFacet.handle.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        bytes memory data = abi.encodeWithSignature(
            "initialize(uint256,string,string,address,address,address)",
            0,
            "testToken",
            "TTT",
            address(0),
            address(0),
            address(this)
        );

        facetCut.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
    }
}
