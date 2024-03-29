// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.6;

import "@gnosis.pm/zodiac/contracts/core/Module.sol";

interface InputData {
    function transfer(address _to, uint256 _value) external;
}

contract MyModule is Module {
    address public moduleOwner;

    constructor(address _owner) {
        bytes memory initializeParams = abi.encode(_owner);
        setUp(initializeParams);
        moduleOwner = msg.sender;
    }

    modifier onlyModuleOwner() {
        require(moduleOwner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferModuleOwnership(address newOwner) public onlyModuleOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        moduleOwner = newOwner;
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        address _owner = abi.decode(initializeParams, (address));

        setAvatar(_owner);
        setTarget(_owner);
        transferOwnership(_owner);
    }

    function executeTransactionETH(address _to, uint256 value)
        public
        onlyModuleOwner
        returns (bool success)
    {
        success = exec(_to, value, new bytes(0), Enum.Operation.Call);
    }

    function executeTransactionOther(
        address _to,
        uint256 value,
        address _token
    ) public onlyModuleOwner returns (bool success) {
        bytes memory inputData = abi.encodeWithSelector(
            InputData.transfer.selector,
            _to,
            value
        );

        success = exec(_token, 0, inputData, Enum.Operation.Call);
    }
}
