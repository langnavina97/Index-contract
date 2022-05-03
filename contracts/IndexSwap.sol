pragma solidity <=0.8.10;

import "./IPancakeRouter02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IToken.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity <=0.8.10;

import "https://github.com/pancakeswap/pancake-swap-periphery/blob/master/contracts/interfaces/IPancakeRouter02.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

// // SPDX-License-Identifier: MIT
// pragma solidity <=0.7.6;

/************************************************************************************************
Originally from https://github.com/balancer-labs/balancer-core/blob/master/contracts/BConst.sol

This source code has been modified from the original, which was copied from the github repository
at commit hash f4ed5d65362a8d6cec21662fb6eae233b0babc1f.

Subject to the GPL-3.0 license
*************************************************************************************************/

contract BConst {
    uint256 public constant VERSION_NUMBER = 1;

    /* ---  Weight Updates  --- */

    // Minimum time passed between each weight update for a token.
    uint256 internal constant WEIGHT_UPDATE_DELAY = 1 hours;

    // Maximum percent by which a weight can adjust at a time
    // relative to the current weight.
    // The number of iterations needed to move from weight A to weight B is the floor of:
    // (A > B): (ln(A) - ln(B)) / ln(1.01)
    // (B > A): (ln(A) - ln(B)) / ln(0.99)
    uint256 internal constant WEIGHT_CHANGE_PCT = BONE / 100;

    uint256 internal constant BONE = 10**18;

    uint256 internal constant MIN_BOUND_TOKENS = 2;
    uint256 internal constant MAX_BOUND_TOKENS = 25;

    // Minimum swap fee.
    uint256 internal constant MIN_FEE = BONE / 10**6;
    // Maximum swap or exit fee.
    uint256 internal constant MAX_FEE = BONE / 10;
    // Actual exit fee. 1%
    uint256 internal constant EXIT_FEE = 1e16;

    // Default total of all desired weights. Can differ by up to BONE.
    uint256 internal constant DEFAULT_TOTAL_WEIGHT = BONE * 25;
    // Minimum weight for any token (1/100).
    uint256 internal constant MIN_WEIGHT = BONE / 8;
    uint256 internal constant MAX_WEIGHT = BONE * 25;
    // Maximum total weight.
    uint256 internal constant MAX_TOTAL_WEIGHT = BONE * 26;
    // Minimum balance for a token (only applied at initialization)
    uint256 internal constant MIN_BALANCE = BONE / 10**12;
    // Initial pool tokens
    uint256 internal constant INIT_POOL_SUPPLY = BONE * 100;

    uint256 internal constant MIN_BPOW_BASE = 1 wei;
    uint256 internal constant MAX_BPOW_BASE = (2 * BONE) - 1 wei;
    uint256 internal constant BPOW_PRECISION = BONE / 10**10;

    // Maximum ratio of input tokens to balance for swaps.
    uint256 internal constant MAX_IN_RATIO = BONE / 2;
    // Maximum ratio of output tokens to balance for swaps.
    uint256 internal constant MAX_OUT_RATIO = (BONE / 3) + 1 wei;
}

/************************************************************************************************
Originally from https://github.com/balancer-labs/balancer-core/blob/master/contracts/BNum.sol

This source code has been modified from the original, which was copied from the github repository
at commit hash f4ed5d65362a8d6cec21662fb6eae233b0babc1f.

Subject to the GPL-3.0 license
*************************************************************************************************/

contract BNum is BConst {
    function btoi(uint256 a) internal pure returns (uint256) {
        return a / BONE;
    }

    function bfloor(uint256 a) internal pure returns (uint256) {
        return btoi(a) * BONE;
    }

    function badd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "ERR_ADD_OVERFLOW");
        return c;
    }

    function bsub(uint256 a, uint256 b) internal pure returns (uint256) {
        (uint256 c, bool flag) = bsubSign(a, b);
        require(!flag, "ERR_SUB_UNDERFLOW");
        return c;
    }

    function bsubSign(uint256 a, uint256 b)
        internal
        pure
        returns (uint256, bool)
    {
        if (a >= b) {
            return (a - b, false);
        } else {
            return (b - a, true);
        }
    }

    function bmul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c0 = a * b;
        require(a == 0 || c0 / a == b, "ERR_MUL_OVERFLOW");
        uint256 c1 = c0 + (BONE / 2);
        require(c1 >= c0, "ERR_MUL_OVERFLOW");
        uint256 c2 = c1 / BONE;
        return c2;
    }

    function bdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "ERR_DIV_ZERO");
        uint256 c0 = a * BONE;
        require(a == 0 || c0 / a == BONE, "ERR_DIV_INTERNAL"); // bmul overflow
        uint256 c1 = c0 + (b / 2);
        require(c1 >= c0, "ERR_DIV_INTERNAL"); //  badd require
        uint256 c2 = c1 / b;
        return c2;
    }

    // DSMath.wpow
    function bpowi(uint256 a, uint256 n) internal pure returns (uint256) {
        uint256 z = n % 2 != 0 ? a : BONE;

        for (n /= 2; n != 0; n /= 2) {
            a = bmul(a, a);

            if (n % 2 != 0) {
                z = bmul(z, a);
            }
        }
        return z;
    }

    // Compute b^(e.w) by splitting it into (b^e)*(b^0.w).
    // Use `bpowi` for `b^e` and `bpowK` for k iterations
    // of approximation of b^0.w
    function bpow(uint256 base, uint256 exp) internal pure returns (uint256) {
        require(base >= MIN_BPOW_BASE, "ERR_BPOW_BASE_TOO_LOW");
        require(base <= MAX_BPOW_BASE, "ERR_BPOW_BASE_TOO_HIGH");

        uint256 whole = bfloor(exp);
        uint256 remain = bsub(exp, whole);

        uint256 wholePow = bpowi(base, btoi(whole));

        if (remain == 0) {
            return wholePow;
        }

        uint256 partialResult = bpowApprox(base, remain, BPOW_PRECISION);
        return bmul(wholePow, partialResult);
    }

    function bpowApprox(
        uint256 base,
        uint256 exp,
        uint256 precision
    ) internal pure returns (uint256) {
        // term 0:
        uint256 a = exp;
        (uint256 x, bool xneg) = bsubSign(base, BONE);
        uint256 term = BONE;
        uint256 sum = term;
        bool negative = false;

        // term(k) = numer / denom
        //         = (product(a - i - 1, i=1-->k) * x^k) / (k!)
        // each iteration, multiply previous term by (a-(k-1)) * x / k
        // continue until term is less than precision
        for (uint256 i = 1; term >= precision; i++) {
            uint256 bigK = i * BONE;
            (uint256 c, bool cneg) = bsubSign(a, bsub(bigK, BONE));
            term = bmul(term, bmul(c, x));
            term = bdiv(term, bigK);
            if (term == 0) break;

            if (xneg) negative = !negative;
            if (cneg) negative = !negative;
            if (negative) {
                sum = bsub(sum, term);
            } else {
                sum = badd(sum, term);
            }
        }

        return sum;
    }
}

/*
Originally from https://github.com/balancer-labs/balancer-core/blob/master/contracts/BMath.sol
This source code has been modified from the original, which was copied from the github repository
at commit hash f4ed5d65362a8d6cec21662fb6eae233b0babc1f.
Subject to the GPL-3.0 license
*/

contract BMath is BConst, BNum {
    /*
    // calcSpotPrice                                                                             
    // sP = spotPrice                                                                            
    // bI = tokenBalanceIn                ( bI / wI )         1                                  
    // bO = tokenBalanceOut         sP =  -----------  *  ----------                             
    // wI = tokenWeightIn                 ( bO / wO )     ( 1 - sF )                             
    // wO = tokenWeightOut                                                                       
    // sF = swapFee                                                                              
  */
    function calcSpotPrice(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 swapFee
    ) internal pure returns (uint256 spotPrice) {
        uint256 numer = bdiv(tokenBalanceIn, tokenWeightIn);
        uint256 denom = bdiv(tokenBalanceOut, tokenWeightOut);
        uint256 ratio = bdiv(numer, denom);
        uint256 scale = bdiv(BONE, bsub(BONE, swapFee));
        return (spotPrice = bmul(ratio, scale));
    }

    /*
    // calcOutGivenIn                                                                            
    // aO = tokenAmountOut                                                                       
    // bO = tokenBalanceOut                                                                      
    // bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \      
    // aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |     
    // wI = tokenWeightIn               \      \ ( bI + ( aI * ( 1 - sF )) /              /      
    // wO = tokenWeightOut                                                                       
    // sF = swapFee                                                                              
  */
    function calcOutGivenIn(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 tokenAmountIn,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountOut) {
        uint256 weightRatio = bdiv(tokenWeightIn, tokenWeightOut);
        uint256 adjustedIn = bsub(BONE, swapFee);
        adjustedIn = bmul(tokenAmountIn, adjustedIn);
        uint256 y = bdiv(tokenBalanceIn, badd(tokenBalanceIn, adjustedIn));
        uint256 foo = bpow(y, weightRatio);
        uint256 bar = bsub(BONE, foo);
        tokenAmountOut = bmul(tokenBalanceOut, bar);
        return tokenAmountOut;
    }

    /*
    // calcInGivenOut                                                                            
    // aI = tokenAmountIn                                                                        
    // bO = tokenBalanceOut               /  /     bO      \    (wO / wI)      \                 
    // bI = tokenBalanceIn          bI * |  | ------------  | ^            - 1  |                
    // aO = tokenAmountOut    aI =        \  \ ( bO - aO ) /                   /                 
    // wI = tokenWeightIn           --------------------------------------------                 
    // wO = tokenWeightOut                          ( 1 - sF )                                   
    // sF = swapFee                                                                              
  */
    function calcInGivenOut(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 tokenAmountOut,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountIn) {
        uint256 weightRatio = bdiv(tokenWeightOut, tokenWeightIn);
        uint256 diff = bsub(tokenBalanceOut, tokenAmountOut);
        uint256 y = bdiv(tokenBalanceOut, diff);
        uint256 foo = bpow(y, weightRatio);
        foo = bsub(foo, BONE);
        tokenAmountIn = bsub(BONE, swapFee);
        tokenAmountIn = bdiv(bmul(tokenBalanceIn, foo), tokenAmountIn);
        return tokenAmountIn;
    }

    // calcPoolOutGivenSingleIn
    // pAo = poolAmountOut         /                                              \
    // tAi = tokenAmountIn        ///      /     //    wI \      \\       \     wI \
    // wI = tokenWeightIn        //| tAi *| 1 - || 1 - --  | * sF || + tBi \    --  \
    // tW = totalWeight     pAo=||  \      \     \\    tW /      //         | ^ tW   | * pS - pS
    // tBi = tokenBalanceIn      \\  ------------------------------------- /        /
    // pS = poolSupply            \\                    tBi               /        /
    // sF = swapFee                \                                              /

    // Charge the trading fee for the proportion of tokenAi
    ///  which is implicitly traded to the other pool tokens.
    // That proportion is (1- weightTokenIn)
    // tokenAiAfterFee = tAi * (1 - (1-weightTi) * poolFee);
    function calcPoolOutGivenSingleIn(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 tokenAmountIn,
        uint256 swapFee
    ) internal pure returns (uint256 poolAmountOut) {
        uint256 normalizedWeight = bdiv(tokenWeightIn, totalWeight);
        uint256 zaz = bmul(bsub(BONE, normalizedWeight), swapFee);
        uint256 tokenAmountInAfterFee = bmul(tokenAmountIn, bsub(BONE, zaz));

        uint256 newTokenBalanceIn = badd(tokenBalanceIn, tokenAmountInAfterFee);
        uint256 tokenInRatio = bdiv(newTokenBalanceIn, tokenBalanceIn);

        // uint newPoolSupply = (ratioTi ^ weightTi) * poolSupply;
        uint256 poolRatio = bpow(tokenInRatio, normalizedWeight);
        uint256 newPoolSupply = bmul(poolRatio, poolSupply);
        poolAmountOut = bsub(newPoolSupply, poolSupply);
        return poolAmountOut;
    }

    /*
    // calcSingleInGivenPoolOut                                                                  
    // tAi = tokenAmountIn              //(pS + pAo)\     /    1    \\                           
    // pS = poolSupply                 || ---------  | ^ | --------- || * bI - bI                
    // pAo = poolAmountOut              \\    pS    /     \(wI / tW)//                           
    // bI = balanceIn          tAi =  --------------------------------------------               
    // wI = weightIn                              /      wI  \                                   
    // tW = totalWeight                          |  1 - ----  |  * sF                            
    // sF = swapFee                               \      tW  /                                  
  */
    function calcSingleInGivenPoolOut(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 poolAmountOut,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountIn) {
        uint256 normalizedWeight = bdiv(tokenWeightIn, totalWeight);
        uint256 newPoolSupply = badd(poolSupply, poolAmountOut);
        uint256 poolRatio = bdiv(newPoolSupply, poolSupply);

        //uint newBalTi = poolRatio^(1/weightTi) * balTi;
        uint256 boo = bdiv(BONE, normalizedWeight);
        uint256 tokenInRatio = bpow(poolRatio, boo);
        uint256 newTokenBalanceIn = bmul(tokenInRatio, tokenBalanceIn);
        uint256 tokenAmountInAfterFee = bsub(newTokenBalanceIn, tokenBalanceIn);
        // Do reverse order of fees charged in joinswap_ExternAmountIn, this way
        //     ``` pAo == joinswap_ExternAmountIn(Ti, joinswap_PoolAmountOut(pAo, Ti)) ```
        //uint tAi = tAiAfterFee / (1 - (1-weightTi) * swapFee) ;
        uint256 zar = bmul(bsub(BONE, normalizedWeight), swapFee);
        tokenAmountIn = bdiv(tokenAmountInAfterFee, bsub(BONE, zar));
        return tokenAmountIn;
    }

    /*
    // calcSingleOutGivenPoolIn                                                                  
    // tAo = tokenAmountOut            /      /                                             \\   
    // bO = tokenBalanceOut           /      // pS - (pAi * (1 - eF)) \     /    1    \      \\  
    // pAi = poolAmountIn            | bO - || ----------------------- | ^ | --------- | * b0 || 
    // ps = poolSupply                \      \\          pS           /     \(wO / tW)/      //  
    // wI = tokenWeightIn      tAo =   \      \                                             //   
    // tW = totalWeight                    /     /      wO \       \                             
    // sF = swapFee                    *  | 1 - |  1 - ---- | * sF  |                            
    // eF = exitFee                        \     \      tW /       /                             
  */
    function calcSingleOutGivenPoolIn(
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 poolAmountIn,
        uint256 swapFee
    ) internal pure returns (uint256 tokenAmountOut) {
        uint256 normalizedWeight = bdiv(tokenWeightOut, totalWeight);
        // charge exit fee on the pool token side
        // pAiAfterExitFee = pAi*(1-exitFee)
        uint256 poolAmountInAfterExitFee = bmul(
            poolAmountIn,
            bsub(BONE, EXIT_FEE)
        );
        uint256 newPoolSupply = bsub(poolSupply, poolAmountInAfterExitFee);
        uint256 poolRatio = bdiv(newPoolSupply, poolSupply);

        // newBalTo = poolRatio^(1/weightTo) * balTo;
        uint256 tokenOutRatio = bpow(poolRatio, bdiv(BONE, normalizedWeight));
        uint256 newTokenBalanceOut = bmul(tokenOutRatio, tokenBalanceOut);

        uint256 tokenAmountOutBeforeSwapFee = bsub(
            tokenBalanceOut,
            newTokenBalanceOut
        );

        // charge swap fee on the output token side
        //uint tAo = tAoBeforeSwapFee * (1 - (1-weightTo) * swapFee)
        uint256 zaz = bmul(bsub(BONE, normalizedWeight), swapFee);
        tokenAmountOut = bmul(tokenAmountOutBeforeSwapFee, bsub(BONE, zaz));
        return tokenAmountOut;
    }

    /*
    // calcPoolInGivenSingleOut                                                                  
    // pAi = poolAmountIn               // /               tAo             \\     / wO \     \   
    // bO = tokenBalanceOut            // | bO - -------------------------- |\   | ---- |     \  
    // tAo = tokenAmountOut      pS - ||   \     1 - ((1 - (tO / tW)) * sF)/  | ^ \ tW /  * pS | 
    // ps = poolSupply                 \\ -----------------------------------/                /  
    // wO = tokenWeightOut  pAi =       \\               bO                 /                /   
    // tW = totalWeight           -------------------------------------------------------------  
    // sF = swapFee                                        ( 1 - eF )                            
    // eF = exitFee                                                                              
    */
    function calcPoolInGivenSingleOut(
        uint256 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 tokenAmountOut,
        uint256 swapFee
    ) internal pure returns (uint256 poolAmountIn) {
        // charge swap fee on the output token side
        uint256 normalizedWeight = bdiv(tokenWeightOut, totalWeight);
        //uint tAoBeforeSwapFee = tAo / (1 - (1-weightTo) * swapFee) ;
        uint256 zoo = bsub(BONE, normalizedWeight);
        uint256 zar = bmul(zoo, swapFee);
        uint256 tokenAmountOutBeforeSwapFee = bdiv(
            tokenAmountOut,
            bsub(BONE, zar)
        );

        uint256 newTokenBalanceOut = bsub(
            tokenBalanceOut,
            tokenAmountOutBeforeSwapFee
        );
        uint256 tokenOutRatio = bdiv(newTokenBalanceOut, tokenBalanceOut);

        //uint newPoolSupply = (ratioTo ^ weightTo) * poolSupply;
        uint256 poolRatio = bpow(tokenOutRatio, normalizedWeight);
        uint256 newPoolSupply = bmul(poolRatio, poolSupply);
        uint256 poolAmountInAfterExitFee = bsub(poolSupply, newPoolSupply);

        // charge exit fee on the pool token side
        // pAi = pAiAfterExitFee/(1-exitFee)
        poolAmountIn = bdiv(poolAmountInAfterExitFee, bsub(BONE, EXIT_FEE));
        return poolAmountIn;
    }
}

interface itoken {
    function mint(address to, uint256 amount) external;

    function burn(address to, uint256 amount) external;

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract TokenBase is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("INDEXLY", "IDX") {}
}

contract IndexSwap is TokenBase, BMath {
    address internal constant pancakeSwapAddress =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3; //Router for pancake bsc testnet

    //address internal constant pancakeSwapAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //Router for bsc mainnet

    IPancakeRouter02 public pancakeSwapRouter;

    // IERC20 public token;

    using SafeMath for uint256;

    address private vault = 0x67C9E63b7288b7bf88Ce114C474CE2fB50ebC8F0;
    //  // Testnet address
    // address private crypto1 = 0xe3a3Fed6a41cAc40D1b38c95a5bB36E4Bb7F1F9B;
    // address private crypto2 = 0x6E17939856143423833CBFF32b4E0dEC714a77EA;
    // address private crypto3 = 0xcC9115C704c1782935e8443eB86c02308C5311Aa;
    // address private crypto4 = 0x9E20F45cB1FD1f55a42C0b6d9e16EefF493FF1d1;
    // address private crypto5 = 0xDd6b59CeAf58c82FE20E9E32e2baB472D631E9Ac;

    // Mainnet Address
    // address private crypto1 = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8; //ETH
    // address private crypto2 = 0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47; //ADA
    // address private crypto3 = 0x4338665CBB7B2485A8855A139b75D5e34AB0DB94; //LTC
    // address private crypto4 = 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402; //DOT
    // address private crypto5 = 0x1Fa4a73a3F0133f0025378af00236f3aBDEE5D63; //NEAR

    // address[5] tokenDefult =[0x2170Ed0880ac9A755fd29B2688956BD959F933F8,
    //                         0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47,
    //                         0x4338665CBB7B2485A8855A139b75D5e34AB0DB94,
    //                         0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402,
    //                         0x1Fa4a73a3F0133f0025378af00236f3aBDEE5D63
    //                         ];

    // uint96[5] denormsDefult= [5,5,5,5,5];
    // address private crypto1 = 0x4b1851167f74FF108A994872A160f1D6772d474b; // BTC
    // address private crypto2 = 0x8BaBbB98678facC7342735486C851ABD7A0d17Ca; // ETH -- already existed
    // address private crypto3 = 0xBf0646Fa5ABbFf6Af50a9C40D5E621835219d384; // SHIBA
    // address private crypto4 = 0xCc00177908830cE1644AEB4aD507Fda3789128Af; // XRP
    // address private crypto5 = 0x2F9fd65E3BB89b68a8e2Abd68Db25F5C348F68Ee; // LTC
    // address private crypto6 = 0x8a9424745056Eb399FD19a0EC26A14316684e274; // DAI -- already existed
    // address private crypto7 = 0x0bBF12a9Ccd7cD0E23dA21eFd3bb16ba807ab069; // LUNA
    // address private crypto8 = 0x8D908A42FD847c80Eeb4498dE43469882436c8FF; // LINK
    // address private crypto9 = 0x62955C6cA8Cd74F8773927B880966B7e70aD4567; // UNI
    // address private crypto10 = 0xb7a58582Df45DBa8Ad346c6A51fdb796D64e0898; // STETH

    address[10] tokenDefult = [
        0x4b1851167f74FF108A994872A160f1D6772d474b, // BTC
        0x8BaBbB98678facC7342735486C851ABD7A0d17Ca, // ETH -- already existed
        0xBf0646Fa5ABbFf6Af50a9C40D5E621835219d384, // SHIBA
        0xCc00177908830cE1644AEB4aD507Fda3789128Af, // XRP
        0x2F9fd65E3BB89b68a8e2Abd68Db25F5C348F68Ee, // LTC*/
        0x8a9424745056Eb399FD19a0EC26A14316684e274, // DAI -- already existed
        0x0bBF12a9Ccd7cD0E23dA21eFd3bb16ba807ab069, // LUNA
        0x8D908A42FD847c80Eeb4498dE43469882436c8FF, // LINK
        0x62955C6cA8Cd74F8773927B880966B7e70aD4567, // UNI
        0xb7a58582Df45DBa8Ad346c6A51fdb796D64e0898 // STETH
    ];

    //uint96[2] denormsDefult=[1,1];
    uint96[10] denormsDefult = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    //uint totalSum;

    struct rate {
        uint256 numerator;
        uint256 denominator;
    }

    /**
     * @dev Token record data structure
     * @param bound is token bound to pool
     * @param ready has token been initialized
     * @param lastDenormUpdate timestamp of last denorm change
     * @param denorm denormalized weight
     * @param desiredDenorm desired denormalized weight (used for incremental changes)
     * @param index index of address in tokens array
     * @param balance token balance
     */
    struct Record {
        bool ready;
        uint40 lastDenormUpdate;
        uint96 denorm;
        uint96 desiredDenorm;
        uint8 index;
        uint256 balance;
    }
    // Array of underlying tokens in the pool.
    address[] internal _tokens;

    // Internal records of the pool's underlying tokens
    mapping(address => Record) internal _records;

    // Total denormalized weight of the pool.
    uint256 internal _totalWeight;

    mapping(address => uint256) admins;

    // True if PUBLIC can call SWAP & JOIN functions
    bool internal _publicSwap;

    rate public currentRate;

    constructor() {
        pancakeSwapRouter = IPancakeRouter02(pancakeSwapAddress);
    }

    /** @dev Emitted when public trades are enabled. */
    event LOG_PUBLIC_SWAP_ENABLED();

    /**
     * @dev Sets up the initial assets for the pool.
     *
     * @param tokens Underlying tokens to initialize the pool with
     * @param denorms Initial denormalized weights for the tokens
     */

    function initialize(address[] calldata tokens, uint96[] calldata denorms)
        external
        onlyOwner
    {
        require(_tokens.length == 0, "INITIALIZED");
        uint256 len = tokens.length;
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            _records[tokens[i]] = Record({
                ready: true,
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denorms[i],
                desiredDenorm: denorms[i],
                index: uint8(i),
                balance: 0
            });
            _tokens.push(tokens[i]);
            totalWeight = badd(totalWeight, denorms[i]);
        }
        _totalWeight = totalWeight;
        _publicSwap = true;
        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    function initializeDefult() external onlyOwner {
        uint256 len = tokenDefult.length;
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            _records[tokenDefult[i]] = Record({
                ready: true,
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denormsDefult[i],
                desiredDenorm: denormsDefult[i],
                index: uint8(i),
                balance: 0
            });
            _tokens.push(tokenDefult[i]);
            totalWeight = badd(totalWeight, denormsDefult[i]);
        }
        _totalWeight = totalWeight;
        _publicSwap = true;
        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    function initializeDefultTest() external onlyOwner {
        uint256 len = tokenDefult.length;
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            _records[tokenDefult[i]] = Record({
                ready: true,
                lastDenormUpdate: uint40(block.timestamp),
                denorm: denormsDefult[i],
                desiredDenorm: denormsDefult[i],
                index: uint8(i),
                balance: 0
            });
            _tokens.push(tokenDefult[i]);
            totalWeight = badd(totalWeight, denormsDefult[i]);
        }
        _totalWeight = totalWeight;
        _publicSwap = true;
        emit LOG_PUBLIC_SWAP_ENABLED();
    }

    function _pushUnderlying(
        address erc20,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = erc20.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "ERC20_FALSE"
        );
    }

    function updateRate(uint256 _numerator, uint256 _denominator) public {
        require(_numerator != 0);
        require(_denominator != 0);
        currentRate.numerator = _numerator;
        currentRate.denominator = _denominator;
    }

    function investInFund(uint256 cryptoAmount) public payable {
        uint256 deadline = block.timestamp + 15; // using 'now' for convenience, for mainnet pass deadline from frontend!
        uint256 amountEth = msg.value;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            Record memory record = _records[t];
            uint256 swapAmount = amountEth.mul(record.denorm).div(_totalWeight);
            pancakeSwapRouter.swapExactETHForTokens{value: swapAmount}(
                0,
                getPathForETH(t),
                vault,
                deadline
            );
        }

        uint256 tokenAmount = cryptoAmount.mul(currentRate.numerator).div(
            currentRate.denominator
        );

        _mint(msg.sender, tokenAmount);

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function withdrawFromFundNew(uint256 tokenAmount) public payable {
        require(tokenAmount <= balanceOf(msg.sender), "not balance");

        uint256 deadline = block.timestamp + 15;

        uint256 totalSupplyIndex = totalSupply();

        _burn(msg.sender, tokenAmount);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];

            IERC20 token = IERC20(t);
            uint256 tokenBalance = token.balanceOf(vault);
            uint256 amount = tokenBalance.mul(tokenAmount).div(
                totalSupplyIndex
            );

            TransferHelper.safeTransferFrom(
                address(t),
                vault,
                address(this),
                amount
            );
            TransferHelper.safeApprove(
                address(t),
                address(pancakeSwapRouter),
                amount
            );
            pancakeSwapRouter.swapExactTokensForETH(
                amount,
                0,
                getPathForToken(t),
                msg.sender,
                deadline
            );
        }
    }

    function getPathForETH(address crypto)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
        path[1] = crypto;

        return path;
    }

    function getPathForToken(address token)
        public
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = pancakeSwapRouter.WETH();

        return path;
    }

    function getETH() public view returns (address) {
        return pancakeSwapRouter.WETH();
    }

    // important to receive ETH
    receive() external payable {}
}
