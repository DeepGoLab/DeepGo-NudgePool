// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NPProxy is Ownable {
    struct LogicContracts {
        address ipc;
        address gpdc;
        address gpwc;
        address lpc;
        address vtc;
        address stc;
        address lqdc;
    }

    mapping(string => LogicContracts) internal versions;
    LogicContracts public currentVersions;
    LogicContracts public delayVersions;
    string[] public versionList;
    string public version;
    uint256 constant delayTime = 30 seconds;
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
        version = _newVersion;
        delayVersions.ipc = _ipc;
        delayVersions.gpdc = _gpdc;
        delayVersions.gpwc = _gpwc;
        delayVersions.lpc = _lpc;
        delayVersions.vtc = _vtc;
        delayVersions.stc = _stc;
        delayVersions.lqdc = _lqdc;
        startTime = block.timestamp;
    }

    function executeUpgrade(
        string memory _newVersion
    )
        public onlyOwner
    {
        if(initialized == true){
            require(block.timestamp > startTime + delayTime, "Operation In Delay" );
        }
        require(delayVersions.ipc != address(0) && delayVersions.gpdc != address(0) && delayVersions.gpwc != address(0) &&
        delayVersions.lpc != address(0) && delayVersions.vtc != address(0) && delayVersions.stc != address(0) &&
        delayVersions.lqdc != address(0), "Wrong Address");
        require(keccak256(abi.encodePacked(_newVersion)) == keccak256(abi.encodePacked(version)), "Version Not Match");
        versions[version] = delayVersions;
        currentVersions = delayVersions;
        versionList.push(_newVersion);
        delete delayVersions;
    }

    function rollback(
    )
        public onlyOwner
    {
        delete delayVersions;
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