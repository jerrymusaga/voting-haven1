// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IProofOfIdentity.sol";

/**
 * @title VotingPOI
 * @author Jerry Musaga
 * @dev Using the Proof of Identity contract to
 * permission access to a feature. Here, the owner of the contract is the only one that can register voters.
 * Before owner registers voters, he will check if the voter is eligible by checking if the address has
 * Proof of Identity NFT and is not suspended.
 * Registered voters can vote on a feature(different choices) and each voter can only vote once.
 */

contract VotingPOI is AccessControl {
    /**
     * @dev The owner of the contract.
     */
    address private owner;

    /**
     * @dev The Proof of Identity Contract.
     */
    IProofOfIdentity private _proofOfIdentity;

    mapping(address => bool) private registeredVoters;
    mapping(address => bool) private hasVoted;

    /**
     * @dev The enum for the choices that voters can choose from.
     */
    enum VoteOption {
        Option1,
        Option2,
        Option3,
        Option4
    }
    mapping(address => VoteOption) private voterChoices;
    uint256 private option1Votes;
    uint256 private option2Votes;
    uint256 private option3Votes;
    uint256 private option4Votes;

    /**
     * @notice Emits the address that registers.
     * @param voter The address that got registered.
     */
    event VoterRegistered(address voter);

    /**
     * @notice Emits the address that voted and the choice.
     * @param voter The address that voted.
     * @param choice The choice that the voter chose.
     */
    event Voted(address voter, VoteOption choice);

    /**
     * @notice Emits the new Proof of Identity contract address.
     * @param poiAddress The new Proof of Identity contract address.
     */
    event POIAddressUpdated(address indexed poiAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    modifier onlyVoter() {
        require(
            registeredVoters[msg.sender],
            "You are not a registered voter."
        );
        _;
    }

    modifier canVote() {
        require(!hasVoted[msg.sender], "You have already voted.");
        _;
    }

    modifier onlyPermissionedToVote(address account) {
        // ensure the account has a Proof of Identity NFT
        if (!_hasID(account)) revert VotingPOI__NoIdentityNFT();

        // ensure the account is not suspended
        if (_isSuspended(account)) revert VotingPOI__Suspended();

        _;
    }

    constructor(address proofOfIdentity_) {
        owner = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        setPOIAddress(proofOfIdentity_);
    }

    /**
     * @notice Error to throw when the zero address has been supplied and it
     * is not allowed.
     */
    error VotingPOI__ZeroAddress();

    /**
     * @notice Error to throw when an account does not have a Proof of Identity
     * NFT.
     */
    error VotingPOI__NoIdentityNFT();

    /**
     * @notice Error to throw when an account is suspended.
     */
    error VotingPOI__Suspended();

    /**
     * @notice Returns the address of the Proof of Identity contract.
     * @return The Proof of Identity address.
     */
    function poiAddress() external view returns (address) {
        return address(_proofOfIdentity);
    }

    /**
     * @notice Sets the Proof of Identity contract address.
     * @param poi The address for the Proof of Identity contract.
     * @dev May revert with:
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     * May revert with `SimpleStoragePOI__ZeroAddress`.
     * May emit a `POIAddressUpdated` event.
     */
    function setPOIAddress(address poi) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (poi == address(0)) revert VotingPOI__ZeroAddress();

        _proofOfIdentity = IProofOfIdentity(poi);
        emit POIAddressUpdated(poi);
    }

    function registerVoter(address _voter) public onlyOwner {
        registeredVoters[_voter] = true;
        emit VoterRegistered(_voter);
    }

    function vote(
        VoteOption _choice
    ) public onlyVoter canVote onlyPermissionedToVote(msg.sender) {
        voterChoices[msg.sender] = _choice;
        hasVoted[msg.sender] = true;
        if (_choice == VoteOption.Option1) {
            option1Votes++;
        } else if (_choice == VoteOption.Option2) {
            option2Votes++;
        } else if (_choice == VoteOption.Option3) {
            option3Votes++;
        } else {
            option4Votes++;
        }

        emit Voted(msg.sender, _choice);
    }

    function getVoteResult()
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return (option1Votes, option2Votes, option3Votes, option4Votes);
    }

    /**
     * @notice Returns whether an account holds a Proof of Identity NFT.
     * @param account The account to check.
     * @return True if the account holds a Proof of Identity NFT, else false.
     */
    function _hasID(address account) private view returns (bool) {
        return _proofOfIdentity.balanceOf(account) > 0;
    }

    /**
     * @notice Returns whether an account is suspended.
     * @param account The account to check.
     * @return True if the account is suspended, false otherwise.
     */
    function _isSuspended(address account) private view returns (bool) {
        return _proofOfIdentity.isSuspended(account);
    }

    /**
     * @notice Returns if a given account has permission to be registered as voter. Only owner of contract can call this function.
     *
     * @param account The account to check.
     *
     * @return True if the account can be registered, false otherwise.
     *
     * @dev Requires that the account:
     * -    has a Proof of Identity NFT;
     * -    is not suspended;
     */
    function checkVoterEligibility(
        address account
    ) private view onlyOwner returns (bool) {
        if (!_hasID(account)) return false;
        if (_isSuspended(account)) return false;

        return true;
    }
}
