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

import {Owned} from "solmate/auth/Owned.sol";
import {ArrayUtils} from "./lib/ArrayUtils.sol";
import {Chamber} from "./Chamber.sol";

contract ChamberGod is Owned {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ChamberCreated(address indexed _chamber, address _owner, string _name, string _symbol);

    event WizardAdded(address indexed _wizard);

    event WizardRemoved(address indexed _wizard);

    event AllowedContractAdded(address indexed _allowedContract);

    event AllowedContractRemoved(address indexed _allowedContract);

    /*//////////////////////////////////////////////////////////////
                              GOD STORAGE
    //////////////////////////////////////////////////////////////*/

    address[] public chambers;

    address[] public wizards;

    address[] public allowedContracts;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Owned(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            CHAMBER GOD LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * Creates a new Chamber and adds it to the list of chambers
     *
     * @param _name             A string with the name
     * @param _symbol           A string with the symbol
     * @param _constituents     An address array containing the constituents
     * @param _quantities       A uint256 array containing the quantities
     * @param _wizards          An address array containing the wizards
     * @param _managers         An address array containing the managers
     *
     * @return address          Address of the new Chamber
     */
    function createChamber(
        string memory _name,
        string memory _symbol,
        address[] memory _constituents,
        uint256[] memory _quantities,
        address[] memory _wizards,
        address[] memory _managers
    ) external returns (address) {
        require(_constituents.length > 0, "Must have constituents");
        require(_quantities.length > 0, "Must have quantities");
        require(_constituents.length == _quantities.length, "Elements lengths not equal");
        require(!_constituents.hasDuplicate(), "Constituents must be unique");

        for (uint256 k = 0; k < _wizards.length; k++) {
            require(isWizard(_wizards[k]), "Wizard not valid");
        }

        for (uint256 j = 0; j < _constituents.length; j++) {
            require(_constituents[j] != address(0), "Constituent must not be null");
            require(_quantities[j] > 0, "Quantity must be greater than 0");
        }

        for (uint256 i = 0; i < _managers.length; i++) {
            require(_managers[i] != address(0), "Manager must not be null");
        }

        Chamber chamber = new Chamber(
          msg.sender,
          _name,
          _symbol,
          _constituents,
          _quantities,
          _wizards,
          _managers
        );

        chambers.push(address(chamber));

        emit ChamberCreated(address(chamber), msg.sender, _name, _symbol);

        return address(chamber);
    }

    /**
     * Returns the Wizards that are approved in the ChamberGod
     *
     * @return address[]      An address array containing the Wizards
     */
    function getWizards() external view returns (address[] memory) {
        return wizards;
    }

    /**
     * Returns the Chambers that have been created using the ChamberGod
     *
     * @return address[]      An address array containing the Chambers
     */
    function getChambers() external view returns (address[] memory) {
        return chambers;
    }

    /**
     * Checks if the address is a Wizard validated in ChamberGod
     *
     * @param _wizard    The address to check
     *
     * @return bool      True if the address is a Wizard validated
     */
    function isWizard(address _wizard) public view returns (bool) {
        return wizards.contains(_wizard);
    }

    /**
     * Checks if the address is a Chamber created by ChamberGod
     *
     * @param _chamber   The address to check
     *
     * @return bool      True if the address is a Chamber created by ChamberGod
     */
    function isChamber(address _chamber) public view returns (bool) {
        return chambers.contains(_chamber);
    }

    /**
     * Allows the owner to add a new Wizard to the ChamberGod
     *
     * @param _wizard    The address of the Wizard to add
     */
    function addWizard(address _wizard) external onlyOwner {
        require(_wizard != address(0), "Must be a valid wizard");
        require(!isWizard(address(_wizard)), "Wizard already in ChamberGod");

        wizards.push(_wizard);

        emit WizardAdded(_wizard);
    }

    /**
     * Allows the owner to remove a Wizard from the ChamberGod
     *
     * @param _wizard    The address of the Wizard to remove
     */
    function removeWizard(address _wizard) external onlyOwner {
        require(isWizard(_wizard), "Wizard not valid");

        wizards.removeStorage(_wizard);

        emit WizardRemoved(_wizard);
    }

    /**
     * Returns the allowed contracts validated in the ChamberGod
     *
     * @return address[]      An address array containing the allowed contracts
     */
    function getAllowedContracts() external view returns (address[] memory) {
        return allowedContracts;
    }

    /**
     * Allows the owner to add a new allowed contract to the ChamberGod
     *
     * @param _target    The address of the allowed contract to add
     */
    function addAllowedContract(address _target) external onlyOwner {
        require(!isAllowedContract(_target), "Contract already allowed");

        allowedContracts.push(_target);

        emit AllowedContractAdded(_target);
    }

    /**
     * Allows the owner to remove an allowed contract from the ChamberGod
     *
     * @param _target    The address of the allowed contract to remove
     */
    function removeAllowedContract(address _target) external onlyOwner {
        require(isAllowedContract(_target), "Contract not allowed");

        allowedContracts.removeStorage(_target);

        emit AllowedContractRemoved(_target);
    }

    /**
     * Checks if the address is an allowed contract validated in ChamberGod
     *
     * @param _target    The address to check
     *
     * @return bool      True if the address is an allowed contract validated
     */
    function isAllowedContract(address _target) public view returns (bool) {
        return allowedContracts.contains(_target);
    }
}