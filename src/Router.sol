// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Create2Factory.sol";

interface IMailBox{
    function dispatch(
        uint32 _destination,
        bytes32 _recipient,
        bytes calldata _body
    ) external returns (bytes32);
}

interface IInterchainGasPaymaster {
    event GasPayment(
        bytes32 indexed messageId,
        uint256 gasAmount,
        uint256 payment
    );

    function payForGas(
        bytes32 _messageId,
        uint32 _destinationDomain,
        uint256 _gasAmount,
        address _refundAddress
    ) external payable;

    function quoteGasPayment(uint32 _destinationDomain, uint256 _gasAmount)
        external
        view
        returns (uint256);
}

contract Router{
    
    address public mailbox;
    address public interchainGasPaymaster;
    Create2Factory contractFactory;
    mapping (uint32 => address) public remoteRouter;

    constructor(address _mailbox, address _interchainGasPaymaster){
        mailbox = _mailbox;
        interchainGasPaymaster = _interchainGasPaymaster;
        contractFactory = new Create2Factory();
    } 
    
    function deployContract(bytes calldata _bytecode, bytes32 _salt, uint8[] calldata _domainIds) payable external returns(address _deployedAddress){
        for(uint i=0; i<_domainIds.length; i++){
            _deployContract(_domainIds[i], _bytecode, _salt);
        }
        _deployedAddress = contractFactory.findDeployedAddress(_bytecode, msg.sender, _salt);
    }

    function deployContractAndInit(bytes calldata _bytecode, bytes32 _salt, bytes calldata _initcode, uint8[] calldata _domainIds) payable external returns(address _deployedAddress){
        for(uint i=0; i<_domainIds.length; i++){
            _deployContractAndInit(_domainIds[i], _bytecode, _salt, _initcode);
        }
        _deployedAddress = contractFactory.findDeployedAddress(_bytecode, msg.sender, _salt);
    }

    function _deployContract(uint32 _domainId, bytes memory _bytecode, bytes32 _salt) internal{
        require(remoteRouter[_domainId] != address(0), "Mailbox of given domain id is unknown");
        bytes32 messageId = IMailBox(mailbox).dispatch(
            _domainId,
            addressToBytes32(remoteRouter[_domainId]),
            abi.encode(1, abi.encode(_bytecode, msg.sender, _salt))
        );
        uint256 quote = IInterchainGasPaymaster(interchainGasPaymaster).quoteGasPayment(_domainId, 200000);
        IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: quote}(
            messageId,
            _domainId,
            200000,
            tx.origin
        );
    }

    function _deployContractAndInit(uint32 _domainId, bytes memory _bytecode, bytes32 _salt, bytes calldata _initcode) internal{
        require(remoteRouter[_domainId] != address(0), "Mailbox of given domain id is unknown");
        bytes32 messageId = IMailBox(mailbox).dispatch(
            _domainId,
            addressToBytes32(remoteRouter[_domainId]),
            abi.encode(2, abi.encode(_bytecode, msg.sender, _salt, _initcode))
        );
        uint256 quote = IInterchainGasPaymaster(interchainGasPaymaster).quoteGasPayment(_domainId, 200000);
        IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: quote}(
            messageId,
            _domainId,
            200000,
            tx.origin
        );
    }

    function handle(uint32 _origin, bytes32 _sender, bytes memory _body) external{
        (uint256 choice, bytes memory data) = abi.decode(_body, (uint256, bytes));
        if(choice == 1){
            (bytes memory bytecode, address sender, bytes32 salt) = abi.decode(data, (bytes,address,bytes32));
            contractFactory.deploy(bytecode, sender, salt);
        }else if(choice == 2){
            (bytes memory bytecode, address sender, bytes32 salt, bytes memory initcode) = abi.decode(data, (bytes,address,bytes32,bytes));
            contractFactory.deployAndInit(bytecode, sender, salt, initcode);
        }
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

}
