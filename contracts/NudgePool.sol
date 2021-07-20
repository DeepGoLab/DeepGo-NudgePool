// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "./lib/BytesUtils.sol";
import "./lib/SafeMath.sol";
import "./storage/NPStorage.sol";
import "./NPProxy.sol";

contract NudgePool is NPStorage, NPProxy, Pausable {
    using BytesUtils for bytes;
    using SafeMath for uint256;

    constructor(
        address _DGTToken,
        address _DGTBeneficiary,
        address _ips,
        address _gps,
        address _lps,
        address _vts
    )
    {
        DGTToken = _DGTToken;
        DGTBeneficiary = _DGTBeneficiary;

        minRatio = uint32(RATIO_FACTOR * 5 / 1000000);
        alpha = 0;
        raiseRatio = uint32(RATIO_FACTOR * 1);

        auctionDuration = 7 days;
        raisingDuration = 3 days;
        minimumDuration = 90 days;

        _IPS = IPStorage(_ips);
        _GPS = GPStorage(_gps);
        _LPS = LPStorage(_lps);
        _VTS = VaultStorage(_vts);
    }

    function initialize(
        address _ipc,
        address _gpdc,
        address _gpwc,
        address _lpc,
        address _vtc,
        address _stc,
        address _lqdc
    )
        external onlyOwner
    {
        require(!initialized, "Already Initialized");
        setUpgrade("0.0.1", _ipc, _gpdc, _gpwc, _lpc, _vtc, _stc, _lqdc);
        executeUpgrade("0.0.1");
        initialized = true;
    }


    function createPool(
        address _ip,
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount,
        uint256 _dgtTokensAmount,
        uint32 _ipImpawnRatio,
        uint32 _ipCloseLine,
        uint32 _chargeRatio,
        uint256 _duration
    )
        external
    {
        (bool status,) = currentVersions.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "createPool(address,address,address,uint256,uint256,uint32,uint32,uint32,uint256)")),
            _ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount,
            _ipImpawnRatio, _ipCloseLine, _chargeRatio, _duration));
        require(status == true, "Create Pool Failed");
    }

    function auctionPool(
        address _ip,
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount,
        uint256 _dgtTokensAmount
    )
        external
    {
        (bool status,) = currentVersions.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "auctionPool(address,address,address,uint256,uint256)")),
            _ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount));
        require(status == true, "Auction Pool Failed");
    }

    function changePoolParam(
        address _ipToken,
        address _baseToken,
        uint32 _ipImpawnRatio,
        uint32 _ipCloseLine,
        uint32 _chargeRatio,
        uint256 _duration
    )
        external
    {
        (bool status,) = currentVersions.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "changePoolParam(address,address,uint32,uint32,uint32,uint256)")),
            _ipToken, _baseToken, _ipImpawnRatio,
            _ipCloseLine, _chargeRatio, _duration));
        require(status == true, "Change Pool Param Failed");
    }

    function IPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.ipc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "IPDepositRunning(address,address,uint256)")),
            _ipToken, _baseToken, _ipTokensAmount));
        require(status == true, "IP Deposit Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function GPDepositRaising(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.gpdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPDepositRaising(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "GP Deposit Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function GPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.gpdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPDepositRunning(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "GP Deposit Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function GPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
        external
    {
        (bool status,) = currentVersions.gpdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPDoDepositRunning(address,address)")), _ipToken, _baseToken));
        require(status == true, "GP Do Deposit Failed");
    }

    function GPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.gpwc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPWithdrawRunning(address,address,uint256)")),
            _ipToken, _baseToken, _baseTokensAmount));
        require(status == true, "GP Withdraw Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function LPDepositRaising(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPDepositRaising(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "LP Deposit Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function LPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPDepositRunning(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "LP Deposit Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function LPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
        external
    {
        (bool status,) = currentVersions.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPDoDepositRunning(address,address)")), _ipToken, _baseToken));
        require(status == true, "LP Do Deposit Failed");
    }

    function LPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _vaultOnly
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPWithdrawRunning(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _vaultOnly));
        require(status == true, "LP Withdraw Failed");
        amount = data.bytesToUint256();
        return amount;
    }

    function checkAuctionEnd(
        address _ipToken,
        address _baseToken
    )
        external
        returns (bool)
    {
        (bool status, bytes memory data) = currentVersions.stc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkAuctionEnd(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkRaisingEnd(
        address _ipToken,
        address _baseToken
    )
        external
        returns (bool)
    {
        (bool status, bytes memory data) = currentVersions.stc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkRaisingEnd(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkRunningEnd(
        address _ipToken,
        address _baseToken
    )
        external
        returns (bool)
    {
        (bool status, bytes memory data) = currentVersions.lqdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkRunningEnd(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkIPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
        returns (bool)
    {
        (bool status, bytes memory data) = currentVersions.lqdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkIPLiquidation(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkGPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
        returns (bool)
    {
        (bool status, bytes memory data) = currentVersions.lqdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkGPLiquidation(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function computeVaultReward(
        address _ipToken,
        address _baseToken
    )
        external
    {
        (bool status,) = currentVersions.vtc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "computeVaultReward(address,address)")), _ipToken, _baseToken));
        require(status == true, "Compute Reward Failed");
    }

    function withdrawVault(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount
    )
        external
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = currentVersions.vtc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "withdrawVault(address,address,uint256)")),
            _ipToken, _baseToken, _baseTokensAmount));
        require(status == true, "Withdraw Vault Failed");
        amount = data.bytesToUint256();
        return amount;
    }
}