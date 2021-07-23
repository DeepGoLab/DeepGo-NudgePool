// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/SafeMath.sol";
import "./BaseLogic.sol";

contract VaultLogic is BaseLogic {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function computeVaultReward(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        uint256 vault = getVaultReward(_ipToken, _baseToken);
        uint256 len = _LPS.getLPArrayLength(_ipToken, _baseToken);
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 resVault = vault;

        for (uint256 i = 0; i < len; i++) {
            address lp = _LPS.getLPByIndex(_ipToken, _baseToken, i);
            uint256 reward = _LPS.getLPVaultReward(_ipToken, _baseToken, lp);
            uint256 amount = _LPS.getLPBaseAmount(_ipToken, _baseToken, lp);
            //reuse local varible
            uint256 curVault = vault.mul(amount).div(LPAmount);
            resVault -= curVault;
            curVault = i == len - 1 ? curVault.add(resVault) : curVault;
            reward = reward.add(curVault);
            _LPS.setLPVaultReward(_ipToken, _baseToken, lp, reward);
        }
    }

    function getVaultReward(
        address _ipToken,
        address _baseToken
    )
        internal
        returns (uint256 vault)
    {
        uint256 lastTime = _VTS.getLastUpdateTime(_ipToken, _baseToken);
        uint256 endTime = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken).add(
                          _IPS.getIPDuration(_ipToken, _baseToken));
        uint256 curVault = _VTS.getCurVault(_ipToken, _baseToken);
        
        require(block.timestamp > lastTime && block.timestamp < endTime,
                "Timestamp Incorrect");
        vault = curVault.mul(block.timestamp.sub(lastTime)).div(endTime.sub(lastTime));
        _VTS.setCurVault(_ipToken, _baseToken, curVault.sub(vault));
        _VTS.setLastUpdateTime(_ipToken, _baseToken, block.timestamp);
    }

    function withdrawVault(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount
    )
        external
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address ip = _IPS.getIPAddress(_ipToken, _baseToken);
        uint256 vault = _VTS.getTotalVault(_ipToken, _baseToken);
        uint256 withdrawed = _VTS.getIPWithdrawed(_ipToken, _baseToken);
        uint256 curVault = _VTS.getCurVault(_ipToken, _baseToken);

        vault = vault.mul(80).div(100);
        require(msg.sender == ip, "Not Permit");
        require(vault.sub(withdrawed) >= _baseTokensAmount, "Withdraw too much");

        amount = curVault > _baseTokensAmount ? _baseTokensAmount : curVault;
        IERC20(_baseToken).safeTransfer(ip, amount);
        curVault = curVault.sub(amount);
        _VTS.setCurVault(_ipToken, _baseToken, curVault);
        withdrawed = withdrawed.add(amount);
        _VTS.setIPWithdrawed(_ipToken, _baseToken, withdrawed);
        return amount;
    }
}