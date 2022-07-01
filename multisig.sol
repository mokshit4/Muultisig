// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract MultiOwner{

    using SafeMath for uint;

    uint public numOfOwners;
    uint public required;
    uint private TransactionId;
    mapping(address => bool) public owners;
    struct Transaction{
        address to;
        uint value;
        uint confirmations;
        uint TransactionId;
        uint timesStamp;
        bytes callData;
        string subject;
    }
    Transaction[] public Transactions;
    mapping(uint => mapping(address => bool)) public confirmations; //transacationId => ownerAddress => confirmed?
    mapping(uint => bool) public transactionStatus;//executed => true; pending => false
    bytes32 CONFIRM_TypeHash = keccak256("Transaction(address to,uint value,bytes callData,string subject)");
    bytes32 DOMAIN_SEPERATOR;
    modifier onlyOwners() {
        require(owners[msg.sender] == true, "not a registered owner");
        _;
    }

    constructor(address[] memory _owners, uint _required){
        for(uint i=0; i < _owners.length; i++){
            require(!owners[_owners[i]] && _owners[i] != address(0));
            owners[_owners[i]] = true;
        }
        required = _required;
        numOfOwners = _owners.length;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPERATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("MultiSigWallet")),
            keccak256(bytes("v0")),
            chainId,
            address(this)
        ));
    }

    function transactionHash(uint _transactionId) public view returns(bytes32 TransactionHash) {
        Transaction memory transaction = Transactions[_transactionId];
        TransactionHash = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPERATOR,
            keccak256(abi.encode(CONFIRM_TypeHash, transaction.to, transaction.value, keccak256(transaction.callData), keccak256(bytes(transaction.subject))))
        ));
    }

    function _addOwner(address _owner) private {
        //check

        owners[_owner] = true;
        numOfOwners = numOfOwners.add(1);
    }

    function _removeOwner(address _owner) private {
        //check

        owners[_owner] = false;
        numOfOwners = numOfOwners.sub(1);
    }

    function _replaceOwner(address _oldOwner, address _newOwner) private {
        //check

        owners[_oldOwner] = false;
        owners[_newOwner] = true;
    }

    function _updateRequired(uint _required) private {
        //check
        required = _required;
    }

    // prospose a transaction
    function proposeTransaction(address _to, uint _value, string memory _subject, bytes memory _data) public onlyOwners{
        Transactions.push(Transaction(_to, _value, 0, TransactionId, block.timestamp, _data, _subject));
        TransactionId = TransactionId.add(1);
    }

    //confirm a transaction
    function _confirmTransaction(uint _transactionId, address _signer) private {
        require((!confirmations[_transactionId][_signer]) && owners[_signer]);
        confirmations[_transactionId][_signer] = true;
        Transactions[_transactionId].confirmations = Transactions[_transactionId].confirmations.add(1);
    }

    //execute a transaction
    function executeTransaction(uint _transactionId, bytes memory signatures) public onlyOwners{
        require(!transactionStatus[_transactionId]);
        require(signatures.length >= required.mul(65), "number of confirmations less");
        require(checkSignatures(_transactionId, signatures));
        transactionStatus[_transactionId] = true;//reentrancy protected
        Transaction memory transaction = Transactions[_transactionId];
        address payable _to = payable(transaction.to);
        uint _value = transaction.value;
        //add delay time check
        (bool success, ) = address(_to).call{value: _value}(transaction.callData);
        if(!success) revert();
    }
    //ECDSA
    function checkSignatures(uint _transactionId, bytes memory signatures) public returns(bool){

        for(uint i = 0; i < required; i++){
            address signer = getSigner(_transactionId, signatures, i);
            _confirmTransaction(_transactionId, signer);
        }
        if(Transactions[_transactionId].confirmations >= required) return true;
        return false;
    }
    function getSigner(uint _transactionId, bytes memory signatures, uint i) internal view returns(address signer) {
            uint8 v;
            bytes32 r;
            bytes32 s;
            assembly {
                let pos := mul(0x41 , i)
                r := mload(add(signatures, add(pos, 0x20)))
                s := mload(add(signatures, add(pos, 0x40)))
                v := and(mload(add(signatures, add(pos, 0x41))), 0xff)
            }
        signer =  ecrecover(transactionHash(_transactionId), v, r, s);

    }
    function deposit() public payable onlyOwners {
    }
}
