// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


library NPSwap {
     using SafeERC20 for IERC20;

    function getAmountOut(
        address inToken,
        address outToken,
        uint256 inAmount
    )
        public view
        returns (uint256 outAmount)
    {
        (address router,,) = getSwapParameter();
        (uint256 reserveIn, uint256 reserveOut) = getReserves(inToken, outToken);
        outAmount = IUniswapV2Router02(router).getAmountOut(inAmount, reserveIn, reserveOut);
    }

    function getAmountIn(
        address inToken,
        address outToken,
        uint256 outAmount
    )
        public view
        returns (uint256 inAmount)
    {
        (address router,,) = getSwapParameter();
        (uint256 reserveIn, uint256 reserveOut) = getReserves(inToken, outToken);
        inAmount = IUniswapV2Router02(router).getAmountIn(outAmount, reserveIn, reserveOut);
    }

    function swap(
        address inToken,
        address outToken,
        uint256 inAmount
    )
        public
        returns (uint256 outAmount)
    {
        (address router,,) = getSwapParameter();
        IERC20(inToken).safeApprove(router, inAmount);

        address[] memory path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;

        uint[] memory amounts = IUniswapV2Router02(router).swapExactTokensForTokens(
            inAmount, 0, path, address(this), block.timestamp + 10 minutes);
        outAmount = amounts[1];
    }

    function sortTokens(
        address tokenA,
        address tokenB
    )
        internal pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, 'NPSwap: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'NPSwap: ZERO_ADDRESS');
    }

    function pairFor(
        address tokenA,
        address tokenB
    )
        internal view
        returns (address pair)
    {
        (, address factory, bytes32 initalCodeHash) = getSwapParameter();
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                initalCodeHash // init code hash
            )))));
    }

    function getReserves(
        address tokenA,
        address tokenB
    )
        internal view
        returns (uint reserveA, uint reserveB)
    {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(
                        pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) :
                        (reserve1, reserve0);
    }
    
    function getSwapParameter(
    )
        internal view
        returns (address router, address factory, bytes32 initalCodeHash)
    {
        //Uniswap - Ethereum
        address routerUni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address factoryUni = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        bytes32 initalCodeHashUni = hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f';

        //Pancake-swap - BSc
        address routerPancake = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address factoryPancake = address(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
        bytes32 initalCodeHashPancake = hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5';
        //backup codehash from Pancake Github
        //bytes32 initalCodeHashPancake = hex'd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66';
        
        //Pancake-swap - BSc testnet
        address routerPancakeTest = address(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        address factoryPancakeTest = address(0x6725F303b657a9451d8BA641348b6761A6CC7a17);
        bytes32 initalCodeHashPancakeTest = hex'd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66';

        //Quickswap - Polygon
        address routerQuick = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
        address factoryQuick = address(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32);
        bytes32 initalCodeHashQuick = hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f';

        uint256 chainID = block.chainid;

        //Ethereum Main, Ropsten, Rinkeby
        if(chainID == 1 || chainID == 3 || chainID == 4) return(routerUni, factoryUni, initalCodeHashUni);
        //BSC Mainnet
        else if(chainID == 56) return(routerPancake, factoryPancake, initalCodeHashPancake);
        //BSC Mainnet ,Testnet
        else if(chainID == 97) return(routerPancakeTest, factoryPancakeTest, initalCodeHashPancakeTest);
        //polygon, Mumbai Testnet(testnet of polygon)
        else if(chainID == 137 || chainID == 80001) return(routerQuick, factoryQuick, initalCodeHashQuick);
        else revert("Not Supported chainID");
    }
}
