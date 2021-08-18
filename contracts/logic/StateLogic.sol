// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/NPSwap.sol";
import "./BaseLogic.sol";

contract StateLogic is BaseLogic {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function checkAuctionEnd(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        
        poolAtStage(_ipToken, _baseToken, Stages.AUCTING);
    
        uint256 time = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);
        if (block.timestamp < time) {
            return false;
        }

        auctionEnd(_ipToken, _baseToken);
        return true;
    }

    function checkRaisingEnd(
        address _ipToken,
        address _baseToken
    )
        external
        lockPool(_ipToken, _baseToken)
        returns (bool)
    {
        poolAtStage(_ipToken, _baseToken, Stages.RAISING);

        uint256 time = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);
        if (block.timestamp < time.add(raisingDuration)) {
            return false;
        }

        raisingEnd(_ipToken, _baseToken);
        return true;
    }

    function auctionEnd(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 DGTAmount = _IPS.getDGTTokensAmount(_ipToken, _baseToken);
        IERC20(DGTToken).safeTransfer(DGTBeneficiary, DGTAmount);
        updateInitIPCanRaise(_ipToken, _baseToken);
        poolTransitNextStage(_ipToken, _baseToken);
    }

    function updateInitIPCanRaise(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 inUnit = 10**ERC20(_baseToken).decimals();
        uint256 price = NPSwap.getAmountOut(_baseToken, _ipToken, inUnit);
        uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint32 impawnRatio = _IPS.getIPImpawnRatio(_ipToken, _baseToken);
        uint256 initAmount = IPStake.mul(impawnRatio).div(RATIO_FACTOR).mul(inUnit).div(price);

        _IPS.setPoolInitPrice(_ipToken, _baseToken, price);
        _IPS.setIPInitCanRaise(_ipToken, _baseToken, initAmount);
        _IPS.setIPMaxCanRaise(_ipToken, _baseToken, initAmount);
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

    function raisingEnd(
        address _ipToken,
        address _baseToken
    )
        private
    {
        uint256 inUnit = 10**ERC20(_ipToken).decimals();
        uint256 price = NPSwap.getAmountOut(_ipToken, _baseToken, inUnit);
        uint256 IPAmount = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        uint32 closeLine = _IPS.getIPCloseLine(_ipToken, _baseToken);
        uint256 maxAmount = _IPS.getIPMaxCanRaise(_ipToken, _baseToken);
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);

        maxAmount = maxAmount > GPAmount ? GPAmount : maxAmount;
        if (IPAmount.mul(price).div(inUnit).mul(closeLine) <= maxAmount.mul(RATIO_FACTOR)) {
            doRaisingLiquidation(_ipToken, _baseToken);
        } else {
            GPAmount = allocateGP(_ipToken, _baseToken, DGTToken);
            // Transit to next stage when raised zero amount.
            if (GPAmount == 0) {
                poolTransitNextStage(_ipToken, _baseToken);
                return;
            }

            uint256 fee = chargeVaultFee(_ipToken, _baseToken, GPAmount);
            uint256 raiseLP = raiseFromLP(_ipToken, _baseToken, GPAmount.sub(fee));
            uint256 swappedIP = NPSwap.swap(_baseToken, _ipToken,
                                            GPAmount.add(raiseLP).sub(fee));
            _GPS.setCurIPAmount(_ipToken, _baseToken, swappedIP);
            _GPS.allocateFunds(_ipToken, _baseToken);
            poolTransitNextStage(_ipToken, _baseToken);
        }
    }

    function doRaisingLiquidation(
        address _ipToken,
        address _baseToken
    )
        private
    {
        // Penalty to IP, transfer stake token to owner
        uint256 IPStake = _IPS.getIPTokensAmount(_ipToken, _baseToken);
        IERC20(_ipToken).safeTransfer(owner(), IPStake);

        // Repay all GP token back
        uint256 totalGPAmount= _GPS.getCurGPAmount(_ipToken, _baseToken);
        _GPS.setLiquidationBaseAmount(_ipToken, _baseToken, totalGPAmount);

        // Repay all LP token back
        uint256 totalLPAmount = _LPS.getCurLPAmount(_ipToken, _baseToken);
        _LPS.setLiquidationBaseAmount(_ipToken, _baseToken, totalLPAmount);

        // Transit pool to LIQUIDATION stage
        _IPS.setPoolStage(_ipToken, _baseToken, uint8(Stages.LIQUIDATION));
    }

    function allocateGP(
        address _ipToken,
        address _baseToken,
        address _dgtToken
    )
        private
        returns (uint256 amount)
    {
        uint256 GPAmount = _GPS.getCurGPAmount(_ipToken, _baseToken);
        uint256 maxAmount = updateMaxIPCanRaise(_ipToken, _baseToken);

        if (GPAmount <= maxAmount) {
            amount = GPAmount;
            return amount;
        }

        amount = _GPS.computeOverRaiseAmount(_ipToken, _baseToken, _dgtToken, GPAmount, maxAmount);
        return amount;
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
        uint256 time = _IPS.getPoolAuctionEndTime(_ipToken, _baseToken);

        fee = _amount.mul(chargeRatio).div(RATIO_FACTOR);
        _VTS.setTotalVault(_ipToken, _baseToken, fee);
        _VTS.setCurVault(_ipToken, _baseToken, fee);
        _VTS.setLastUpdateTime(_ipToken, _baseToken, time.add(raisingDuration));
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

        amount = _amount.mul(raiseRatio).div(RATIO_FACTOR);
        amount = amount > curLPAmount ? curLPAmount : amount;
        _GPS.setCurRaiseLPAmount(_ipToken, _baseToken, amount);
        return amount;
    }
}