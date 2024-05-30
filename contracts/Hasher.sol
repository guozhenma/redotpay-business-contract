// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Hasher {
    function hashSettleAndRefund(
        string memory orderId,
        address[] memory receivers,
        uint256[] memory amounts,
        address usdcAddress,
        uint256 expireTime
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                orderId,
                block.chainid,
                receivers,
                amounts,
                usdcAddress,
                expireTime,
                address(this)
            )
        );
        return operationHash;
    }

    function hashWithdraws(
        string memory orderId,
        address[] memory receivers,
        uint256[] memory amounts,
        uint256[] memory fees,
        address usdcAddress,
        uint256 expireTime
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                orderId,
                block.chainid,
                receivers,
                amounts,
                fees,
                usdcAddress,
                expireTime,
                address(this)
            )
        );
        return operationHash;
    }
}
