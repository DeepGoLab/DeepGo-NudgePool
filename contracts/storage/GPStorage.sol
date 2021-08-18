// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/SafeMath.sol";

contract GPStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // For gas optimization
    uint256 constant NONZERO_INIT = 1;

    struct GPAlloc {
        address     gp;
        uint256     weight;
    }

    struct GPInfo {
        bool        valid;
        uint256     id; // index in GPA
        uint256     baseTokensAmount; // baseToken unit
        uint256     baseTokensBalance; // ipTokensAmount * price - raisedFromLPAmount
        uint256     runningDepositAmount;
        uint256     ipTokensAmount; // ipToken unit, include GP and LP
        uint256     raisedFromLPAmount; // baseToken unit
        uint256     overRaiseAmount;    //baseToken repay to GP after raising end
    }

    struct PoolInfo {
        uint256     curTotalGPAmount; // baseToken unit
        uint256     curTotalBalance; // baseToken unit
        uint256     curTotalLPAmount; // baseToken unit
        uint256     curTotalIPAmount; // baseToken swapped into ipToken amount
        uint256     liquidationBaseAmount; // baseToken repay to GP
        uint256     liquidationIPAmount; // IPToken repay to GP

        address[]   GPA;
        mapping(address => GPInfo) GPM;
    }

    address public admin;
    address public proxy;
    mapping(address => mapping(address => PoolInfo)) private pools;

    constructor() {
        admin = msg.sender;
    }

    function setProxy(address _proxy) external {
        require(admin == msg.sender, "Not Permit");
        require(_proxy != address(0), "Invalid Address");
        proxy = _proxy;
    }

    function setCurGPAmount(address _ipt, address _bst, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        pools[_ipt][_bst].curTotalGPAmount = _amount;
    }

    function setCurRaiseLPAmount(address _ipt, address _bst, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        pools[_ipt][_bst].curTotalLPAmount = _amount;
    }

    function setCurIPAmount(address _ipt, address _bst, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        pools[_ipt][_bst].curTotalIPAmount = _amount;
    }

    function setCurGPBalance(address _ipt, address _bst, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        pools[_ipt][_bst].curTotalBalance = _amount;
    }

    function setLiquidationBaseAmount(address _ipt, address _bst, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        pools[_ipt][_bst].liquidationBaseAmount = _amount;
    }

    function setLiquidationIPAmount(address _ipt, address _bst, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        pools[_ipt][_bst].liquidationIPAmount = _amount;
    }

    function setGPBaseAmount(address _ipt, address _bst, address _gp, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = _amount;
    }

    function setGPRunningDepositAmount(address _ipt, address _bst, address _gp, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].runningDepositAmount = _amount;
    }

    function setGPHoldIPAmount(address _ipt, address _bst, address _gp, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].ipTokensAmount = _amount;
    }

    function setGPRaiseLPAmount(address _ipt, address _bst, address _gp, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount = _amount;
    }

    function setGPBaseBalance(address _ipt, address _bst, address _gp, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = _amount;
    }

    function setGPAmount(address _ipt, address _bst, address _gp, uint256 _amount, uint256 retAmount) private {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = _amount;
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = _amount;
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = NONZERO_INIT.add(retAmount);
    }

    function setOverRaiseAmount(address _ipt, address _bst, address _gp, uint256 _amount) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        pools[_ipt][_bst].GPM[_gp].overRaiseAmount = _amount;
    }

    function insertGP(address _ipt, address _bst, address _gp, uint256 _amount, bool running) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == false, "GP Already Exist");
        pools[_ipt][_bst].GPA.push(_gp);

        pools[_ipt][_bst].GPM[_gp].valid = true;
        pools[_ipt][_bst].GPM[_gp].id = pools[_ipt][_bst].GPA.length;
        if (running) {
            pools[_ipt][_bst].GPM[_gp].baseTokensAmount = 0;
            pools[_ipt][_bst].GPM[_gp].runningDepositAmount = _amount;
        } else {
            pools[_ipt][_bst].GPM[_gp].baseTokensAmount = _amount;
            pools[_ipt][_bst].GPM[_gp].runningDepositAmount = 0;
        }

        pools[_ipt][_bst].GPM[_gp].ipTokensAmount = NONZERO_INIT;
        pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount = NONZERO_INIT;
        pools[_ipt][_bst].GPM[_gp].overRaiseAmount = NONZERO_INIT;
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = 0;
    }

    function deleteGP(address _ipt, address _bst, address _gp) external {
        require(proxy == msg.sender, "Not Permit");
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        uint256 id = pools[_ipt][_bst].GPM[_gp].id;
        uint256 length = pools[_ipt][_bst].GPA.length;

        pools[_ipt][_bst].GPA[id - 1] = pools[_ipt][_bst].GPA[length - 1];
        pools[_ipt][_bst].GPM[pools[_ipt][_bst].GPA[length - 1]].id = id;
        pools[_ipt][_bst].GPA.pop();

        pools[_ipt][_bst].GPM[_gp].valid = false;
        pools[_ipt][_bst].GPM[_gp].id = 0;
        pools[_ipt][_bst].GPM[_gp].baseTokensAmount = 0;
        pools[_ipt][_bst].GPM[_gp].runningDepositAmount = 0;
        pools[_ipt][_bst].GPM[_gp].ipTokensAmount = 0;
        pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount = 0;
        pools[_ipt][_bst].GPM[_gp].overRaiseAmount = 0;
        pools[_ipt][_bst].GPM[_gp].baseTokensBalance = 0;
    }

    function getCurGPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalGPAmount;
    }

    function getCurRaiseLPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalLPAmount;
    }

    function getCurIPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalIPAmount;
    }

    function getCurGPBalance(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].curTotalBalance;
    }

    function getLiquidationBaseAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].liquidationBaseAmount;
    }

    function getLiquidationIPAmount(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].liquidationIPAmount;
    }

    function getGPBaseAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].baseTokensAmount;
    }

    function getGPRunningDepositAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].runningDepositAmount;
    }

    function getGPHoldIPAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].ipTokensAmount;
    }

    function getGPRaiseLPAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].raisedFromLPAmount;
    }

    function getGPBaseBalance(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].baseTokensBalance;
    }

    function getOverRaiseAmount(address _ipt, address _bst, address _gp) external view returns(uint256) {
        require(pools[_ipt][_bst].GPM[_gp].valid == true, "GP Not Exist");
        return pools[_ipt][_bst].GPM[_gp].overRaiseAmount.sub(NONZERO_INIT);
    }

    function getGPValid(address _ipt, address _bst, address _gp) external view returns(bool) {
        return pools[_ipt][_bst].GPM[_gp].valid;
    }

    function getGPArrayLength(address _ipt, address _bst) external view returns(uint256) {
        return pools[_ipt][_bst].GPA.length;
    }

    function getGPByIndex(address _ipt, address _bst, uint256 _id) external view returns(address) {
        require(_id < pools[_ipt][_bst].GPA.length, "Wrong ID");
        return pools[_ipt][_bst].GPA[_id];
    }

    function getGPAddresses(address _ipt, address _bst) external view returns(address[] memory) {
        return pools[_ipt][_bst].GPA;
    }

    function allocateFunds(address _ipt, address _bst) external {
        require(proxy == msg.sender, "Not Permit");

        uint256 len = pools[_ipt][_bst].GPA.length;
        uint256 balance = pools[_ipt][_bst].curTotalBalance;
        uint256 IPAmount = pools[_ipt][_bst].curTotalIPAmount;
        uint256 raiseLP = pools[_ipt][_bst].curTotalLPAmount;
        uint256 resIPAmount = IPAmount;
        uint256 resRaiseLP = raiseLP;

        for (uint256 i = 0; i < len; i++) {
            address gp = pools[_ipt][_bst].GPA[i];
            uint256 gpBalance = pools[_ipt][_bst].GPM[gp].baseTokensBalance;

            uint256 curIPAmount = gpBalance.mul(IPAmount).div(balance);
            resIPAmount -= curIPAmount;
            curIPAmount = i == len - 1 ? curIPAmount.add(resIPAmount) : curIPAmount;

            uint256 curRaiseAmount = gpBalance.mul(raiseLP).div(balance);
            resRaiseLP -= curRaiseAmount;
            curRaiseAmount = i == len - 1 ? curRaiseAmount.add(resRaiseLP) : curRaiseAmount;

            pools[_ipt][_bst].GPM[gp].ipTokensAmount = curIPAmount;
            pools[_ipt][_bst].GPM[gp].raisedFromLPAmount = curRaiseAmount;
        }
    }

    function computeOverRaiseAmount(
        address _ipToken,
        address _baseToken,
        address _dgtToken,
        uint256 gpAmount,
        uint256 resAmount
    )
        external
        returns(uint256) {
        require(proxy == msg.sender, "Not Permit");

        uint256 totalWeight = 0;
        uint256 amount;
        uint256 len = pools[_ipToken][_baseToken].GPA.length;
        GPAlloc[] memory helpArr = new GPAlloc[](len);
        for (uint256 i = 0; i < len; i++) {
            address gp = pools[_ipToken][_baseToken].GPA[i];
            amount = pools[_ipToken][_baseToken].GPM[gp].baseTokensAmount;
            helpArr[i].gp = gp;
            helpArr[i].weight = IERC20(_dgtToken).balanceOf(gp).add(1 ether).mul(amount.sqrt());
            totalWeight = totalWeight.add(helpArr[i].weight);

            for (uint256 j = i; j != 0; j--) {
                if (helpArr[j].weight > helpArr[j-1].weight) {
                    GPAlloc memory tmp = GPAlloc(helpArr[j].gp, helpArr[j].weight);
                    helpArr[j].gp = helpArr[j-1].gp;
                    helpArr[j].weight = helpArr[j-1].weight;
                    helpArr[j-1].gp = tmp.gp;
                    helpArr[j-1].weight = tmp.weight;
                } else {
                    break;
                }
            }
        }

        for (uint256 i = 0; i < len; i++) {
            address gp = helpArr[i].gp;
            uint256 expectAmount = resAmount.mul(helpArr[i].weight).div(totalWeight);
            amount = pools[_ipToken][_baseToken].GPM[gp].baseTokensAmount;
            expectAmount = expectAmount > amount ? amount : expectAmount;
            if (expectAmount < amount) {
                uint256 retAmount = amount.sub(expectAmount);
                setGPAmount(_ipToken, _baseToken, gp, expectAmount, retAmount);
                gpAmount = gpAmount.sub(retAmount);
            }
            resAmount = resAmount.sub(expectAmount);
            totalWeight = totalWeight.sub(helpArr[i].weight);
        }

        pools[_ipToken][_baseToken].curTotalGPAmount = gpAmount;
        pools[_ipToken][_baseToken].curTotalBalance = gpAmount;
        return gpAmount;
    }
}