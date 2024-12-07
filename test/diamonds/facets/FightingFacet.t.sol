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
import {FightingFacet} from "@/diamonds/gameContracts/FightingFacet.sol";
import {AtlasERC20Facet} from "@/diamonds/gameContracts/AtlasERC20Facet.sol";

contract FightingFacetTest is Test, HelperContract {
    DiamondInit public init;
    DiamondCutFacet public cut;
    DiamondLoupeFacet public loupe;
    IDiamondLoupe public diamondLoupe;
    Diamond public diamond;

    event CommitMade(address indexed user, uint256 indexed petId, bytes32 commitHash);
    event ResultMade(address indexed user, uint256 indexed petId, bool outcome);

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

    function test_AddFightingFacet() public {
        FightingFacet fightingFacet = new FightingFacet();
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = fightingFacet.setArtefactContract.selector;
        selectors[1] = fightingFacet.setWinningCap.selector;
        selectors[2] = fightingFacet.commit.selector;
        selectors[3] = fightingFacet.reveal.selector;
        selectors[4] = fightingFacet.waitingForReveal.selector;
        selectors[5] = fightingFacet.generateRandomHash.selector;
        selectors[6] = fightingFacet.clearCommit.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(fightingFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));

        bytes memory data = abi.encodeWithSelector(fightingFacet.initialize.selector, address(0));

        diamondCutFacet.diamondCut(diamondCut, address(fightingFacet), data);

        bytes4 selector = fightingFacet.commit.selector;
        IDiamondLoupe diamondLoupeFacet = IDiamondLoupe(address(diamond));
        address facet = diamondLoupeFacet.facetAddress(selector);
        assertEq(facet, address(fightingFacet), "fightingFacet not added");
        bytes4[] memory selectors_ = diamondLoupeFacet.facetFunctionSelectors(address(fightingFacet));
        assertEq(selectors_[0], selectors[0], "setArtefactContract not added");
        assertEq(selectors_[1], selectors[1], "setWinningCap selectors not added");
        assertEq(selectors_[2], selectors[2], "commit selectors not added");
        assertEq(selectors_[3], selectors[3], "reveal selectors not added");
    }

    function test_Commit() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        FightingFacet fightingFacet = FightingFacet(address(diamond));
        DataInterfaceFacet dataInterfaceFacet = DataInterfaceFacet(address(diamond));
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        uint256 fee = dataInterfaceFacet.getFees().mintingFees;
        atlasNFTFacet.mint{value: fee}();
        uint256 ID = 0;
        uint256 commitCost = dataInterfaceFacet.commitCost(ID, 50);
        bytes32 nonce = fightingFacet.generateRandomHash(ID);
        bytes32 commitHash = keccak256(abi.encodePacked(nonce));

        vm.expectEmit(true, true, true, false);
        emit CommitMade(address(this), ID, keccak256(abi.encodePacked(commitHash, ID)));
        fightingFacet.commit{value: commitCost}(ID, commitHash);
    }

    function test_Reveal() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        FightingFacet fightingFacet = FightingFacet(address(diamond));
        DataInterfaceFacet dataInterfaceFacet = DataInterfaceFacet(address(diamond));
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        uint256 fee = dataInterfaceFacet.getFees().mintingFees;
        atlasNFTFacet.mint{value: fee}();
        uint256 ID = 0;
        uint256 commitCost = dataInterfaceFacet.commitCost(ID, 50);
        bytes32 nonce = fightingFacet.generateRandomHash(ID);
        bytes32 commitHash = keccak256(abi.encodePacked(nonce));

        vm.expectEmit(true, true, true, false);
        emit CommitMade(address(this), ID, keccak256(abi.encodePacked(commitHash, ID)));
        fightingFacet.commit{value: commitCost}(ID, commitHash);

        vm.expectEmit(true, true, true, false);
        emit ResultMade(address(this), ID, true);
        fightingFacet.reveal(ID, nonce);
    }

    function test_FullRun() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        _addLevelingFacet();
        _addAtlasERC20Facet();
        _addDataInterfaceFacet();
        DataInterfaceFacet dataInterfaceFacet = DataInterfaceFacet(address(diamond));
        AtlasNFTFacet atlasNFTFacet = AtlasNFTFacet(address(diamond));
        LevelingFacet levelingFacet = LevelingFacet(address(diamond));

        address altDiamond = _createMockDiamond();
        AtlasERC20Facet expToken = new AtlasERC20Facet();
        AtlasERC20Facet tokenInterface = AtlasERC20Facet(address(altDiamond));
        IDiamondCut diamondCutFacet = IDiamondCut(address(altDiamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = expToken.balanceOf.selector;
        selectors[1] = expToken.mint.selector;
        selectors[2] = expToken.burn.selector;
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

        uint256 fee = dataInterfaceFacet.getFees().mintingFees;
        atlasNFTFacet.mint{value: fee}();
        uint256 tokenId = atlasNFTFacet.tokenOfOwnerByIndex(address(this), 0);
        while (tokenId < 49) {
            tokenId = atlasNFTFacet.tokenOfOwnerByIndex(address(this), 0);
            _commitReveal(tokenId);
            if (tokenInterface.balanceOf(address(this)) > levelingFacet.expForLevel(tokenId)) {
                levelingFacet.levelUp(tokenId);
                tokenId = atlasNFTFacet.tokenOfOwnerByIndex(address(this), 0);
            }
            vm.warp(block.timestamp + 1 days);
        }
    }

    function test_ShouldRevertOnNotOwnedToken() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        FightingFacet fightingFacet = FightingFacet(address(diamond));
        DataInterfaceFacet dataInterfaceFacet = DataInterfaceFacet(address(diamond));

        uint256 ID = 0;
        uint256 commitCost = dataInterfaceFacet.commitCost(ID, 50);
        bytes32 nonce = fightingFacet.generateRandomHash(ID);
        bytes32 commitHash = keccak256(abi.encodePacked(nonce));

        vm.expectRevert("Not the owner of the pet");
        fightingFacet.commit{value: commitCost}(ID, commitHash);
    }

    function test_ShouldNotBeInitializeableTwice() public {
        _addFightingFacet();
        FightingFacet fightingFacet = FightingFacet(address(diamond));

        vm.expectRevert("FightingFacet: facet instance has already been initialized");

        fightingFacet.initialize(address(0));
    }

    function test_ShouldRevertIfNotInitialized() public {
        FightingFacet fightingFacet = new FightingFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = fightingFacet.commit.selector;
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(fightingFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
        IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));
        diamondCutFacet.diamondCut(diamondCut, address(0), bytes("0x"));

        vm.expectRevert("facet not initialized");
        FightingFacet(address(diamond)).commit(0, bytes32("0x"));
    }

    function test_ShouldRevertIfNoDataInterface() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        vm.expectRevert("DataInterfaceFacet not found");
        FightingFacet(address(diamond)).commit(0, bytes32("0x"));
    }

    function test_ShouldRevertIfNotOwner() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        FightingFacet fightingFacet = FightingFacet(address(diamond));
        bytes memory expectedError =
            abi.encodeWithSignature("NotContractOwner(address,address)", address(1), address(this));
        vm.prank(address(1));
        vm.expectRevert(expectedError);
        fightingFacet.setArtefactContract(address(0));
        vm.prank(address(1));
        vm.expectRevert(expectedError);
        fightingFacet.setWinningCap(0);
    }

    function _addAtlasNFTFacet() internal returns (AtlasNFTFacet) {
        AtlasNFTFacet atlasNFTFacet = new AtlasNFTFacet();
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = atlasNFTFacet.burn.selector;
        selectors[1] = atlasNFTFacet.mint.selector;
        selectors[2] = atlasNFTFacet.ownerOf.selector;
        selectors[3] = atlasNFTFacet.tokenOfOwnerByIndex.selector;
        selectors[4] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        selectors[5] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        selectors[6] = atlasNFTFacet.transferFrom.selector;

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
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = atlasERC20Facet.balanceOf.selector;

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

        return dataInterface;
    }

    function _addLevelingFacet() private returns (LevelingFacet) {
        LevelingFacet newFacet = new LevelingFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](5);
        selectorsArray[0] = newFacet.levelUp.selector;
        selectorsArray[1] = newFacet.levelDown.selector;
        selectorsArray[2] = newFacet.expForLevel.selector;
        selectorsArray[3] = newFacet.rewardForLevel.selector;
        selectorsArray[4] = newFacet.setExpToken.selector;

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

    function _addFightingFacet() private returns (FightingFacet) {
        FightingFacet fightingFacet = new FightingFacet();
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = fightingFacet.setArtefactContract.selector;
        selectors[1] = fightingFacet.setWinningCap.selector;
        selectors[2] = fightingFacet.commit.selector;
        selectors[3] = fightingFacet.reveal.selector;
        selectors[4] = fightingFacet.waitingForReveal.selector;
        selectors[5] = fightingFacet.generateRandomHash.selector;
        selectors[6] = fightingFacet.clearCommit.selector;
        selectors[7] = fightingFacet.initialize.selector;

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(fightingFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        //TODO : Add artefactFacet rework

        // Artefact artefact = new Artefact(address(new MockMailbox(1)), 1, address(this));
        // IDiamondCut diamondCutFacet = IDiamondCut(address(diamond));
        // bytes memory data = abi.encodeWithSelector(fightingFacet.initialize.selector, address(artefact));
        // diamondCutFacet.diamondCut(diamondCut, address(fightingFacet), data);

        return fightingFacet;
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

    function _commitReveal(uint256 tokenId) internal {
        FightingFacet fightingFacet = FightingFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 fees = dataInterface.commitCost(tokenId, 50);
        bytes32 nonce = fightingFacet.generateRandomHash(tokenId);
        bytes32 commitHash = keccak256(abi.encodePacked(nonce));
        fightingFacet.commit{value: fees}(tokenId, commitHash);

        fightingFacet.reveal(tokenId, nonce);
    }
}
