// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract GPDepositLogic is BaseLogic {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function GPDepositRaising(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RAISING);
        address _gp = msg.sender;
        uint256 oriGPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);

        amount = _baseTokensAmount;
        IERC20(_baseToken).safeTransferFrom(_gp, address(this), amount);
        _GPS.setCurGPAmount(_ipToken, _baseToken, oriGPAmount.add(amount));
        _GPS.setCurGPBalance(_ipToken, _baseToken, oriGPAmount.add(amount));
        if (_create) {
            _GPS.insertGP(_ipToken, _baseToken, _gp, amount, false);
            _GPS.setGPBaseBalance(_ipToken, _baseToken, _gp, amount);
        } else {
            uint256 oriAmount = _GPS.getGPBaseAmount(_ipToken, _baseToken, _gp);
            _GPS.setGPBaseAmount(_ipToken, _baseToken, _gp, oriAmount.add(amount));
            _GPS.setGPBaseBalance(_ipToken, _baseToken, _gp, oriAmount.add(amount));
        }

        require(amount > 0, "Deposit Zero");
        return amount;
    }

    function GPDepositRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _create
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _gp = msg.sender;
        uint256 maxAmount = updateMaxIPCanRaise(_ipToken, _baseToken);
        uint256 curAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);

        require(maxAmount > curAmount, "No Space Left");
        amount = maxAmount - curAmount > _baseTokensAmount ?
                _baseTokensAmount : maxAmount - curAmount;
        IERC20(_baseToken).safeTransferFrom(_gp, address(this), amount);
        if (_create) {
            _GPS.insertGP(_ipToken, _baseToken, _gp, amount, true);
        } else {
            uint256 oriAmount = _GPS.getGPRunningDepositAmount(_ipToken, _baseToken, _gp);
            require(oriAmount == 0, "Wait To Do");
            _GPS.setGPRunningDepositAmount(_ipToken, _baseToken, _gp, amount);
        }

        require(amount > 0, "Deposit Zero");
        return amount;
    }

    function GPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
    
        external
        lockPool(_ipToken, _baseToken)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _gp = msg.sender;
        uint256 amount = _GPS.getGPRunningDepositAmount(_ipToken, _baseToken, _gp);

        require(amount > 0, "Already done");
        _GPS.setCurGPAmount(_ipToken, _baseToken,
                            _GPS.getCurGPAmount(_ipToken, _baseToken).add(amount));
        _GPS.setGPBaseAmount(_ipToken, _baseToken, _gp,
                             _GPS.getGPBaseAmount(_ipToken, _baseToken, _gp).add(amount));
        _GPS.setGPRunningDepositAmount(_ipToken, _baseToken, _gp, 0);

        // Update balance should before raise from LP.
        updateGPBalance(_ipToken, _baseToken);

        uint256 _amount = amount.sub(chargeVaultFee(_ipToken, _baseToken, amount));
        uint256 raiseLP = raiseFromLP(_ipToken, _baseToken, _amount);
        uint256 oriBalance = _GPS.getGPBaseBalance(_ipToken, _baseToken, _gp);
        _GPS.setGPBaseBalance(_ipToken, _baseToken, _gp, oriBalance.add(_amount));
        oriBalance = _GPS.getCurGPBalance(_ipToken, _baseToken);
        _GPS.setCurGPBalance(_ipToken, _baseToken, oriBalance.add(_amount));
        
        uint256 swappedIP = NPSwap.swap(_baseToken, _ipToken,
                                           _amount.add(raiseLP));
        oriBalance = _GPS.getCurIPAmount(_ipToken, _baseToken);
        _GPS.setCurIPAmount(_ipToken, _baseToken, oriBalance.add(swappedIP));
        allocateFunds(_ipToken, _baseToken);
    }

    function updateMaxIPCanRaise(
        address _ipToken,
        address _baseToken
    )
        private
        returns (uint256 maxAmount)
    {
        uint256 inUnit = 10**ERC20(_baseToken).decimals();
        uint256 price = NPSwap.getAmountOut(_baseToken, _ipToken, inUnit);
        uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint256 initPrice = _IPS.getPoolInitPrice(_ipToken, _baseToken);
        uint32 impawnRatio = _IPS.getIPImpawnRatio(_ipToken, _baseToken);
        // part 1
        uint256 amount = IPStake.mul(impawnRatio).div(RATIO_FACTOR).mul(price.sqrt()).div(initPrice.sqrt()).mul(inUnit).div(initPrice);
        maxAmount = amount;
        // part2
        amount = IPStake.mul(impawnRatio).div(RATIO_FACTOR).mul(alpha).div(RATIO_FACTOR).mul(inUnit).div(initPrice);
        amount = amount.mul(price).div(initPrice);
        maxAmount = maxAmount.add(amount);

        amount = _IPS.getIPInitCanRaise(_ipToken, _baseToken);
        maxAmount = maxAmount > amount ? maxAmount : amount;
        _IPS.setIPMaxCanRaise(_ipToken, _baseToken, maxAmount);
    }

    function chargeVaultFee(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 fee)
    {
        uint32 chargeRatio = _IPS.getIPChargeRatio(_ipToken, _baseToken);

        fee = _amount.mul(chargeRatio).div(RATIO_FACTOR);
        _VTS.setTotalVault(_ipToken, _baseToken,
                           _VTS.getTotalVault(_ipToken, _baseToken).add(fee));
        _VTS.setCurVault(_ipToken, _baseToken,
                         _VTS.getCurVault(_ipToken, _baseToken).add(fee));
        return fee;
    }

    function raiseFromLP(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 amount)
    {
        uint256 curLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 curRaiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        amount = _amount.mul(raiseRatio).div(RATIO_FACTOR);
        amount = amount > curLPAmount.sub(curRaiseLP) ?
                         curLPAmount.sub(curRaiseLP) : amount;
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, curRaiseLP.add(amount));
        return amount;
    }

    function updateGPBalance(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        if (IPAmount == 0) {
            // No GP in this pool before, return directly.
            return;
        }
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 len = _GPS.getGPArrayLength(_ipToken, _baseToken);
        // If sub fail, the pool should do GP liquidation.
        uint256 balance = IPAmount.mul(price).div(inUnit).sub(_GPS.getCurRaiseLPAmount(_ipToken, _baseToken));

        _GPS.setCurGPBalance(_ipToken, _baseToken, balance);
        for (uint256 i = 0; i < len; i++) {
            address gp = _GPS.getGPByIndex(_ipToken, _baseToken, i);
            uint256 amount = _GPS.getGPHoldIPAmount(_ipToken, _baseToken, gp);
            _GPS.setGPBaseBalance(_ipToken, _baseToken, gp,
                                  amount.mul(balance).div(IPAmount));
        }
    }

    function allocateFunds(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 len = _GPS.getGPArrayLength(_ipToken, _baseToken);
        uint256 balance = _GPS.getCurGPBalance(_ipToken, _baseToken);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 resIPAmount = IPAmount;
        uint256 resRaiseLP = raiseLP;

        for (uint256 i = 0; i < len; i++) {
            address gp = _GPS.getGPByIndex(_ipToken, _baseToken, i);
            uint256 gpBalance = _GPS.getGPBaseBalance(_ipToken, _baseToken, gp);

            uint256 curAmount = gpBalance.mul(IPAmount).div(balance);
            resIPAmount -= curAmount;
            curAmount = i == len - 1 ? curAmount.add(resIPAmount) : curAmount;
            _GPS.setGPHoldIPAmount(_ipToken, _baseToken, gp, curAmount);

            curAmount = gpBalance.mul(raiseLP).div(balance);
            resRaiseLP -= curAmount;
            curAmount = i == len - 1 ? curAmount.add(resRaiseLP) : curAmount;
            _GPS.setGPRaiseLPAmount(_ipToken, _baseToken, gp, curAmount);
        }
    }
}