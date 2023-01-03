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

interface IChamberGod {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ChamberCreated(address indexed _chamber, address _owner, string _name, string _symbol);

    event WizardAdded(address indexed _wizard);

    event WizardRemoved(address indexed _wizard);

    /*//////////////////////////////////////////////////////////////
                            CHAMBER GOD LOGIC
    //////////////////////////////////////////////////////////////*/

    function createChamber(
        address _owner,
        string memory _name,
        string memory _symbol,
        address[] memory _constituents,
        int256[] memory _quantities,
        address[] memory _wizards,
        address[] memory _managers
    ) external returns (address);

    function isWizard(address _wizard) external view returns (bool);

    function isChamber(address _chamber) external view returns (bool);

    function addWizard(address _wizard) external;

    function removeWizard(address _wizard) external;

    function removeChamber(address _chamber) external;

    function addAllowedContract(address target) external;

    function removeAllowedContract(address target) external;

    function isAllowedContract(address _target) external returns (bool);

    function getAllowedContracts() external returns (address[] memory);
}
