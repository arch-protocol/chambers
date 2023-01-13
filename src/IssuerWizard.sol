/**
 *     SPDX-License-Identifier: Apache License 2.0
 *
 *     Copyright 2018 Set Labs Inc.
 *     Copyright 2022 Smash Works Inc.
 *
 *     Licensed under the Apache License, Version 2.0 (the "License");
 *     you may not use this file except in compliance with the License.
 *     You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *     Unless required by applicable law or agreed to in writing, software
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 *
 *     NOTICE
 *
 *     This is a modified code from Set Labs Inc. found at
 *
 *     https://github.com/SetProtocol/set-protocol-contracts
 *
 *     All changes made by Smash Works Inc. are described and documented at
 *
 *     https://docs.arch.finance/chambers
 */
pragma solidity ^0.8.17.0;

import {IChamber} from "./interfaces/IChamber.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {PreciseUnitMath} from "./lib/PreciseUnitMath.sol";

contract IssuerWizard is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event ChamberTokenIssued(address indexed chamber, address indexed recipient, uint256 quantity);

    event ChamberTokenRedeemed(
        address indexed chamber, address indexed recipient, uint256 quantity
    );

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Returns the amount of tokens required
     *
     * @param _chamber  Chamber instance
     * @param _quantity Amount of Chamber tokens to be minted
     */
    function getConstituentsQuantitiesForIssuance(IChamber _chamber, uint256 _quantity)
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _constituents = _chamber.getConstituentsAddresses();
        uint256 _numberOfConstituents = _constituents.length;
        uint256[] memory _requiredConstituentsQuantities = new uint256[](_numberOfConstituents);
        uint256 chamberDecimals = ERC20(address(_chamber)).decimals();

        for (uint256 i = 0; i < _numberOfConstituents; i++) {
            _requiredConstituentsQuantities[i] = _chamber.getConstituentQuantity(_constituents[i])
                .preciseMulCeil(_quantity, chamberDecimals);
        }
        return (_constituents, _requiredConstituentsQuantities);
    }

    /**
     * Deposits the required constituents into the Chamber instance in order to mint the specified
     * tokens amount. It is assumed that the msg.sender previously approved the tokens transfers.
     *
     * @param _chamber  Chamber instance
     * @param _quantity Amount of Chamber tokens to be minted
     */
    function issue(IChamber _chamber, uint256 _quantity) external nonReentrant {
        require(_quantity > 0, "Quantity must be greater than 0");

        (address[] memory _constituents, uint256[] memory _requiredConstituentsQuantities) =
            getConstituentsQuantitiesForIssuance(_chamber, _quantity);

        for (uint256 i = 0; i < _constituents.length; i++) {
            address constituent = _constituents[i];
            IERC20(constituent).safeTransferFrom(
                msg.sender, address(_chamber), _requiredConstituentsQuantities[i]
            );
        }
        _chamber.mint(msg.sender, _quantity);

        emit ChamberTokenIssued(address(_chamber), msg.sender, _quantity);
    }

    /**
     * Burn the specified quantity tokens from the msg.sender, and transfer the underlying constituents
     * to the recipient address.
     *
     * @param _chamber  Chamber instance
     * @param _quantity Amount of Chamber tokens to be burned
     */
    function redeem(IChamber _chamber, uint256 _quantity) external nonReentrant {
        require(_quantity > 0, "Quantity must be greater than 0");
        uint256 currentBalance = IERC20(address(_chamber)).balanceOf(msg.sender);
        require(currentBalance >= _quantity, "Not enough balance to redeem");

        _chamber.burn(msg.sender, _quantity);

        (address[] memory _constituents, uint256[] memory _requiredConstituentsQuantities) =
            getConstituentsQuantitiesForIssuance(_chamber, _quantity);

        for (uint256 i = 0; i < _constituents.length; i++) {
            address constituent = _constituents[i];
            _chamber.withdrawTo(constituent, msg.sender, _requiredConstituentsQuantities[i]);
        }

        emit ChamberTokenRedeemed(address(_chamber), msg.sender, _quantity);
    }
}
