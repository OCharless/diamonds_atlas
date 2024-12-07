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
import {MockMailbox} from "@HyperLane/mock/MockMailbox.sol";
import {DataInterfaceFacet} from "@/diamonds/gameContracts/DataInterfaceFacet.sol";
import {LevelingFacet} from "@/diamonds/gameContracts/LevelingFacet.sol";
import {AtlasERC20Facet} from "@/diamonds/gameContracts/AtlasERC20Facet.sol";

contract AtlasNFTFacetTest is Test, HelperContract {
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

    function test_addAtlasNFTFacet() public {
        AtlasNFTFacet atlasNFTFacet = new AtlasNFTFacet();
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = atlasNFTFacet.burn.selector;
        selectors[1] = atlasNFTFacet.mint.selector;
        selectors[2] = atlasNFTFacet.ownerOf.selector;
        selectors[3] = atlasNFTFacet.balanceOf.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(atlasNFTFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));

        bytes memory data = abi.encodeWithSelector(atlasNFTFacet.initialize.selector, 0, 100_000, 0, "testToken", "TTT");

        diamondCutFacet.diamondCut(diamondCut, address(atlasNFTFacet), data);

        bytes4 selector = atlasNFTFacet.mint.selector;
        IDiamondLoupe diamondLoupeFacet = IDiamondLoupe(address(diamond));
        address facet = diamondLoupeFacet.facetAddress(selector);
        assertEq(facet, address(atlasNFTFacet), "atlasNFTFacet not added");
        bytes4[] memory selectors_ = diamondLoupeFacet.facetFunctionSelectors(address(atlasNFTFacet));
        assertEq(selectors_[0], selectors[0], "burn not added");
        assertEq(selectors_[1], selectors[1], "mint selectors not added");
        assertEq(selectors_[2], selectors[2], "ownerOf selectors not added");
        assertEq(selectors_[3], selectors[3], "balanceOf selectors not added");
    }

    function test_DirectCallToFacetDontChangeStorage() public {
        AtlasNFTFacet nftFacet = _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        AtlasNFTFacet nftDiamondFacet = AtlasNFTFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 fee = dataInterface.getFees().mintingFees;
        nftDiamondFacet.mint{value: fee}();
        nftFacet.balanceOf(address(this));
    }

    function test_DirectCallChangingStorageStateShouldRevert() public {
        AtlasNFTFacet nftFacet = _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 fee = dataInterface.getFees().mintingFees;
        vm.expectRevert("DataInterfaceFacet Not initialized");
        nftFacet.mint{value: fee}();
    }

    function test_BurnRevertIfNotOwner() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        uint256 fee = dataInterface.getFees().mintingFees;
        atlasNFTFacet.mint{value: fee}();

        (bool success,) = address(1).call{value: fee}("");
        require(success, "Failed to send ether");
        vm.prank(address(1));
        atlasNFTFacet.mint{value: fee}();
        vm.prank(address(1));
        atlasNFTFacet.burn(50);

        vm.prank(address(1));
        vm.expectRevert("Burn caller is not owner nor approved");
        atlasNFTFacet.burn(0);
    }

    function test_ShouldRevertIfFeesNotPaid() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        vm.expectRevert("fees not paid");
        atlasNFTFacet.mint();
    }

    function test_ShouldRevertAtMaxLimit() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 fee = dataInterface.getFees().mintingFees;
        for (uint256 i = 0; i < 2000; i++) {
            address testAddress = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            (bool success,) = address(testAddress).call{value: fee}("");
            require(success, "Failed to send ether");
            vm.prank(testAddress);
            atlasNFTFacet.mint{value: fee}();
        }
        vm.expectRevert("Exceeds the limit");
        atlasNFTFacet.mint{value: fee}();
    }

    function test_NFTsDontOverlap() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        _addLevelingFacet();
        _addAtlasERC20Facet();
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        LevelingFacet levelingFacet = LevelingFacet(address(diamond));
        uint256 fee = dataInterface.getFees().mintingFees;

        address altDiamond = _createMockDiamond();
        AtlasERC20Facet expToken = new AtlasERC20Facet();
        AtlasERC20Facet expTokenInterface = AtlasERC20Facet(address(altDiamond));
        IDiamondCut diamondCutFacet = IDiamondCut(address(altDiamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = expToken.balanceOf.selector;
        selectors[1] = expToken.mint.selector;
        selectors[2] = expToken.burn.selector;
        selectors[3] = expToken.transfer.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(expToken),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        diamondCutFacet.diamondCut(
            diamondCut,
            address(expToken),
            abi.encodeWithSelector(expToken.initialize.selector, 18, "ATP", "Atlas Token", address(diamond))
        );
        levelingFacet.setExpToken(address(altDiamond));

        for (uint256 i = 0; i <= 2000; i++) {
            if (i == 2000) {
                vm.expectRevert("Exceeds the limit");
                atlasNFTFacet.mint{value: fee}();
                continue;
            }

            address testAddress = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            (bool success,) = testAddress.call{value: fee}("");
            require(success, "Failed to send ether");
            expTokenInterface.transfer(testAddress, 100000000 ether);
            vm.prank(testAddress);
            atlasNFTFacet.mint{value: fee}();

            //To skip some cases in order to avoid Out Of Gas error
            if (i > 21 && i < 1995) continue;

            for (uint256 j = 0; j < 50; j++) {
                vm.prank(testAddress);
                if (j == 49) {
                    vm.expectRevert("Can't level up past max level");
                    levelingFacet.levelUp(i * 50 + j);
                    continue;
                }
                levelingFacet.levelUp(i * 50 + j);
            }
        }
    }

    function test_ShouldRevertIfDataLibNotInitialized() public {
        _addAtlasNFTFacet();
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        vm.expectRevert("DataInterfaceFacet Not initialized");
        atlasNFTFacet.mint();
    }

    function test_ShouldNotBeTransferrable() public {
        AtlasNFTFacet facet = _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 fee = dataInterface.getFees().mintingFees;
        atlasNFTFacet.mint{value: fee}();
        vm.expectRevert("Not implemented");
        atlasNFTFacet.safeTransferFrom(address(this), address(this), 0);
        vm.expectRevert("Not implemented");
        atlasNFTFacet.safeTransferFrom(address(this), address(this), 0, "");
        vm.expectRevert("Not implemented");
        atlasNFTFacet.transferFrom(address(this), address(this), 0);
        vm.expectRevert("Not implemented");
        facet.approve(address(this), 0);
        vm.expectRevert("Not implemented");
        facet.setApprovalForAll(address(this), true);
        vm.expectRevert("Not implemented");
        facet.getApproved(0);
        vm.expectRevert("Not implemented");
        facet.isApprovedForAll(address(this), address(this));
    }

    function test_RevertIfAlreadyInitialized() public {
        _addAtlasNFTFacet();
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));

        vm.expectRevert("NFTFacet: facet instance has already been initialized");

        atlasNFTFacet.initialize(100_000, 200_000, 0, "testToken2", "TTT2");
    }

    function _addAtlasNFTFacet() internal returns (AtlasNFTFacet) {
        AtlasNFTFacet atlasNFTFacet = new AtlasNFTFacet();
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = atlasNFTFacet.burn.selector;
        selectors[1] = atlasNFTFacet.mint.selector;
        selectors[2] = atlasNFTFacet.ownerOf.selector;
        selectors[3] = atlasNFTFacet.balanceOf.selector;
        selectors[4] = atlasNFTFacet.initialize.selector;
        selectors[5] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        selectors[6] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        selectors[7] = atlasNFTFacet.transferFrom.selector;

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

        return dataInterface;
    }

    function _addLevelingFacet() private returns (LevelingFacet) {
        LevelingFacet newFacet = new LevelingFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](3);
        selectorsArray[0] = newFacet.levelUp.selector;
        selectorsArray[1] = newFacet.levelDown.selector;
        selectorsArray[2] = newFacet.setExpToken.selector;

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
}
