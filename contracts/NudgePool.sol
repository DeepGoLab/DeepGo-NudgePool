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

    event CreatePool(address _ip, address _ipToken, address _baseToken, uint256 _ipTokensAmount, uint256 _dgtTokensAmount,
                        uint32 _ipImpawnRatio, uint32 _ipCloseLine,uint32 _chargeRatio, uint256 _duration);
    event AuctionPool(address _ip, address _ipToken, address _baseToken, uint256 _ipTokensAmount, uint256 _dgtTokensAmount);
    event DestroyPool(address _ipToken, address _baseToken);
    event ChangePoolParam(address _ipToken, address _baseToken, uint32 _ipImpawnRatio, uint32 _ipCloseLine,
                   uint32 _chargeRatio, uint256 _duration);
    event RunningIPDeposit(address _ipToken, address _baseToken, uint256 _ipTokensAmount);
    event RaisingGPDeposit(address _ipToken, address _baseToken, uint256 _baseTokensAmount);
    event RunningGPDeposit(address _ipToken, address _baseToken, uint256 _baseTokensAmount);
    event RunningGPDoDeposit(address _ipToken, address _baseToken);
    event RunningGPWithdraw(address _ipToken, address _baseToken, uint256 _baseTokensAmount);
    event LiquidationGPWithdraw(address _ipToken, address _baseToken);
    event RaisingLPDeposit(address _ipToken, address _baseToken, uint256 _baseTokensAmount);
    event RunningLPDeposit(address _ipToken, address _baseToken, uint256 _baseTokensAmount);
    event RunningLPDoDeposit(address _ipToken, address _baseToken);
    event RunningLPWithdraw(address _ipToken, address _baseToken, uint256 _baseTokensAmount);
    event LiquidationLPWithdraw(address _ipToken, address _baseToken);
    event WithdrawVault(address _ipToken, address _baseToken, uint256 _baseTokensAmount);

    constructor(
        address _DGTToken,
        address _DGTBeneficiary,
        address _ips,
        address _gps,
        address _lps,
        address _vts
    )
    {
        require(_DGTToken != address(0) && _DGTBeneficiary != address(0) &&
                _ips != address(0) && _gps != address(0) &&
                _lps != address(0) && _vts != address(0), "Invalid Address");

        DGTToken = _DGTToken;
        DGTBeneficiary = _DGTBeneficiary;
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
        executeUpgrade();
        initialized = true;
    }

    function setPause(
    )
        external onlyOwner
    {
        _pause();
        emit Paused(msg.sender);
    }

    function unPause(
    )
        external onlyOwner
    {
        _unpause();
        emit Unpaused(msg.sender);
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
        external whenNotPaused
    {
        (bool status,) = curVersion.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "createPool(address,address,address,uint256,uint256,uint32,uint32,uint32,uint256)")),
            _ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount,
            _ipImpawnRatio, _ipCloseLine, _chargeRatio, _duration));
        require(status == true, "Create Pool Failed");
        emit CreatePool(_ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount,
                        _ipImpawnRatio, _ipCloseLine, _chargeRatio, _duration);
    }

    function auctionPool(
        address _ip,
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount,
        uint256 _dgtTokensAmount
    )
        external whenNotPaused
    {
        (bool status,) = curVersion.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "auctionPool(address,address,address,uint256,uint256)")),
            _ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount));
        require(status == true, "Auction Pool Failed");
        emit AuctionPool(_ip, _ipToken, _baseToken, _ipTokensAmount, _dgtTokensAmount);
    }

    function destroyPool(
        address _ipToken,
        address _baseToken
    )
        external onlyOwner
    {
        (bool status,) = curVersion.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "destroyPool(address,address)")), _ipToken, _baseToken));
        require(status == true, "Destroy Pool Failed");
        emit DestroyPool(_ipToken, _baseToken);
    }

    function changePoolParam(
        address _ipToken,
        address _baseToken,
        uint32 _ipImpawnRatio,
        uint32 _ipCloseLine,
        uint32 _chargeRatio,
        uint256 _duration
    )
        external whenNotPaused
    {
        (bool status,) = curVersion.ipc.delegatecall(abi.encodeWithSelector(bytes4(keccak256(
            "changePoolParam(address,address,uint32,uint32,uint32,uint256)")),
            _ipToken, _baseToken, _ipImpawnRatio,
            _ipCloseLine, _chargeRatio, _duration));
        require(status == true, "Change Pool Param Failed");
        emit ChangePoolParam(_ipToken, _baseToken, _ipImpawnRatio, _ipCloseLine,
                            _chargeRatio, _duration);
    }

    function IPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _ipTokensAmount
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.ipc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "IPDepositRunning(address,address,uint256)")),
            _ipToken, _baseToken, _ipTokensAmount));
        require(status == true, "IP Deposit Failed");
        amount = data.bytesToUint256();
        emit RunningIPDeposit(_ipToken, _baseToken, _ipTokensAmount);
        return amount;
    }

    function GPDepositRaising(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.gpdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPDepositRaising(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "GP Deposit Failed");
        amount = data.bytesToUint256();
        emit RaisingGPDeposit(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }

    function GPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.gpdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPDepositRunning(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "GP Deposit Failed");
        amount = data.bytesToUint256();
        emit RunningGPDeposit(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }

    function GPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
    {
        (bool status,) = curVersion.gpdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPDoDepositRunning(address,address)")), _ipToken, _baseToken));
        require(status == true, "GP Do Deposit Failed");
        emit RunningGPDoDeposit(_ipToken, _baseToken);
    }

    function GPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.gpwc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPWithdrawRunning(address,address,uint256)")),
            _ipToken, _baseToken, _baseTokensAmount));
        require(status == true, "GP Withdraw Failed");
        amount = data.bytesToUint256();
        emit RunningGPWithdraw(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }

    function GPWithdrawLiquidation(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
    {
        (bool status, bytes memory data) = curVersion.gpwc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "GPWithdrawLiquidation(address,address)")),
            _ipToken, _baseToken));
        require(status == true, "GP Withdraw Failed");
        emit LiquidationGPWithdraw(_ipToken, _baseToken);
    }

    function LPDepositRaising(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPDepositRaising(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "LP Deposit Failed");
        amount = data.bytesToUint256();
        emit RaisingLPDeposit(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }

    function LPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPDepositRunning(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _create));
        require(status == true, "LP Deposit Failed");
        amount = data.bytesToUint256();
        emit RunningLPDeposit(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }

    function LPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
    {
        (bool status,) = curVersion.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPDoDepositRunning(address,address)")), _ipToken, _baseToken));
        require(status == true, "LP Do Deposit Failed");
        emit RunningLPDoDeposit(_ipToken, _baseToken);
    }

    function LPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _vaultOnly
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPWithdrawRunning(address,address,uint256,bool)")),
            _ipToken, _baseToken, _baseTokensAmount, _vaultOnly));
        require(status == true, "LP Withdraw Failed");
        amount = data.bytesToUint256();
        emit RunningLPWithdraw(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }

    function LPWithdrawLiquidation(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
    {
        (bool status, bytes memory data) = curVersion.lpc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "LPWithdrawLiquidation(address,address)")),
            _ipToken, _baseToken));
        require(status == true, "LP Withdraw Failed");
        emit LiquidationLPWithdraw(_ipToken, _baseToken);
    }

    function checkAuctionEnd(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
        returns (bool)
    {
        (bool status, bytes memory data) = curVersion.stc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkAuctionEnd(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkRaisingEnd(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
        returns (bool)
    {
        (bool status, bytes memory data) = curVersion.stc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkRaisingEnd(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkRunningEnd(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
        returns (bool)
    {
        (bool status, bytes memory data) = curVersion.lqdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkRunningEnd(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkIPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
        returns (bool)
    {
        (bool status, bytes memory data) = curVersion.lqdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkIPLiquidation(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function checkGPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
        returns (bool)
    {
        (bool status, bytes memory data) = curVersion.lqdc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "checkGPLiquidation(address,address)")), _ipToken, _baseToken));
        require(status == true, "Check Failed");
        return data.bytesToBool();
    }

    function repayGPOverRaise(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
    {
        (bool status, ) = curVersion.gpdc.deledatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "repayGPOverRaise(address,address)")), _ipToken, _baseToken));
        require(status == true, "Repay Failed");
    }

    function computeVaultReward(
        address _ipToken,
        address _baseToken
    )
        external whenNotPaused
    {
        (bool status,) = curVersion.vtc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "computeVaultReward(address,address)")), _ipToken, _baseToken));
        require(status == true, "Compute Reward Failed");
    }

    function withdrawVault(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount
    )
        external whenNotPaused
        returns (uint256 amount)
    {
        (bool status, bytes memory data) = curVersion.vtc.delegatecall(
            abi.encodeWithSelector(bytes4(keccak256(
            "withdrawVault(address,address,uint256)")),
            _ipToken, _baseToken, _baseTokensAmount));
        require(status == true, "Withdraw Vault Failed");
        amount = data.bytesToUint256();
        emit WithdrawVault(_ipToken, _baseToken, _baseTokensAmount);
        return amount;
    }
}