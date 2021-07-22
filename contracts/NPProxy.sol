// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/SafeMath.sol";

contract NPProxy is Ownable {
    using SafeMath for uint256;

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
    LogicContracts public curVersion;
    LogicContracts public delayVersion;
    string[] public versionList;
    string public versionName;
    string public delayVersionName;
    uint256 constant delayTime = 5 minutes;
    uint256 public startTime;
    bool public initialized;

    event SetUpgrade(string version, address IPlogic, address GPDepositLogic, address GPWithdrawLogic,
                    address LPLogic, address VaultLogic, address StateLogic, address LiquidationLogic);
    event ExecuteUpgrade(string version, address IPlogic, address GPDepositLogic, address GPWithdrawLogic,
                    address LPLogic, address VaultLogic, address StateLogic, address LiquidationLogic);
    event Rollback();

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
        startTime = block.timestamp;
        emit SetUpgrade(_newVersion, _ipc, _gpdc, _gpwc, _lpc, _vtc, _stc, _lqdc);
    }

    function executeUpgrade(
    )
        public onlyOwner
    {
        require(delayVersion.ipc != address(0) && delayVersion.gpdc != address(0) && delayVersion.gpwc != address(0) &&
                delayVersion.lpc != address(0) && delayVersion.vtc != address(0) && delayVersion.stc != address(0) &&
                delayVersion.lqdc != address(0), "Wrong Address");
        if (initialized == true) {
            require(block.timestamp > startTime.add(delayTime), "In Delay" );
        }
        versions[delayVersionName] = delayVersion;
        versionName = delayVersionName;
        curVersion = delayVersion;
        versionList.push(delayVersionName);
        delayVersionName = '';
        delete delayVersion;
        emit ExecuteUpgrade(versionName, curVersion.ipc, curVersion.gpdc, curVersion.gpwc, curVersion.lpc,
                            curVersion.vtc, curVersion.stc, curVersion.lqdc);
    }

    function rollback(
    )
        public onlyOwner
    {
        delayVersionName = '';
        delete delayVersion;
        emit Rollback();
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