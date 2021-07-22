// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract LPLogic is BaseLogic {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function LPDepositRaising(
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
        address _lp = msg.sender;
        uint256 oriLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);

        amount = _baseTokensAmount;
        IERC20(_baseToken).safeTransferFrom(_lp, address(this), amount);
        _LPS.setCurLPAmount(_ipToken, _baseToken, oriLPAmount.add(amount));
        if (_create) {
            _LPS.insertLP(_ipToken, _baseToken, _lp, amount, false);
        } else {
            uint256 oriAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
            _LPS.setLPBaseAmount(_ipToken, _baseToken, _lp, oriAmount.add(amount));
        }
        
        require(amount > 0, "Deposit Zero");
        return amount;
    }

    function LPDepositRunning(
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
        address _lp = msg.sender;

        amount = _baseTokensAmount;
        IERC20(_baseToken).safeTransferFrom(_lp, address(this), amount);
        if (_create) {
            _LPS.insertLP(_ipToken, _baseToken, _lp, amount, true);
        } else {
            uint256 oriAmount = _LPS.getLPRunningDepositAmount(_ipToken, _baseToken, _lp);
            require(oriAmount == 0, "Wait To Do");
            _LPS.setLPRunningDepositAmount(_ipToken, _baseToken, _lp, amount);
        }

        require(amount > 0, "Deposit Zero");
        return amount;
    }

    function LPDoDepositRunning(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _lp = msg.sender;
        uint256 oriLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 oriAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        uint256 curRaiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 amount = _LPS.getLPRunningDepositAmount(_ipToken, _baseToken, _lp);

        require(amount > 0, "Already done");
        _LPS.setLPRunningDepositAmount(_ipToken, _baseToken, _lp, 0);
        _LPS.setCurLPAmount(_ipToken, _baseToken, oriLPAmount.add(amount));
        _LPS.setLPBaseAmount(_ipToken, _baseToken, _lp, oriAmount.add(amount));

        lendToGP(_ipToken, _baseToken, oriLPAmount.add(amount).sub(curRaiseLP));
    }

    function LPWithdrawRunning(
        address _ipToken,
        address _baseToken,
        uint256 _baseTokensAmount,
        bool _vaultOnly
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (uint256 amount)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RUNNING);
        address _lp = msg.sender;

        if (_vaultOnly) {
            amount = _LPS.getLPVaultReward(_ipToken, _baseToken, _lp);
            _LPS.setLPVaultReward(_ipToken, _baseToken, _lp, 0);
            IERC20(_baseToken).safeTransfer(_lp, amount);
            return amount;
        }

        // Withdraw all base token, ignore input amount
        _baseTokensAmount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        amount = reclaimFromGP(_ipToken, _baseToken, _baseTokensAmount);
        amount = amount.add(_LPS.getLPVaultReward(_ipToken, _baseToken, _lp));
        amount = amount.sub(chargeFee(_ipToken, _baseToken, _lp));
        IERC20(_baseToken).safeTransfer(_lp, amount);
        _LPS.deleteLP(_ipToken, _baseToken, _lp);

        return amount;
    }

    function lendToGP(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 lend)
    {
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 raiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 balance = IPAmount.mul(price).div(inUnit);

        if (raiseLP >= balance ||
            balance.mul(RATIO_FACTOR).div(balance.sub(raiseLP)) >=
            raiseRatio + RATIO_FACTOR) {
            lend = 0;
            return lend;
        }

        uint256 GPBalance = balance.sub(raiseLP);
        lend = GPBalance.mul(raiseRatio + RATIO_FACTOR).div(RATIO_FACTOR).sub(balance);
        lend = lend > _amount ? _amount : lend;

        uint256 swappedIP = NPSwap.swap(_baseToken, _ipToken, lend);
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, raiseLP.add(lend));
        _GPS.setCurIPAmount(_ipToken, _baseToken, IPAmount.add(swappedIP));
        allocateFunds(_ipToken, _baseToken);

        return lend;
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

    function reclaimFromGP(
        address _ipToken,
        address _baseToken,
        uint256 _amount
    )
        private
        returns (uint256 amount)
    {
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _GPS.getCurIPAmount(_ipToken, _baseToken);
        uint256 LPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        uint256 curRaiseLP = _GPS.getCurRaiseLPAmount(_ipToken, _baseToken);
        uint256 balance = IPAmount.mul(price).div(inUnit);
        uint256 expect;

        if (curRaiseLP >= balance ||
            balance.mul(RATIO_FACTOR).div(balance.sub(curRaiseLP)) >=
            raiseRatio + RATIO_FACTOR) {
            expect = curRaiseLP > _amount ? _amount : curRaiseLP;
        } else {
            expect = _amount > LPAmount.sub(curRaiseLP) ?
                     _amount.sub(LPAmount.sub(curRaiseLP)) : 0;
        }

        if (expect == 0) {
            amount = _amount;
            _LPS.setCurLPAmount(_ipToken, _baseToken, LPAmount.sub(_amount));
            return amount;
        }

        uint256 swappedIP = expect.mul(inUnit).div(price);
        uint256 real = NPSwap.swap(_ipToken, _baseToken, swappedIP);
        _GPS.setCurIPAmount(_ipToken, _baseToken, IPAmount.sub(swappedIP));
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, curRaiseLP.sub(expect));
        _LPS.setCurLPAmount(_ipToken, _baseToken, LPAmount.sub(_amount));
        allocateFunds(_ipToken, _baseToken);

        amount = real > expect ? _amount.add(real.sub(expect)) :
                   _amount.sub(expect.sub(real));
        return amount;
    }

    function chargeFee(
        address _ipToken,
        address _baseToken,
        address _lp
    )
        private
        returns (uint256 fee)
    {
        uint256 amount = _LPS.getLPBaseAmount(_ipToken, _baseToken, _lp);
        fee = amount.mul(1).div(100);
        IERC20(_baseToken).safeTransfer(DGTBeneficiary, fee);
        return fee;
    }
}