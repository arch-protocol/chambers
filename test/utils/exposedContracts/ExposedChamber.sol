// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Chamber} from "../../../src/Chamber.sol";

contract ExposedChamber is Chamber {
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address[] memory _constituents,
        uint256[] memory _quantities,
        address[] memory _wizards,
        address[] memory _managers
    ) Chamber(_owner, _name, _symbol, _constituents, _quantities, _wizards, _managers) {}

    function invokeContract(bytes memory _data, address payable _target)
        public
        returns (bytes memory response)
    {
        return (_invokeContract(_data, _target));
    }
}
