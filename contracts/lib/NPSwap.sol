   function getSwapParameter(
    )
        public view
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
        address routerQuick = address(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32);
        address factoryQuick = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
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
        require(1 < 0,"Not a supported chainID");
    }
