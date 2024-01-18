// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Business is Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public immutable USDC_ADDRESS; // usdc contract address

    address[] public signers; // singer's addresses
    bool isDisabled; // status bit that control whether a contract is available

    mapping(address => uint256) public balances; // users' balances
    uint256 public banlanceOfOwner; // owner's balance

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
        IERC20 token,
        uint256 amount
    ) external payable notDisabled {
        if (address(token) == USDC_ADDRESS) {
            token.safeTransferFrom(msg.sender, address(this), amount);
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
    ) external notDisabled {
        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");
        require(expireTime >= block.timestamp, "expired transaction");

        bytes32 operationHash = keccak256(
            abi.encodePacked(
                "ERC20",
                to,
                amount,
                USDC_ADDRESS,
                expireTime,
                address(this)
            )
        );

        for (uint8 index = 0; index < signers.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == signers[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        IERC20(USDC_ADDRESS).safeTransfer(to, amount);
        banlanceOfOwner -= amount;
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
    ) external notDisabled {
        require(receivers.length == amounts.length, "arrays length mismatch");
        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");
        require(expireTime >= block.timestamp, "expired transaction");

        bytes32 operationHash = keccak256(
            abi.encodePacked(
                "ERC20",
                receivers,
                amounts,
                USDC_ADDRESS,
                expireTime,
                address(this)
            )
        );

        for (uint8 index = 0; index < signers.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == signers[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        for (uint8 index = 0; index < receivers.length; index++) {
            address to = receivers[index];
            uint256 amount = amounts[index];
            IERC20(USDC_ADDRESS).safeTransfer(to, amount);
        }
    }

    /**
     *
     * @param accounts      the accounts to be settled
     * @param amounts       the amounts to be settled
     * @param allSigners    all signer who sign the tx
     * @param signatures    the signatures of tx
     */
    function settle(
        address[] memory accounts,
        uint256[] memory amounts,
        address[] memory allSigners,
        bytes[] memory signatures
    ) external notDisabled {
        require(accounts.length == amounts.length, "arrays length mismatch");

        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");

        bytes32 operationHash = keccak256(abi.encodePacked(accounts, amounts));

        for (uint8 index = 0; index < signers.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == signers[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "invalid address");
            require(amounts[i] > 0, "invalid amount");

            address account = accounts[i];
            uint256 amount = amounts[i];
            require(balances[account] >= amount, "insufficient banlance");

            balances[account] -= amount;
            banlanceOfOwner += amount;
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
    function banlanceOf(address account) public view returns (uint256) {
        require(
            msg.sender == account || msg.sender == this.owner(),
            "You don't have access to that."
        );

        return balances[account];
    }

    /**
     * get the whole balance of this contract
     */
    function banlance() external view returns (uint256) {
        return IERC20(USDC_ADDRESS).balanceOf(address(this));
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
