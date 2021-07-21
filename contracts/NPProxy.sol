// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/SafeMath.sol";

contract NPProxy is Ownable {
    using SafeMath for uint256;

    struct LogicContracts {
        bool valid;
        address ipc;
        address gpdc;
        address gpwc;
        address lpc;
        address vtc;
        address stc;
        address lqdc;
    }

    mapping(string => LogicContracts) internal versions;
    LogicContracts public curVersion;
    LogicContracts public delayVersion;
    string[] public versionList;
    string public versionName;
    string public delayVersionName;
    uint256 constant delayTime = 5 minutes;
    uint256 public startTime;
    bool public initialized;

    function setUpgrade(
        string memory _newVersion,
        address _ipc,
        address _gpdc,
        address _gpwc,
        address _lpc,
        address _vtc,
        address _stc,
        address _lqdc
    )
        public onlyOwner
    {
        require(_ipc != address(0) && _gpdc != address(0) && _gpwc != address(0) &&
                _lpc != address(0) && _vtc != address(0) && _stc != address(0) &&
                _lqdc != address(0), "Wrong Address");
        require(bytes(_newVersion).length > 0, "Empty Version");
        delayVersionName = _newVersion;
        delayVersion.ipc = _ipc;
        delayVersion.gpdc = _gpdc;
        delayVersion.gpwc = _gpwc;
        delayVersion.lpc = _lpc;
        delayVersion.vtc = _vtc;
        delayVersion.stc = _stc;
        delayVersion.lqdc = _lqdc;
        delayVersion.valid = true;
        startTime = block.timestamp;
    }

    function executeUpgrade(
        string memory _newVersion
    )
        public onlyOwner
    {
        require(delayVersion.valid == true, "Upgrade Invalid");
        if (initialized == true) {
            require(block.timestamp > startTime.add(delayTime), "In Delay" );
        }
        require(keccak256(abi.encodePacked(_newVersion)) == keccak256(abi.encodePacked(delayVersionName)), "Version Incorrect");
        versions[delayVersionName] = delayVersion;
        versionName = delayVersionName;
        curVersion = delayVersion;
        versionList.push(_newVersion);
        delayVersionName = '';
        delete delayVersion;
    }

    function rollback(
    )
        public onlyOwner
    {
        delayVersionName = '';
        delete delayVersion;
    }

    function getLogicContracts(
        string calldata _version
    ) 
        external view onlyOwner
        returns(address, address, address, address, address, address, address)
    {
        require(bytes(_version).length > 0, "Empty Version");
        return (versions[_version].ipc, versions[_version].gpdc,
                versions[_version].gpwc, versions[_version].lpc,
                versions[_version].vtc, versions[_version].stc,
                versions[_version].lqdc);
    }
}