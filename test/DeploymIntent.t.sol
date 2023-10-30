// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {DeploymIntent, DeployParams} from "src/./DeploymIntent.sol";
import {ZoneParameters, Schema} from "seaport-types/lib/ConsiderationStructs.sol";
import {ZoneInterface} from "seaport-types/interfaces/ZoneInterface.sol";
import {ISIP5} from "shipyard-core/interfaces/sips/ISIP5.sol";

contract Mock {
    uint256 immutable value;

    constructor(uint256 _value) payable {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }
}

contract DeploymIntentTest is Test {
    DeploymIntent target;

    function setUp() public {
        target = new DeploymIntent(address(this));
    }

    receive() external payable {}

    function testConstructorEvent() public {
        vm.expectEmit(true, false, false, false);
        emit ISIP5.SeaportCompatibleContractDeployed();
        new DeploymIntent(address(this));
    }

    function testReceiveAndClaimBalance() public {
        uint256 startingBalance = address(this).balance;

        payable(target).transfer(1 ether);
        assertEq(address(target).balance, 1 ether);
        target.claimBalance();
        assertEq(address(target).balance, 0);
        assertEq(address(this).balance, startingBalance);
    }

    function testClaimBalance_Failed() public {
        Mock mock = new Mock(0);
        vm.prank(address(mock));
        vm.expectRevert(DeploymIntent.NativeTransferFailed.selector);
        target.claimBalance();
    }

    function testValidateOrder() public {
        DeployParams memory deployParams = DeployParams({
            initialValue: 1 ether,
            salt: bytes32(uint256(1234)),
            data: abi.encodePacked(type(Mock).creationCode, abi.encode(uint256(69)))
        });

        ZoneParameters memory parameters;
        parameters.zoneHash = target.computeZoneHash(deployParams.data, bytes32(uint256(1234)), 1 ether);
        parameters.extraData = abi.encode(deployParams);

        payable(target).transfer(1 ether);
        bytes4 val = target.validateOrder(parameters);
        assertEq(val, DeploymIntent.validateOrder.selector);
    }

    function testValidateOrder_BadAddress() public {
        DeployParams memory deployParams = DeployParams({
            initialValue: 1 ether,
            // wrong salt results in bad address
            salt: bytes32(0),
            data: abi.encodePacked(type(Mock).creationCode, abi.encode(uint256(69)))
        });

        ZoneParameters memory parameters;
        parameters.zoneHash = target.computeZoneHash(deployParams.data, bytes32(uint256(1234)), 1 ether);
        parameters.extraData = abi.encode(deployParams);

        payable(target).transfer(1 ether);
        vm.expectRevert(DeploymIntent.UnableToDeriveZoneHash.selector);
        target.validateOrder(parameters);
    }

    function testValidateOrder_BadInitialValue() public {
        DeployParams memory deployParams = DeployParams({
            // wrong initial value results in bad zoneHash
            initialValue: 1 ether,
            salt: bytes32(0),
            data: abi.encodePacked(type(Mock).creationCode, abi.encode(uint256(69)))
        });

        ZoneParameters memory parameters;
        parameters.zoneHash = target.computeZoneHash(deployParams.data, bytes32(uint256(1234)), 2 ether);
        parameters.extraData = abi.encode(deployParams);

        payable(target).transfer(2 ether);
        vm.expectRevert(DeploymIntent.UnableToDeriveZoneHash.selector);
        target.validateOrder(parameters);
    }

    function testValidateOrder_NotEnoughFunds() public {
        DeployParams memory deployParams = DeployParams({
            // wrong initial value results in bad zoneHash
            initialValue: 1 ether,
            salt: bytes32(0),
            data: abi.encodePacked(type(Mock).creationCode, abi.encode(uint256(69)))
        });

        ZoneParameters memory parameters;
        parameters.zoneHash = target.computeZoneHash(deployParams.data, bytes32(uint256(1234)), 1 ether);
        parameters.extraData = abi.encode(deployParams);

        // try to execute without enough funds
        vm.expectRevert(DeploymIntent.Create2Failed.selector);
        target.validateOrder(parameters);
    }

    function testValidateOrder(bytes32 salt, uint256 immutableVal, uint64 nativeAmount) public {
        DeployParams memory deployParams = DeployParams({
            initialValue: nativeAmount,
            salt: salt,
            data: abi.encodePacked(type(Mock).creationCode, abi.encode(immutableVal))
        });

        ZoneParameters memory parameters;
        parameters.zoneHash = target.computeZoneHash(deployParams.data, salt, nativeAmount);
        parameters.extraData = abi.encode(deployParams);

        payable(target).transfer(nativeAmount);
        bytes4 val = target.validateOrder(parameters);
        assertEq(val, DeploymIntent.validateOrder.selector);
    }

    function testValidateOrder_OnlySeaport() public {
        address notSeaport = makeAddr("not seaport");
        vm.prank(notSeaport);
        vm.expectRevert(DeploymIntent.OnlySeaport.selector);
        ZoneParameters memory params;
        target.validateOrder(params);
    }

    function testSupportsInterface() public {
        assertEq(target.supportsInterface(type(ZoneInterface).interfaceId), true);
    }

    function testName() public {
        assertEq(target.name(), "DeploymIntent");
    }

    function testGetSeaportMetadata() public {
        (string memory name, Schema[] memory schemas) = target.getSeaportMetadata();
        assertEq(name, "DeploymIntent");
        assertEq(schemas.length, 1);
        assertEq(schemas[0].id, 5);
        assertEq(schemas[0].metadata.length, 0);
    }
}
