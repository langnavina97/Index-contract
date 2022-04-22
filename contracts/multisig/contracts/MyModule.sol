// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.6;

import "@gnosis.pm/zodiac/contracts/core/Module.sol";

interface InputData {
    function transfer(address _to, uint256 _value) external;
}

contract MyModule is Module {
    address public token;

    constructor(address _owner, address _token) {
        bytes memory initializeParams = abi.encode(_owner, _token);
        setUp(initializeParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (address _owner, address _token) = abi.decode(
            initializeParams,
            (address, address)
        );

        token = _token;
        setAvatar(_owner);
        setTarget(_owner);
        transferOwnership(_owner);
    }

    function executeTransactionETH(uint256 value)
        public
        returns (bool success)
    {
        success = exec(
            0xe92Abac47DF8E48E5E60d5Ec9e348E9580191C93,
            value,
            new bytes(0),
            Enum.Operation.Call
        );
    }

    function executeTransactionOther(uint256 value, address _token)
        public
        returns (bool success)
    {
        bytes memory inputData = abi.encodeWithSelector(
            InputData.transfer.selector,
            0xe92Abac47DF8E48E5E60d5Ec9e348E9580191C93,
            value
        );

        success = exec(_token, 0, inputData, Enum.Operation.Call);
    }
}
