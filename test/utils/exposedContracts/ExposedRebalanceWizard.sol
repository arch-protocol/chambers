// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {RebalanceWizard} from "src/RebalanceWizard.sol";

contract ExposedRebalanceWizard is RebalanceWizard {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() RebalanceWizard() {}

    /*//////////////////////////////////////////////////////////////
                           EXPOSED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function trade(RebalanceParams calldata params) external {
        _trade(params);
    }
}
