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
import {HelperContract} from "./HelperContract.sol";
import {INFTFacet} from "@/diamonds/interfaces/INFTFacet.sol";
import {DataInterfaceFacet} from "@/diamonds/gameContracts/DataInterfaceFacet.sol";
import {TokenRouterFacetV2} from "@/diamonds/gameContracts/V2TokenRouterFacet.sol";
import {AtlasNFTFacet} from "@/diamonds/gameContracts/AtlasNFTFacet.sol";
import {LevelingFacet} from "@/diamonds/gameContracts/LevelingFacet.sol";
import {FightingFacet} from "@/diamonds/gameContracts/FightingFacet.sol";
import {AtlasERC20Facet} from "@/diamonds/gameContracts/AtlasERC20Facet.sol";
import {MockMailbox} from "@HyperLane/mock/MockMailbox.sol";

contract DiamondTest is Test, HelperContract {
    MockMailbox originMailbox;
    MockMailbox destinationMailbox;

    DiamondInit public init;
    DiamondCutFacet public cut;
    DiamondLoupeFacet public loupe;
    IDiamondLoupe public diamondLoupe;
    Diamond public diamond;

    event CommitMade(address indexed user, uint256 indexed petId, bytes32 commitHash);

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

    function test_ShouldHaveTwoFacets() public view {
        IDiamondLoupe.Facet[] memory facets = diamondLoupe.facets();
        assertEq(facets.length, 2);
    }

    function test_ShouldHaveCutFacetSelector() public view {
        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(cut));
        assertEq(selectors.length, 1);
        bytes4 selector = cut.diamondCut.selector;
        assertEq(selectors[0], selector);
    }

    function test_ShouldHaveLoupeFacetSelector() public view {
        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(loupe));
        assertEq(selectors.length, 5);
        bytes4 selector = loupe.facets.selector;
        assert(containsElement(selectors, selector));
        selector = loupe.facetAddress.selector;
        assert(containsElement(selectors, selector));
        selector = loupe.facetFunctionSelectors.selector;
        assert(containsElement(selectors, selector));
        selector = loupe.facetAddresses.selector;
        assert(containsElement(selectors, selector));
        selector = loupe.supportsInterface.selector;
        assert(containsElement(selectors, selector));
    }

    function test_AddFacet() public {
        AtlasNFTFacet newFacet = new AtlasNFTFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);

        bytes4[] memory selectorsArray = new bytes4[](2);
        selectorsArray[0] = newFacet.mint.selector;
        selectorsArray[1] = newFacet.balanceOf.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));

        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(newFacet));
        assertEq(selectors.length, 2);

        bytes4 mintSelector = newFacet.mint.selector;
        assertEq(selectors[0], mintSelector);
        bytes4 balanceSelector = newFacet.balanceOf.selector;
        assertEq(selectors[1], balanceSelector);

        INFTFacet nft = INFTFacet(address(diamond));
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 0);
        nft.mint{value: 0.0001 ether}();
        balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
    }

    function test_RemoveFacet() public {
        AtlasNFTFacet newFacet = _addAtlasNFTFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);

        bytes4[] memory selectorsArray = new bytes4[](1);
        selectorsArray[0] = newFacet.mint.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(0),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));

        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(newFacet));
        assertEq(selectors.length, 2);

        bytes4 balanceSelector = newFacet.balanceOf.selector;
        assertEq(selectors[1], balanceSelector);
        bytes4 ownerOfSelector = newFacet.ownerOf.selector;
        assertEq(selectors[0], ownerOfSelector);
    }

    function test_addLevelingFacet() public {
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

        bytes4 data = newFacet.initialize.selector;

        (uint256[] memory lvlToExp, uint256[] memory lvlToRew) = _buildLvlArrays();

        facetCut.diamondCut(diamondCut, address(newFacet), abi.encodeWithSelector(data, lvlToExp, lvlToRew));

        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(newFacet));
        assertEq(selectors.length, 2);

        bytes4 levelUpSelector = newFacet.levelUp.selector;
        assertEq(selectors[0], levelUpSelector);
        bytes4 levelDownSelector = newFacet.levelDown.selector;
        assertEq(selectors[1], levelDownSelector);
    }

    function test_addTokenRouterFacetV2() public {
        TokenRouterFacetV2 newFacet = new TokenRouterFacetV2(address(originMailbox));
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](1);
        selectorsArray[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256)"));

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));

        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(newFacet));
        assertEq(selectors.length, 1);

        bytes4 getTransferRemoteSelector = bytes4(keccak256("transferRemote(uint32,bytes32,uint256)"));
        assertEq(selectors[0], getTransferRemoteSelector);
    }

    function test_addFightingFacet() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        DiamondCutFacet facetCut = DiamondCutFacet(address(diamond));
        FightingFacet newFacet = new FightingFacet();
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](2);
        selectorsArray[0] = newFacet.commit.selector;
        selectorsArray[1] = newFacet.reveal.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(
            diamondCut, address(newFacet), abi.encodeWithSelector(newFacet.initialize.selector, address(0))
        );

        bytes4[] memory selectors = diamondLoupe.facetFunctionSelectors(address(newFacet));
        assertEq(selectors.length, 2);
        bytes4 commitSelector = newFacet.commit.selector;
        assertEq(selectors[0], commitSelector);
        bytes4 revealSelector = newFacet.reveal.selector;
        assertEq(selectors[1], revealSelector);
    }

    function test_MintReplaceReMintValidStorage() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        INFTFacet nft = INFTFacet(address(diamond));
        nft.mint{value: 0.0001 ether}();
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
        address owner = nft.ownerOf(0);
        assertEq(owner, address(this));

        AtlasNFTFacet newFacet2 = new AtlasNFTFacet();

        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](3);
        selectorsArray[0] = newFacet2.mint.selector;
        selectorsArray[1] = newFacet2.balanceOf.selector;
        selectorsArray[2] = newFacet2.ownerOf.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet2),
            action: IDiamond.FacetCutAction.Replace,
            functionSelectors: selectorsArray
        });
        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));
        bytes4[] memory s = new bytes4[](1);
        s[0] = newFacet2.tokenOfOwnerByIndex.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet2),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: s
        });
        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));

        assertEq(nft.ownerOf(0), address(this));

        uint256 fees = dataInterface.getFees().mintingFees;
        nft.mint{value: fees}();
        balance = nft.balanceOf(address(this));
        assertEq(balance, 2);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenID = AtlasNFTFacet(address(diamond)).tokenOfOwnerByIndex(address(this), i);
            assertEq(tokenID, i * 50, "Token ID should be equal to i*50");
        }
    }

    function test_LevelingAnNFTAndRevertIfMaxLevel() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        _addLevelingFacet();
        _addAtlasERC20Facet();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        INFTFacet nft = INFTFacet(address(diamond));
        LevelingFacet leveling = LevelingFacet(address(diamond));
        uint256 fees = dataInterface.getFees().mintingFees;
        nft.mint{value: fees}();
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
        address owner = nft.ownerOf(0);
        assertEq(owner, address(this));

        for (uint256 i = 0; i < 50; i++) {
            if (i > 48) {
                vm.expectRevert("Can't level up past max level");
            }
            leveling.levelUp(i);
            assertEq(nft.balanceOf(address(this)), 1);
        }
    }

    function test_Bridging() public {
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        _addTokenRouterFacetV2();
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        INFTFacet nft = INFTFacet(address(diamond));

        uint256 fees = dataInterface.getFees().mintingFees;
        nft.mint{value: fees}();

        TokenRouterFacetV2 hypInterface = TokenRouterFacetV2(payable(address(diamond)));
        uint32 domain = 2;

        hypInterface.setGas(domain, 330_000);
        hypInterface.enrollRemoteRouter(domain, bytes32("0x1"));
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
        address owner = nft.ownerOf(0);
        assertEq(owner, address(this));

        bytes32 recipient = bytes32(uint256(uint160(address(this))));
        uint256 amount = 0;
        uint256 pfees = dataInterface.getFees().mintingFees;
        uint256 bfees = hypInterface.quoteGasPayment(domain);
        hypInterface.transferRemote{value: pfees + bfees}(domain, recipient, amount, false);
    }

    function test_BridgeBack() public {
        _addAtlasNFTFacet();
        DataInterfaceFacet dataInterfaceFacet = _addDataInterfaceFacet();
        _addTokenRouterFacetV2();
        address receiver = _createMockDiamond();

        //--------------Adding the DataInterfaceFacet to the receiver--------------
        IDiamondCut facetCut = IDiamondCut(address(receiver));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](3);
        selectorsArray[0] = dataInterfaceFacet.getFees.selector;
        selectorsArray[1] = dataInterfaceFacet.commitCost.selector;
        selectorsArray[2] = dataInterfaceFacet.ownerSetMintingFees.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(dataInterfaceFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });
        facetCut.diamondCut(
            diamondCut, address(dataInterfaceFacet), abi.encodeWithSelector(dataInterfaceFacet.initialize.selector)
        );
        //-------------------------------------------------------------------------

        AtlasNFTFacet receiverDiamondNFT = AtlasNFTFacet(address(receiver));
        TokenRouterFacetV2 receiverDiamondHL = TokenRouterFacetV2(payable(address(receiver)));

        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        INFTFacet nft = INFTFacet(address(diamond));

        uint256 fees = dataInterface.getFees().mintingFees;
        nft.mint{value: fees}();

        TokenRouterFacetV2 hypInterface = TokenRouterFacetV2(payable(address(diamond)));
        uint32 domain = 2;

        hypInterface.setGas(domain, 330_000);
        receiverDiamondHL.setGas(1, 330_000);

        hypInterface.enrollRemoteRouter(domain, bytes32(uint256(uint160(address(receiver)))));
        receiverDiamondHL.enrollRemoteRouter(1, bytes32(uint256(uint160(address(diamond)))));

        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
        address owner = nft.ownerOf(0);
        assertEq(owner, address(this));

        bytes32 recipient = bytes32(uint256(uint160(address(this))));
        uint256 amount = 0;
        uint256 pfees = dataInterface.getFees().mintingFees;
        uint256 bfees = hypInterface.quoteGasPayment(domain);

        hypInterface.transferRemote{value: pfees + bfees}(domain, recipient, amount, false);
        destinationMailbox.processNextInboundMessage();
        balance = nft.balanceOf(address(this));
        assertEq(balance, 0);
        uint256 receiverBalance = receiverDiamondNFT.balanceOf(address(this));
        assertEq(receiverBalance, 1);

        receiverDiamondHL.transferRemote{value: pfees + bfees}(1, recipient, amount, false);
        originMailbox.processNextInboundMessage();
        balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
        receiverBalance = receiverDiamondNFT.balanceOf(address(this));
        assertEq(receiverBalance, 0);
    }

    function test_Fight() public {
        _addFightingFacet();
        _addAtlasNFTFacet();
        _addDataInterfaceFacet();
        FightingFacet fighting = FightingFacet(address(diamond));
        INFTFacet nft = INFTFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 fees = dataInterface.getFees().mintingFees;
        nft.mint{value: fees}();
        uint256 ID = 0;
        uint256 commitCost = dataInterface.commitCost(ID, 50);
        bytes32 nonce = fighting.generateRandomHash(ID);
        bytes32 commitHash = keccak256(abi.encodePacked(nonce));
        vm.expectEmit(true, true, true, false);
        emit CommitMade(address(this), 0, commitHash);
        fighting.commit{value: commitCost}(0, commitHash);
    }

    function test_DistinctStorage() public {
        AtlasNFTFacet atlasNFTFacet = _addAtlasNFTFacet();
        DataInterfaceFacet dataInterfaceFacet = _addDataInterfaceFacet();
        INFTFacet nft = INFTFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));

        address distinctDiamond = _createMockDiamond();
        IDiamondCut facetCut = IDiamondCut(address(distinctDiamond));

        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](2);
        selectorsArray[0] = atlasNFTFacet.balanceOf.selector;
        selectorsArray[1] = atlasNFTFacet.mint.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(0),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: selectorsArray
        });
        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));
        selectorsArray[0] = atlasNFTFacet.balanceOf.selector;
        selectorsArray[1] = atlasNFTFacet.mint.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(atlasNFTFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });
        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));
        bytes4[] memory selectorsArray_ = new bytes4[](1);
        selectorsArray_[0] = dataInterfaceFacet.getFees.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(dataInterfaceFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray_
        });
        facetCut.diamondCut(
            diamondCut, address(dataInterfaceFacet), abi.encodeWithSelector(dataInterfaceFacet.initialize.selector)
        );

        INFTFacet distinctNFT = INFTFacet(address(distinctDiamond));
        uint256 fees = dataInterface.getFees().mintingFees;
        distinctNFT.mint{value: fees}();
        address owner = distinctNFT.ownerOf(100_000);
        assertEq(owner, address(this));
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 0);
        balance = distinctNFT.balanceOf(address(this));
        assertEq(balance, 1);
        nft.mint{value: fees}();
        balance = nft.balanceOf(address(this));
        assertEq(balance, 1);
        owner = nft.ownerOf(0);
        assertEq(owner, address(this));
        owner = distinctNFT.ownerOf(100_000);
        assertEq(owner, address(this));
        owner = distinctNFT.ownerOf(0);
        assertEq(owner, address(0));
    }

    function test_LevelUpShouldRevertOnNoNFTCut() public {
        _addLevelingFacet();
        LevelingFacet leveling = LevelingFacet(address(diamond));
        vm.expectRevert("NFT facet not found");
        leveling.levelUp(0);
    }

    function test_BridgeShouldRevertOnNoNFTCut() public {
        _addTokenRouterFacetV2();
        TokenRouterFacetV2 hypInterface = TokenRouterFacetV2(payable(address(diamond)));
        vm.expectRevert("NFT facet not found");
        hypInterface.transferRemote(0, bytes32(0), 0, false);
    }

    function test_BridgeShouldRevertOnNoDataCut() public {
        _addTokenRouterFacetV2();
        _addAtlasNFTFacet();
        TokenRouterFacetV2 hypInterface = TokenRouterFacetV2(payable(address(diamond)));
        vm.expectRevert("DataInterfaceFacet not found");
        hypInterface.transferRemote(0, bytes32(0), 0, false);
    }

    function test_FightShouldRevertOnNoNFTCut() public {
        _addFightingFacet();
        _addDataInterfaceFacet();
        FightingFacet fighting = FightingFacet(address(diamond));
        DataInterfaceFacet dataInterface = DataInterfaceFacet(address(diamond));
        uint256 ID = 0;
        uint256 commitCost = dataInterface.commitCost(ID, 50);
        vm.expectRevert("NFT facet not found");
        bytes32 nonce = fighting.generateRandomHash(ID);
        bytes32 commitHash = keccak256(abi.encodePacked(nonce));
        vm.expectRevert("NFT facet not found");
        fighting.commit{value: commitCost}(0, commitHash);
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

        bytes memory data = abi.encodeWithSignature(
            "initialize(uint256,uint256,uint8,string,string)", 0, 100_000, 0, "testToken", "TTT"
        );

        facetCut.diamondCut(diamondCut, address(newFacet), data);

        return newFacet;
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

    function _addDataInterfaceFacet() private returns (DataInterfaceFacet) {
        DataInterfaceFacet newFacet = new DataInterfaceFacet();
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);

        bytes4[] memory selectorsArray = new bytes4[](2);
        selectorsArray[0] = newFacet.getFees.selector;
        selectorsArray[1] = newFacet.commitCost.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(diamondCut, address(newFacet), abi.encodeWithSelector(newFacet.initialize.selector));

        return newFacet;
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

    function _addFightingFacet() private returns (FightingFacet) {
        DiamondCutFacet facetCut = DiamondCutFacet(address(diamond));
        FightingFacet newFacet = new FightingFacet();
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](3);
        selectorsArray[0] = newFacet.commit.selector;
        selectorsArray[1] = newFacet.reveal.selector;
        selectorsArray[2] = newFacet.generateRandomHash.selector;
        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });
        facetCut.diamondCut(
            diamondCut, address(newFacet), abi.encodeWithSelector(newFacet.initialize.selector, address(0))
        );
        return newFacet;
    }

    function _addTokenRouterFacetV2() private returns (TokenRouterFacetV2) {
        TokenRouterFacetV2 newFacet = new TokenRouterFacetV2(address(originMailbox));
        IDiamondCut facetCut = IDiamondCut(address(diamond));
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](5);
        selectorsArray[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256,bool)"));
        selectorsArray[1] = newFacet.setGas.selector;
        selectorsArray[2] = newFacet.enrollRemoteRouter.selector;
        selectorsArray[3] = newFacet.quoteGasPayment.selector;
        selectorsArray[4] = newFacet.handle.selector;

        diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        facetCut.diamondCut(diamondCut, address(0), bytes("0x"));

        return newFacet;
    }

    function _mailBoxSetup() private {
        originMailbox = new MockMailbox(1);
        destinationMailbox = new MockMailbox(2);
        originMailbox.addRemoteMailbox(2, destinationMailbox);
        destinationMailbox.addRemoteMailbox(1, originMailbox);
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

        TokenRouterFacetV2 newFacet = new TokenRouterFacetV2(address(destinationMailbox));
        AtlasNFTFacet newFacet2 = new AtlasNFTFacet();

        IDiamondCut facetCut = IDiamondCut(address(_diamond));
        IDiamond.FacetCut[] memory diamondCut_ = new IDiamond.FacetCut[](1);
        bytes4[] memory selectorsArray = new bytes4[](5);
        selectorsArray[0] = bytes4(keccak256("transferRemote(uint32,bytes32,uint256,bool)"));
        selectorsArray[1] = newFacet.setGas.selector;
        selectorsArray[2] = newFacet.enrollRemoteRouter.selector;
        selectorsArray[3] = newFacet.quoteGasPayment.selector;
        selectorsArray[4] = newFacet.handle.selector;

        diamondCut_[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray
        });

        bytes memory data = abi.encodeWithSignature(
            "initialize(uint256,uint256,uint8,string,string)", 100_000, 200_000, 0, "TTT", "testToken"
        );

        facetCut.diamondCut(diamondCut_, address(newFacet2), data);

        bytes4[] memory selectorsArray2 = new bytes4[](3);
        selectorsArray2[0] = newFacet2.mint.selector;
        selectorsArray2[1] = newFacet2.balanceOf.selector;
        selectorsArray2[2] = newFacet2.ownerOf.selector;

        diamondCut_[0] = IDiamond.FacetCut({
            facetAddress: address(newFacet2),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectorsArray2
        });

        facetCut.diamondCut(diamondCut_, address(0), bytes("0x"));
        // newFacet2.initialize(0, 100_000, "testToken", "TTT");

        return address(_diamond);
    }
}
