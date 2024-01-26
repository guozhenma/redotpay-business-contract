// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Business is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable USDC_ADDRESS; // usdc contract address

    address[] public signers; // singer's addresses
    bool isDisabled; // status bit that control whether a contract is available

    mapping(address => uint256) public balances; // users' balances
    uint256 public balanceOfOwner; // owner's balance

    modifier notDisabled() {
        require(!isDisabled, "Contract is disabled.");
        _;
    }

    constructor(address[] memory allSigners, address usdc) Ownable(msg.sender) {
        require(allSigners.length == 3, "invalid signers length");
        require(allSigners[0] != allSigners[1], "must be different signers");
        require(allSigners[0] != allSigners[2], "must be different signers");
        require(allSigners[1] != allSigners[2], "must be different signers");

        require(usdc != address(0), "invalid usdc address");

        USDC_ADDRESS = usdc;
        signers = allSigners;
        isDisabled = false;
    }

    /**
     * Deposit ERC20 tokens to this wallet. Automatically convert tokens to usdc through DEX.
     * @param token     the token to be deposited
     * @param amount    the amount in Wei to be deposited
     */
    function deposit(
        address token,
        uint256 amount
    ) external payable notDisabled nonReentrant {
        if (token == USDC_ADDRESS) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            balances[msg.sender] += amount;
        } else {
            // TODO: swap other currency to USDC
        }
    }

    /**
     *  Withdraw USDC from this wallet to owner's address using 2 signers.
     *
     * @param to            the destination address to send an outgoing transaction
     * @param amount        the amount in Wei to be sent
     * @param expireTime    the number of seconds since 1970 for which this transaction is valid
     * @param allSigners    all signer who sign the tx
     * @param signatures    the signatures of tx
     */
    function withdraw(
        address to,
        uint256 amount,
        uint256 expireTime,
        address[] memory allSigners,
        bytes[] memory signatures
    ) external notDisabled nonReentrant {
        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");
        require(expireTime >= block.timestamp, "expired transaction");

        bytes32 operationHash = _hashWithdraw(to, amount, expireTime);
        operationHash = MessageHashUtils.toEthSignedMessageHash(operationHash);

        for (uint8 index = 0; index < allSigners.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == allSigners[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        IERC20(USDC_ADDRESS).safeTransfer(to, amount);
        balanceOfOwner -= amount;
    }

    /**
     *  Withdraw user's USDC from this wallet to user's address using 2 signers.
     *
     * @param receivers     the destination address to send an outgoing transaction
     * @param amounts       the amounts in Wei to be sent
     * @param expireTime    the number of seconds since 1970 for which this transaction is valid
     * @param allSigners    all signer who sign the tx
     * @param signatures    the signatures of tx
     */
    function withdraws(
        address[] memory receivers,
        uint256[] memory amounts,
        uint256 expireTime,
        address[] memory allSigners,
        bytes[] memory signatures
    ) external notDisabled nonReentrant {
        require(receivers.length == amounts.length, "arrays length mismatch");
        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");
        require(expireTime >= block.timestamp, "expired transaction");

        bytes32 operationHash = _hasWithdraws(receivers, amounts, expireTime);
        operationHash = MessageHashUtils.toEthSignedMessageHash(operationHash);

        for (uint8 index = 0; index < allSigners.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == allSigners[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        for (uint8 index = 0; index < receivers.length; index++) {
            address to = receivers[index];
            uint256 amount = amounts[index];

            require(to != address(0), "invalid address");
            require(amount > 0, "invalid amount");
            require(balances[to] >= amount, "insufficient balance");
            IERC20(USDC_ADDRESS).safeTransfer(to, amount);
            balances[to] -= amount;
        }
    }

    /**
     *
     * @param accounts      the accounts to be settled
     * @param amounts       the amounts to be settled
     * @param expireTime    the number of seconds since 1970 for which this transaction is valid
     * @param allSigners    all signer who sign the tx
     * @param signatures    the signatures of tx
     */
    function settle(
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 expireTime,
        address[] memory allSigners,
        bytes[] memory signatures
    ) external notDisabled nonReentrant {
        require(accounts.length == amounts.length, "arrays length mismatch");

        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");
        require(expireTime >= block.timestamp, "expired transaction");

        bytes32 operationHash = MessageHashUtils.toEthSignedMessageHash(
            _hasWithdraws(accounts, amounts, expireTime)
        );

        for (uint8 index = 0; index < allSigners.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == allSigners[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "invalid address");
            require(amounts[i] > 0, "invalid amount");

            address account = accounts[i];
            uint256 amount = amounts[i];
            require(balances[account] >= amount, "insufficient balance");

            balances[account] -= amount;
            balanceOfOwner += amount;
        }
    }

    /**
     * disable the contract
     */
    function disableContract() external onlyOwner {
        isDisabled = true;
    }

    /**
     * enable the contract
     */
    function enableContract() external onlyOwner {
        isDisabled = false;
    }

    /**
     * set signers
     * @param allSigners allowed signers
     */
    function setSigners(address[] memory allSigners) external onlyOwner {
        require(allSigners.length == 3, "invalid withdrawalMgrs length");
        require(allSigners[0] != allSigners[1], "must be different signers");
        require(allSigners[0] != allSigners[2], "must be different signers");
        require(allSigners[1] != allSigners[2], "must be different signers");
        signers = allSigners;
    }

    /**
     * get the balance of a given address
     * @param account address to search
     */
    function balanceOf(address account) public view returns (uint256) {
        if (account == owner()) {
            require(msg.sender == owner(), "You don't have access to that.");
            return balanceOfOwner;
        } else {
            require(
                msg.sender == account || msg.sender == owner(),
                "You don't have access to that."
            );
            return balances[account];
        }
    }

    /**
     * get the whole balance of this contract
     */
    function balance() external view returns (uint256) {
        return IERC20(USDC_ADDRESS).balanceOf(address(this));
    }

    // ============================= internals =============================

    function _hasWithdraws(
        address[] memory receivers,
        uint256[] memory amounts,
        uint256 expireTime
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                receivers,
                amounts,
                USDC_ADDRESS,
                expireTime,
                address(this)
            )
        );
        return operationHash;
    }

    function _hashWithdraw(
        address to,
        uint256 amount,
        uint256 expireTime
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                to,
                amount,
                USDC_ADDRESS,
                expireTime,
                address(this)
            )
        );
        return operationHash;
    }

    function _isAllowedSigner(address signer) internal view returns (bool) {
        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                return true;
            }
        }
        return false;
    }
}
