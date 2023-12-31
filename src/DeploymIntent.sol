// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ZoneInterface} from "seaport-types/interfaces/ZoneInterface.sol";
import {Schema, ZoneParameters} from "seaport-types/lib/ConsiderationStructs.sol";
import {SIP5} from "shipyard-core/reference/sips/SIP5.sol";
import {IERC165} from "forge-std/interfaces/IERC165.sol";

struct DeployParams {
    uint256 initialValue;
    bytes32 salt;
    bytes data;
}

contract DeploymIntent is ZoneInterface, SIP5 {
    address public immutable SEAPORT;
    uint256 constant CREATE2_FAILED_SELECTOR = 0x04a5b3ee;
    uint256 constant UNABLE_TO_DERIVE_ZONE_HASH_SELECTOR = 0x2698ad98;
    uint256 constant PACKED_ADDRESS_OFFSET = 0x0C;
    uint256 constant PACKED_HASH_LENGTH = 0x34;
    uint256 constant SELECTOR_OFFSET = 0x1c;
    uint256 constant NATIVE_TRANSFER_FAILED_SELECTOR = 0xf4b3b1bc;

    error OnlySeaport();
    ///@dev selector 0x04a5b3ee
    error Create2Failed();
    ///@dev selector 0x2698ad98
    error UnableToDeriveZoneHash();
    ///@dev selector 0xf4b3b1bc
    error NativeTransferFailed();

    constructor(address seaport) {
        SEAPORT = seaport;
    }

    /**
     * @notice Allow receiving native tokens so that contracts may be seeded with
     *         an initial balance.
     */
    receive() external payable {}

    /**
     * @notice Anyone can claim the balance of this contract. If the balance is
     *         claimed during Seaport fulfillment, and subsequent orders rely
     *         on a non-zero balance, the whole fulfillment will fail. Thus,
     *         a reentrancy guard is not necessary.
     */
    function claimBalance() external {
        assembly {
            let succ := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
            if iszero(succ) {
                mstore(0, NATIVE_TRANSFER_FAILED_SELECTOR)
                revert(SELECTOR_OFFSET, 4)
            }
        }
    }

    function name() public pure override returns (string memory) {
        return "DeploymIntent";
    }

    function getSeaportMetadata()
        external
        pure
        override(SIP5, ZoneInterface)
        returns (string memory, Schema[] memory schemas)
    {
        schemas = new Schema[](1);
        schemas[0] = _sip5Schema();
        return (name(), schemas);
    }

    function supportsInterface(bytes4 interfaceId) external pure override(ZoneInterface, IERC165) returns (bool) {
        return interfaceId == type(ZoneInterface).interfaceId;
    }

    function validateOrder(ZoneParameters calldata zoneParameters) external returns (bytes4) {
        if (msg.sender != SEAPORT) {
            revert OnlySeaport();
        }
        // decode intent params
        DeployParams memory intent = abi.decode(zoneParameters.extraData, (DeployParams));
        // place vals onto stack for assembly block
        uint256 value = intent.initialValue;
        bytes32 salt = intent.salt;
        bytes memory data = intent.data;
        address deployed;

        assembly ("memory-safe") {
            deployed := create2(value, add(data, 0x20), mload(data), salt)
            if iszero(deployed) {
                mstore(0, CREATE2_FAILED_SELECTOR)
                revert(SELECTOR_OFFSET, 4)
            }
        }

        // hash the deployed address and initial value, then compare to the zone hash
        bytes32 derivedZoneHash;
        bytes32 zoneHash = zoneParameters.zoneHash;
        assembly ("memory-safe") {
            mstore(0, deployed)
            mstore(0x20, value)
            derivedZoneHash := keccak256(PACKED_ADDRESS_OFFSET, PACKED_HASH_LENGTH)
            if iszero(eq(derivedZoneHash, zoneHash)) {
                mstore(0, UNABLE_TO_DERIVE_ZONE_HASH_SELECTOR)
                revert(SELECTOR_OFFSET, 4)
            }
        }

        return this.validateOrder.selector;
    }

    function computeZoneHash(bytes calldata data, bytes32 salt, uint256 initialValue) external view returns (bytes32) {
        return computeZoneHash(keccak256(data), salt, initialValue);
    }

    function computeZoneHash(bytes32 initCodeHash, bytes32 salt, uint256 initialValue) public view returns (bytes32) {
        address addr = predictCreate2Address(initCodeHash, salt);
        return keccak256(abi.encodePacked(addr, initialValue));
    }

    function predictCreate2Address(bytes32 initcodeHash, bytes32 salt) internal view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initcodeHash)))));
    }
}
