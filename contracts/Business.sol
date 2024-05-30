// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IAggregationRouterV5} from "./IAggregationRouterV5.sol";
import {ECDSAHelper} from "./ECDSAHelper.sol";

contract Business is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // Events
    event Deposit(
        string sn, // 充值订单号
        uint chainId, // 区块链id
        address from, // 充值用户的地址
        address token, // 充值的币种
        uint256 spentAmount, // 充值的数量
        uint256 usdcAmount // 兑换成 USDC 之后的数量
    );

    event BuyCard(
        string sn, // 购卡订单号
        uint chainId, // 区块链id
        address from, // 购卡用户的地址
        address token, // 购卡使用的币种，目前只支持 USDC
        uint256 amount // 购卡使用的币的数量，目前只支持 USDC
    );

    event Settle(string sn, address[] accounts, uint256[] amounts);

    event Refund(string sn, address[] accounts, uint256[] amounts);

    event Withdraws(
        string sn,
        address[] accounts,
        uint256[] amounts,
        uint256[] fees
    );

    event Withdraw(address to, uint256 amount);

    address public USDC_ADDRESS; // usdc contract address
    address public AGGREGATION_ROUTER_V5_ADDRESS; // 1inch AggregationRouterV5  address
    address[] public signers; // singer's addresses
    bool isDisabled; // status bit that control whether a contract is available

    mapping(address => uint256) public balances; // users' balances
    uint256 public balanceOfOwner; // owner's balance

    IERC20 private constant ETH_ADDRESS =
        IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 private constant ZERO_ADDRESS = IERC20(address(0));

    mapping(address => uint256) public outstandingBalances; // 用户欠费记录。消费金额大于充值金额的情况
    modifier notDisabled() {
        require(!isDisabled, "Contract is disabled.");
        _;
    }

    function initialize(
        address owner,
        address[] memory allSigners,
        address usdc,
        address aggregationRouterV5
    ) external initializer {
        require(owner != address(0), "invalid owner address");
        require(allSigners.length == 3, "invalid signers length");
        require(allSigners[0] != allSigners[1], "must be different signers");
        require(allSigners[0] != allSigners[2], "must be different signers");
        require(allSigners[1] != allSigners[2], "must be different signers");

        require(usdc != address(0), "invalid usdc address");
        __Ownable_init(owner);
        __ReentrancyGuard_init();
        USDC_ADDRESS = usdc;
        AGGREGATION_ROUTER_V5_ADDRESS = aggregationRouterV5;
        signers = allSigners;
        isDisabled = false;
    }

    /**
     * Gets called when a transaction is received without calling a method
     */
    receive() external payable {}

    /**
     * Buy card: Deposit USDC to owner address directly.
     * @param token     the token to be deposited
     * @param amount    the amount in Wei to be deposited
     */
    function buyCard(
        string memory orderId,
        address token,
        uint256 amount
    ) external payable notDisabled nonReentrant {
        require(token == USDC_ADDRESS, "Only support usdc");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        balanceOfOwner += amount;
        emit BuyCard(orderId, block.chainid, msg.sender, token, amount);
    }

    /**
     * Deposit ERC20 tokens to this wallet. Automatically convert tokens to usdc through DEX.
     * @param token     the token to be deposited
     * @param amount    the amount in Wei to be deposited
     */
    function deposit(
        string memory orderId,
        address token,
        uint256 amount,
        bytes calldata exchangeData
    ) external payable notDisabled nonReentrant returns (uint256) {
        uint256 usdcAmt;

        if (token == USDC_ADDRESS) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            balances[msg.sender] += amount;
            usdcAmt = amount;
        } else {
            uint256 beforeSwapBalance = IERC20(USDC_ADDRESS).balanceOf(
                address(this)
            );
            (, IAggregationRouterV5.SwapDescription memory desc, , ) = abi
                .decode(
                    exchangeData[4:],
                    (
                        address,
                        IAggregationRouterV5.SwapDescription,
                        bytes,
                        bytes
                    )
                );
            require(
                IERC20(token) == desc.srcToken,
                "mismatch token and desc.srcToken"
            );
            require(
                USDC_ADDRESS == address(desc.dstToken),
                "invalid desc.dstToken"
            );
            require(amount == desc.amount, "mismatch amount and desc.amount");
            require(
                address(this) == desc.dstReceiver,
                "invalid desc.dstReceiver"
            );

            bool isNativeToken = _isNative(desc.srcToken);
            if (!isNativeToken) {
                // deposit other ERC20 tokens
                desc.srcToken.safeTransferFrom(
                    msg.sender,
                    address(this),
                    desc.amount
                );

                // safeApprove requires unsetting the allowance first.
                desc.srcToken.forceApprove(AGGREGATION_ROUTER_V5_ADDRESS, 0);
                desc.srcToken.forceApprove(
                    AGGREGATION_ROUTER_V5_ADDRESS,
                    desc.amount
                );
            }

            // Swap token
            (
                bool success,
                bytes memory returndata
            ) = AGGREGATION_ROUTER_V5_ADDRESS.call{value: msg.value}(
                    exchangeData
                );
            require(success, "exchange failed");

            (usdcAmt, ) = abi.decode(returndata, (uint256, uint256));
            require(
                usdcAmt >= desc.minReturnAmount,
                "received USDC less than minReturnAmount"
            );

            uint256 afterSwapBalance = IERC20(USDC_ADDRESS).balanceOf(
                address(this)
            );
            require(
                afterSwapBalance == beforeSwapBalance + usdcAmt,
                "swap incorrect"
            );

            balances[msg.sender] += usdcAmt;
        }

        emit Deposit(
            orderId,
            block.chainid,
            msg.sender,
            token,
            amount,
            usdcAmt
        );
        return usdcAmt;
    }

    /**
     *  Withdraw USDC from this wallet to owner's address using 2 signers.
     *
     * @param to            the destination address to send an outgoing transaction
     * @param amount        the amount in Wei to be sent
     * @param expireTime    the number of seconds since 1970 for which this transaction is valid
     */
    function withdraw(
        address to,
        uint256 amount,
        uint256 expireTime
    ) external notDisabled nonReentrant onlyOwner {
        require(expireTime >= block.timestamp, "expired transaction");
        require(balanceOfOwner >= amount, "insufficient balance");

        IERC20(USDC_ADDRESS).safeTransfer(to, amount);
        balanceOfOwner -= amount;
        emit Withdraw(to, amount);
    }

    /**
     *  Withdraw user's USDC from this wallet to user's address using 2 signers.
     *
     * @param receivers     the destination address to send an outgoing transaction
     * @param amounts       the amounts in Wei to be sent
     * @param fees          fees
     * @param expireTime    the number of seconds since 1970 for which this transaction is valid
     * @param allSigners    all signer who sign the tx
     * @param signatures    the signatures of tx
     */
    function withdraws(
        address[] memory receivers,
        uint256[] memory amounts,
        uint256[] memory fees,
        uint256 expireTime,
        string memory orderId,
        address[] memory allSigners,
        bytes[] memory signatures
    ) external notDisabled nonReentrant {
        require(receivers.length == amounts.length, "arrays length mismatch");
        require(receivers.length == fees.length, "arrays length mismatch");
        require(allSigners.length >= 2, "invalid allSigners length");
        require(
            allSigners.length == signatures.length,
            "arrays length mismatch"
        );
        require(allSigners[0] != allSigners[1], "can not be same signer");
        require(expireTime >= block.timestamp, "expired transaction");

        bytes32 operationHash = _hashWithdraws(
            receivers,
            amounts,
            fees,
            expireTime,
            orderId
        );
        operationHash = ECDSAHelper.toEthSignedMessageHash(operationHash);

        for (uint8 index = 0; index < allSigners.length; index++) {
            address signer = ECDSA.recover(operationHash, signatures[index]);
            require(signer == allSigners[index], "invalid signer");
            require(_isAllowedSigner(signer), "not allowed signer");
        }

        for (uint8 index = 0; index < receivers.length; index++) {
            address to = receivers[index];
            uint256 amount = amounts[index];
            uint256 fee = fees[index];
            uint256 total = amount + fee;

            require(to != address(0), "invalid address");
            require(amount > 0, "invalid amount");
            require(fee >= 0, "invalid fee");
            require(balances[to] - outstandingBalances[to] >= total, "insufficient balance");
            IERC20(USDC_ADDRESS).safeTransfer(to, amount);

            balances[to] -= total;
            balanceOfOwner += fee;
        }

        emit Withdraws(orderId, receivers, amounts, fees);
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
        string memory orderId,
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

        bytes32 operationHash = ECDSAHelper.toEthSignedMessageHash(
            _hashSettleAndRefund(accounts, amounts, expireTime, orderId)
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
            // require(balances[account] >= amount, "insufficient balance");

            if (balances[account] >= amount) {
                balances[account] -= amount;
                balanceOfOwner += amount;
            } else {
                balances[account] = 0;
                balanceOfOwner += balances[account];
                uint256 outstandingBalance = amount - balances[account];
                outstandingBalances[account] += outstandingBalance;
            }
        }

        emit Settle(orderId, accounts, amounts);
    }

    /**
     *
     * @param accounts      the accounts to be refunded
     * @param amounts       the amounts to be refunded
     * @param expireTime    the number of seconds since 1970 for which this transaction is valid
     * @param allSigners    all signer who sign the tx
     * @param signatures    the signatures of tx
     */
    function refund(
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 expireTime,
        string memory orderId,
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

        bytes32 operationHash = ECDSAHelper.toEthSignedMessageHash(
            _hashSettleAndRefund(accounts, amounts, expireTime, orderId)
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
            require(balanceOfOwner >= amount, "insufficient balance");

            balanceOfOwner -= amount;
            balances[account] += amount;
        }

        emit Refund(orderId, accounts, amounts);
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
        require(
            msg.sender == account || msg.sender == owner(),
            "You don't have access to that."
        );
        return balances[account];
    }

    /**
     * get the whole balance of this contract
     */
    function balance() external view returns (uint256) {
        return IERC20(USDC_ADDRESS).balanceOf(address(this));
    }

    // ============================= internals =============================
    function _isNative(IERC20 token_) internal pure returns (bool) {
        return (token_ == ZERO_ADDRESS || token_ == ETH_ADDRESS);
    }

    function _hashSettleAndRefund(
        address[] memory receivers,
        uint256[] memory amounts,
        uint256 expireTime,
        string memory orderId
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                orderId,
                block.chainid,
                receivers,
                amounts,
                USDC_ADDRESS,
                expireTime,
                address(this)
            )
        );
        return operationHash;
    }

    function _hashWithdraws(
        address[] memory receivers,
        uint256[] memory amounts,
        uint256[] memory fees,
        uint256 expireTime,
        string memory orderId
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                orderId,
                block.chainid,
                receivers,
                amounts,
                fees,
                USDC_ADDRESS,
                expireTime,
                address(this)
            )
        );
        return operationHash;
    }

    /**
     *
     * @param to to
     * @param amount amount
     * @param expireTime expireTime
     *
     */
    function _hashWithdraw(
        address to,
        uint256 amount,
        uint256 expireTime,
        string memory orderId
    ) internal view returns (bytes32) {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                orderId,
                block.chainid,
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
