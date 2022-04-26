// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.5.16;

import "./VBep20.sol";
import "./IBEP20.sol";
import "./TransferHelper.sol";

contract Lending {
    address public vault;

    // BTC
    IBEP20 public underlyingBTC;
    VBep20 public vBTCToken;

    // ETH
    IBEP20 public underlyingETH;
    VBep20 public vETHToken;

    // XRP
    IBEP20 public underlyingXRP;
    VBep20 public vXRPToken;

    // LTC
    IBEP20 public underlyingLTC;
    VBep20 public vLTCToken;

    // DAI
    IBEP20 public underlyingDAI;
    VBep20 public vDAIToken;

    constructor() public {
        vault = 0x6056773C28c258425Cf9BC8Ba5f86B8031863164;

        // BTC
        underlyingBTC = IBEP20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
        vBTCToken = VBep20(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);

        // ETH
        underlyingETH = IBEP20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
        vETHToken = VBep20(0xf508fCD89b8bd15579dc79A6827cB4686A3592c8);

        // LTC
        underlyingLTC = IBEP20(0x4338665CBB7B2485A8855A139b75D5e34AB0DB94);
        vLTCToken = VBep20(0x57A5297F2cB2c0AaC9D554660acd6D385Ab50c6B);

        // DAI
        underlyingDAI = IBEP20(0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3);
        vDAIToken = VBep20(0x334b3eCB4DCa3593BCCC3c7EBD1A1C1d1780FBF1);

        // XRP
        underlyingXRP = IBEP20(0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE);
        vXRPToken = VBep20(0xB248a295732e0225acd3337607cc01068e3b9c10);
    }

    function lendTokens(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        uint256 amount4,
        uint256 amount5
    ) public {
        // BTC
        TransferHelper.safeTransferFrom(
            0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c,
            vault,
            address(this),
            amount1
        );

        underlyingBTC.approve(address(vBTCToken), amount1);
        assert(vBTCToken.mint(amount1) == 0);

        // ETH
        TransferHelper.safeTransferFrom(
            0x2170Ed0880ac9A755fd29B2688956BD959F933F8,
            vault,
            address(this),
            amount2
        );
        underlyingETH.approve(address(vETHToken), amount2);
        assert(vETHToken.mint(amount2) == 0);

        // LTC
        TransferHelper.safeTransferFrom(
            0x4338665CBB7B2485A8855A139b75D5e34AB0DB94,
            vault,
            address(this),
            amount3
        );

        underlyingLTC.approve(address(vLTCToken), amount3);
        assert(vLTCToken.mint(amount3) == 0);

        // DAI
        TransferHelper.safeTransferFrom(
            0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3,
            vault,
            address(this),
            amount4
        );

        underlyingDAI.approve(address(vDAIToken), amount4);
        assert(vDAIToken.mint(amount4) == 0);

        // XRP
        TransferHelper.safeTransferFrom(
            0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE,
            vault,
            address(this),
            amount5
        );

        underlyingXRP.approve(address(vXRPToken), amount5);
        assert(vXRPToken.mint(amount5) == 0);
    }

    function redeemTokens(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        uint256 amount4,
        uint256 amount5
    ) public {
        // BTC
        assert(vBTCToken.redeemUnderlying(amount1) == 0);
        underlyingBTC.transfer(vault, amount1);

        // ETH
        assert(vETHToken.redeemUnderlying(amount2) == 0);
        underlyingETH.transfer(vault, amount2);

        // LTC
        assert(vLTCToken.redeemUnderlying(amount3) == 0);
        underlyingLTC.transfer(vault, amount3);

        // DAI
        assert(vDAIToken.redeemUnderlying(amount4) == 0);
        underlyingDAI.transfer(vault, amount4);

        // XRP
        assert(vXRPToken.redeemUnderlying(amount5) == 0);
        underlyingXRP.transfer(vault, amount5);
    }
}
