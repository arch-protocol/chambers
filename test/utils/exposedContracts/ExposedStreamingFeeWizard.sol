// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {IChamber} from "../../../src/interfaces/IChamber.sol";
import {StreamingFeeWizard} from "../../../src/StreamingFeeWizard.sol";

contract ExposedStreamingFeeWizard is StreamingFeeWizard {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() StreamingFeeWizard() {}

    /*//////////////////////////////////////////////////////////////
                           EXPOSED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function calculateInflationQuantity(
        uint256 _currentSupply,
        uint256 _lastCollectTimestamp,
        uint256 _streamingFeePercentage
    ) public view returns (uint256 inflationQuantity) {
        return _calculateInflationQuantity(
            _currentSupply, _lastCollectTimestamp, _streamingFeePercentage
        );
    }

    function exposedCollectStreamingFee(
        IChamber _chamber,
        uint256 _lastCollectTimestamp,
        uint256 _streamingFeePercentage
    ) public {
        _collectStreamingFee(_chamber, _lastCollectTimestamp, _streamingFeePercentage);
    }
}
