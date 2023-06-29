// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Create2Factory{

    function _deploy(bytes memory _bytecode, bytes32 _salt) internal returns(address _deployedAddress){
        require(_bytecode.length != 0, "Bytecode can't be empty");
        assembly {
            _deployedAddress := create2(
                0,
                add(_bytecode, 32),
                mload(_bytecode),
                _salt
            )
        }
        require(_deployedAddress != address(0), "Deployment failed !!");
    }

    function findDeployedAddress(bytes memory _bytecode, address _sender, bytes32 _salt) external view returns(address _deployedAddress){
        bytes32 newSalt = keccak256(abi.encode(_sender, _salt));
        _deployedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(this),
                            newSalt,
                            keccak256(_bytecode) // init code hash
                        )
                    )
                )
            )
        );
    }

    function deploy(bytes memory _bytecode, address _sender, bytes32 _salt) external returns(address _deployedAddress){
        _deployedAddress = _deploy(
            _bytecode,
            keccak256(abi.encode(_sender, _salt))
        );
    }

    function deployAndInit(bytes memory _bytecode, address _sender, bytes32 _salt, bytes calldata _initcode) external returns(address _deployedAddress){
        _deployedAddress = _deploy(
            _bytecode,
            keccak256(abi.encode(_sender, _salt))
        );
        (bool success,) = _deployedAddress.call(_initcode);
        require(success);
    }

}