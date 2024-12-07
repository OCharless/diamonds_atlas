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
import {DataInterfaceFacet} from "@/diamonds/gameContracts/DataInterfaceFacet.sol";
import {AtlasNFTFacet} from "@/diamonds/gameContracts/AtlasNFTFacet.sol";
import {MockMailbox} from "@HyperLane/mock/MockMailbox.sol";

contract DataInterfaceFacetTest is Test, HelperContract {
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
    }

    function test_addDataInterfaceFacet() public {
        DataInterfaceFacet dataInterface = new DataInterfaceFacet();
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = dataInterface.getFees.selector;
        selectors[1] = dataInterface.commitCost.selector;
        selectors[2] = dataInterface.ownerSetFightingFees.selector;
        selectors[3] = dataInterface.ownerSetMintingFees.selector;

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

        bytes4 selector = dataInterface.getFees.selector;
        IDiamondLoupe diamondLoupeFact = IDiamondLoupe(address(diamond));
        address facet = diamondLoupeFact.facetAddress(selector);
        assertEq(facet, address(dataInterface), "DataInterfaceFacet not added");
        bytes4[] memory selectors_ = diamondLoupeFact.facetFunctionSelectors(address(dataInterface));
        assertEq(selectors_[0], selectors[0], "getFees not added");
        assertEq(selectors_[1], selectors[1], "commitCost selectors not added");
        assertEq(selectors_[2], selectors[2], "ownerSetFightingFees selectors not added");
        assertEq(selectors_[3], selectors[3], "ownerSetMintingFees selectors not added");
    }

    function test_RevertIfNotDiamondOwner() public {
        _addDataInterfaceFacet();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));

        bytes memory expectedError =
            abi.encodeWithSignature("NotContractOwner(address,address)", address(1), address(this));

        vm.prank(address(1));
        vm.expectRevert(expectedError);
        dataInterface.ownerSetFightingFees(1);
    }

    function test_RevertIfAlreadyInitialized() public {
        _addDataInterfaceFacet();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));

        vm.expectRevert("DataInterface: facet instance has already been initialized");

        dataInterface.initialize();
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
        bytes memory data = abi.encodeWithSelector(dataInterface.initialize.selector, address(0));
        diamondCutFacet.diamondCut(diamondCut, address(dataInterface), data);

        return dataInterface;
    }
}
