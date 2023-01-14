// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Chamber} from "src/Chamber.sol";

contract ChamberFactory {
    address public owner;
    string public name;
    string public symbol;
    address[] public wizards;
    address[] public managers;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address[] memory _wizards,
        address[] memory _managers
    ) {
        owner = _owner;
        name = _name;
        symbol = _symbol;
        wizards = _wizards;
        managers = _managers;
    }

    function getChamberWithCustomTokens(
        address[] memory _constituents,
        uint256[] memory _quantities
    ) public returns (Chamber) {
        Chamber chamber = new Chamber(
        owner,
        name,
        symbol,
        _constituents,
        _quantities,
        wizards,
        managers
      );
        return chamber;
    }
}
