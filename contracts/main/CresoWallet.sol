// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../core/BaseAccount.sol";
import "./callback/TokenCallbackHandler.sol";

contract CresoWallet is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable
{
    using ECDSA for bytes32;

    address public owner;

    address[] public guardians; // Trusted addresses for recovery
    mapping(address => bool) public isGuardian;
    uint256 public requiredConfirmations; // Number of confirmations required for recovery
    address public proposedNewOwner; // New owner proposed during recovery
    mapping(address => bool) public recoveryConfirmation; // Guardians' confirmations
    uint256 public recoveryInitiatedTime;
    uint256 public recoveryTimeLock = 24 hours; // Time lock for security
    bool public recoveryActive;

    IEntryPoint private immutable _entryPoint;

    event CresoWalletInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );

    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event RecoveryStarted(address indexed proposedOwner);
    event RecoveryConfirmed(
        address indexed guardian,
        address indexed proposedOwner
    );
    event RecoveryCancelled(address indexed owner);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            msg.sender == owner || msg.sender == address(this),
            "only owner"
        );
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        require(
            dest.length == func.length &&
                (value.length == 0 || value.length == func.length),
            "wrong array lengths"
        );
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of CresoWallet must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit CresoWalletInitialized(_entryPoint, owner);
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner,
            "account: not Owner or EntryPoint"
        );
    }

    /// implement template method of BaseAccount
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }

    // Add a new guardian
    function addGuardian(address _guardian) public onlyOwner {
        require(!isGuardian[_guardian], "Guardian already exists");
        guardians.push(_guardian);
        isGuardian[_guardian] = true;
        emit GuardianAdded(_guardian);
    }

    // Remove an existing guardian
    function removeGuardian(address _guardian) public onlyOwner {
        require(isGuardian[_guardian], "Not a guardian");
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == _guardian) {
                guardians[i] = guardians[guardians.length - 1];
                guardians.pop();
                break;
            }
        }
        isGuardian[_guardian] = false;
        emit GuardianRemoved(_guardian);
    }

    // Initiate the recovery process
    function startRecovery(address _proposedNewOwner) public {
        require(isGuardian[msg.sender], "Not a guardian");
        require(!recoveryActive, "Recovery already active");
        proposedNewOwner = _proposedNewOwner;
        recoveryInitiatedTime = block.timestamp;
        recoveryActive = true;
        for (uint256 i = 0; i < guardians.length; i++) {
            recoveryConfirmation[guardians[i]] = false;
        }
        recoveryConfirmation[msg.sender] = true;
        requiredConfirmations = guardians.length / 2 + 1; //majority is required
        emit RecoveryStarted(_proposedNewOwner);
    }

    // Confirm the recovery by a guardian
    function confirmRecovery() public {
        require(isGuardian[msg.sender], "Not a guardian");
        require(recoveryActive, "No recovery in process");
        require(
            block.timestamp >= recoveryInitiatedTime + recoveryTimeLock,
            "Recovery time lock not passed"
        );
        recoveryConfirmation[msg.sender] = true;

        uint256 confirmations = 0;
        for (uint256 i = 0; i < guardians.length; i++) {
            if (recoveryConfirmation[guardians[i]]) confirmations++;
        }

        if (confirmations >= requiredConfirmations) {
            emit OwnerChanged(owner, proposedNewOwner);
            owner = proposedNewOwner;
            proposedNewOwner = address(0);
            recoveryActive = false;
        }
    }

    // Allow the owner to cancel an active recovery
    function cancelRecovery() public onlyOwner {
        require(recoveryActive, "No recovery to cancel");
        recoveryActive = false;
        proposedNewOwner = address(0);
        emit RecoveryCancelled(owner);
    }

}
