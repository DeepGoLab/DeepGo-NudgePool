// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract LiquidationLogic is BaseLogic {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function checkIPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint32 closeLine = _IPS.getIPCloseLine(_ipToken, _baseToken);
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);

        if (IPAmount.mul(price).div(inUnit).mul(closeLine) <= GPAmount.mul(RATIO_FACTOR)) {
            doIPLiquidation(_ipToken, _baseToken, price);
            return true;
        }

        return false;
    }

    function checkGPLiquidation(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);

        if (IPAmount.mul(price).div(inUnit) <= raiseLP) {
            doGPLiquidation(_ipToken, _baseToken, price);
            return true;
        }

        return false;
    }

    function checkRunningEnd(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        uint256 time = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);
        uint256 duration = _IPS.getIPDuration(_ipToken, _baseToken);

        if (block.timestamp < time.add(duration)) {
            return false;
        }

        runningEnd(_ipToken, _baseToken);
        return true;
    }

    function doIPLiquidation(
        address _ipToken,
        address _baseToken,
        uint256 price
    )
        private
    {
        uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 LPBase = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 swappedIP = 0;
        uint256 belongLP = 0;
        uint256 belongGP = 0;

        IPAmount = IPAmount.add(IPStake);
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        swappedIP = raiseLP.div(price).mul(inUnit);
        swappedIP = swappedIP > IPAmount ? IPAmount : swappedIP;
        if (swappedIP > 0) {
            belongLP = NPSwap.swap(_ipToken, _baseToken, swappedIP);
        }
        belongGP = IPAmount.sub(swappedIP);
        belongLP = belongLP.add(LPBase.sub(raiseLP));
        divideVault(_ipToken, _baseToken);
        repayLP(_ipToken, _baseToken, belongLP);
        repayGP(_ipToken, _baseToken, belongGP, false);
        repayIP(_ipToken, _baseToken, true);

    }

    function doGPLiquidation(
        address _ipToken,
        address _baseToken,
        uint256 price
    )
        private
    {
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 LPBase = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 belongLP = 0;

        if (IPAmount > 0) {
            belongLP= NPSwap.swap(_ipToken, _baseToken, IPAmount);
        }

        belongLP = belongLP.add(LPBase.sub(raiseLP));
        divideVault(_ipToken, _baseToken);
        repayLP(_ipToken, _baseToken, belongLP);
        repayGP(_ipToken, _baseToken, 0, true);
        repayIP(_ipToken, _baseToken, false);
    }

    function runningEnd(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 LPBase = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 swappedBase = 0;
        uint256 belongLP = 0;
        uint256 belongGP = 0;

        if (IPAmount > 0 ) {
            swappedBase = NPSwap.swap(_ipToken, _baseToken, IPAmount);
        }

        belongLP = swappedBase > raiseLP ? raiseLP : swappedBase;
        belongGP = swappedBase.sub(belongLP);
        belongGP = belongGP.sub(chargeGPFee(_ipToken, _baseToken, belongGP));
        belongLP = belongLP.add(LPBase.sub(raiseLP));
        belongLP = belongLP.sub(chargeLPFee(_ipToken, _baseToken));

        divideVault(_ipToken, _baseToken);
        repayLP(_ipToken, _baseToken, belongLP);
        repayGP(_ipToken, _baseToken, belongGP, true);
        repayIP(_ipToken, _baseToken, false);
    }

    function divideVault(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 curVault = _VTS.getCurVault(_ipToken, _baseToken);
        uint256 len = _LPS.getLPArrayLength(_ipToken, _baseToken);
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint resVault = curVault;

        for (uint256 i = 0; i < len; i++) {
            address lp = _LPS.getLPByIndex(_ipToken, _baseToken, i);
            uint256 reward = _LPS.getLPVaultReward(_ipToken, _baseToken, lp);
            uint256 amount = _LPS.getLPBaseAmount(_ipToken, _baseToken, lp);

            uint256 tmpVault = curVault.mul(amount).div(LPAmount);
            resVault -= tmpVault;
            tmpVault = i == len - 1 ? tmpVault.add(resVault) : tmpVault;
            reward = reward.add(tmpVault);
            _LPS.setLPVaultReward(_ipToken, _baseToken, lp, reward);
        }

        // Reset Pool Vault Info
        _VTS.setTotalVault(_ipToken, _baseToken, 0);
        _VTS.setIPWithdrawed(_ipToken, _baseToken, 0);
        _VTS.setCurVault(_ipToken, _baseToken, 0);
        _VTS.setLastUpdateTime(_ipToken, _baseToken, 0);
    }

    function repayLP(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
    {
        uint256 len = _LPS.getLPArrayLength(_ipToken, _baseToken);
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 resAmount = _amount;

        for (uint256 i = len; i > 0; i--) {
            address lp = _LPS.getLPByIndex(_ipToken, _baseToken, i - 1);
            uint256 reward = _LPS.getLPVaultReward(_ipToken, _baseToken, lp);
            uint256 amount = _LPS.getLPBaseAmount(_ipToken, _baseToken, lp);

            uint256 curAmount = _amount.mul(amount).div(LPAmount);
            resAmount -= curAmount;
            curAmount = i == 1 ? curAmount.add(resAmount) : curAmount;
            uint256 belongLP = reward.add(curAmount);
            IERC20(_baseToken).safeTransfer(lp, belongLP);
            _LPS.deleteLP(_ipToken, _baseToken, lp);
        }

        // Reset Pool LP Info
        _LPS.setCurLPAmount(_ipToken, _baseToken, 0);
    }

    function repayGP(
        address _ipToken,
        address _baseToken,
        uint256 _amount,
        bool _base
    )
        private
    {
        uint256 len = _GPS.getGPArrayLength(_ipToken, _baseToken);
        uint256 GPBalance = _GPS.getCurGPBalance(_ipToken, _baseToken);
        uint256 resAmount = _amount;

        for (uint256 i = len; i > 0; i--) {
            address gp = _GPS.getGPByIndex(_ipToken, _baseToken, i - 1);

            if (_amount > 0) {
                uint256 balance = _GPS.getGPBaseBalance(_ipToken, _baseToken, gp);
                uint256 belongGP = _amount.mul(balance).div(GPBalance);
                resAmount -= belongGP;
                belongGP = i == 1? belongGP.add(resAmount) : belongGP;

                if (_base) {
                    IERC20(_baseToken).safeTransfer(gp, belongGP);
                } else {
                    IERC20(_ipToken).safeTransfer(gp, belongGP);
                }
            }
            
            _GPS.deleteGP(_ipToken, _baseToken, gp);
        }

        // Reset Pool GP Info
        _GPS.setCurGPAmount(_ipToken, _baseToken, 0);
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, 0);
        _GPS.setCurIPAmount(_ipToken, _baseToken, 0);
        _GPS.setCurGPBalance(_ipToken, _baseToken, 0);
    }

    function repayIP(
        address _ipToken,
        address _baseToken,
        bool ipLiquidation
    )
        private
    {
        if (!ipLiquidation) {
            uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
            address ip = _IPS.getIPAddress(_ipToken, _baseToken);
            IERC20(_ipToken).safeTransfer(ip, IPStake);
        }
    
        // Reset Pool Info
        poolResetState(_ipToken, _baseToken);
    }

    function poolResetState(
        address _ipToken,
        address _baseToken
    )
        private
    {
        _IPS.setPoolStage(_ipToken, _baseToken, uint8(Stages.FINISHED));
        _IPS.deletePool(_ipToken, _baseToken);
    }

    function chargeGPFee(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 fee)
    {
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);
        uint256 earnedGP = _amount > GPAmount ? _amount.sub(GPAmount) : 0;

        if (earnedGP > 0) {
            fee = earnedGP.mul(20).div(100);
            IERC20(_baseToken).safeTransfer(DGTBeneficiary, fee);
            return fee;
        }

        return 0;
    }

    function chargeLPFee(
        address _ipToken,
        address _baseToken
    )
        private
        returns (uint256 fee)
    {
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        fee = LPAmount.mul(1).div(100);
        IERC20(_baseToken).safeTransfer(DGTBeneficiary, fee);
        return fee;
    }
}