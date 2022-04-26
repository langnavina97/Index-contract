// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.4.22 <0.9.0;

import "./IPancakeRouter02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IToken.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

contract IndexSwap {
    address internal constant pancakeSwapAddress =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3; //Router for pancake bsc testnet
    // address internal constant pancakeSwapAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //Router for bsc mainnet
    IPancakeRouter02 public pancakeSwapRouter;

    address private vault = 0x6056773C28c258425Cf9BC8Ba5f86B8031863164;

    IToken public defiToken;

    using SafeMath for uint256;

    //address private crypto1 = 0x419816F160C9bf1Bb8F297d17E1bF44207B9E06C; // BTC
    address private crypto1 = 0x4b1851167f74FF108A994872A160f1D6772d474b; // BTC
    address private crypto2 = 0x8BaBbB98678facC7342735486C851ABD7A0d17Ca; // ETH -- already existed
    address private crypto3 = 0xBf0646Fa5ABbFf6Af50a9C40D5E621835219d384; // SHIBA
    address private crypto4 = 0xCc00177908830cE1644AEB4aD507Fda3789128Af; // XRP
    address private crypto5 = 0x2F9fd65E3BB89b68a8e2Abd68Db25F5C348F68Ee; // LTC
    address private crypto6 = 0x8a9424745056Eb399FD19a0EC26A14316684e274; // DAI -- already existed
    address private crypto7 = 0x0bBF12a9Ccd7cD0E23dA21eFd3bb16ba807ab069; // LUNA
    address private crypto8 = 0x8D908A42FD847c80Eeb4498dE43469882436c8FF; // LINK
    address private crypto9 = 0x62955C6cA8Cd74F8773927B880966B7e70aD4567; // UNI
    address private crypto10 = 0xb7a58582Df45DBa8Ad346c6A51fdb796D64e0898; // STETH

    mapping(address => uint256) public btcBalance;
    mapping(address => uint256) public ethBalance;
    mapping(address => uint256) public shibaBalance;
    mapping(address => uint256) public xrpBalance;
    mapping(address => uint256) public ltcBalance;
    mapping(address => uint256) public daiBalance;
    mapping(address => uint256) public lunaBalance;
    mapping(address => uint256) public linkBalance;
    mapping(address => uint256) public uniBalance;
    mapping(address => uint256) public stethBalance;

    struct rate {
        uint256 numerator;
        uint256 denominator;
    }
    mapping(address => uint256) admins;
    rate public currentRate;

    constructor() {
        pancakeSwapRouter = IPancakeRouter02(pancakeSwapAddress);
        defiToken = IToken(0xF70538622598232a95B1EC1914Fc878d28EBAE68);
    }

    function updateRate(uint256 _numerator, uint256 _denominator) public {
        require(_numerator != 0);
        require(_denominator != 0);
        currentRate.numerator = _numerator;
        currentRate.denominator = _denominator;
    }

    function setUpDataDeFi(
        uint256 btc,
        uint256 eth,
        uint256 shiba,
        uint256 xrp,
        uint256 ltc,
        uint256 dai,
        uint256 luna,
        uint256 link,
        uint256 uni,
        uint256 steth,
        address user
    ) public {
        btcBalance[user] = btcBalance[user] + btc;
        ethBalance[user] = ethBalance[user] + eth;
        shibaBalance[user] = shibaBalance[user] + shiba;
        xrpBalance[user] = xrpBalance[user] + xrp;
        ltcBalance[user] = ltcBalance[user] + ltc;
        daiBalance[user] = daiBalance[user] + dai;
        lunaBalance[user] = lunaBalance[user] + luna;
        linkBalance[user] = linkBalance[user] + link;
        uniBalance[user] = uniBalance[user] + uni;
        stethBalance[user] = stethBalance[user] + steth;
    }

    function editDataDeFi(
        uint256 btc,
        uint256 eth,
        uint256 shiba,
        uint256 xrp,
        uint256 ltc,
        uint256 dai,
        uint256 luna,
        uint256 link,
        uint256 uni,
        uint256 steth,
        address user
    ) public {
        btcBalance[user] = btcBalance[user] - btc;
        ethBalance[user] = ethBalance[user] - eth;
        shibaBalance[user] = shibaBalance[user] - shiba;
        xrpBalance[user] = xrpBalance[user] - xrp;
        ltcBalance[user] = ltcBalance[user] - ltc;
        daiBalance[user] = daiBalance[user] - dai;
        lunaBalance[user] = lunaBalance[user] - luna;
        linkBalance[user] = linkBalance[user] - link;
        uniBalance[user] = uniBalance[user] - uni;
        stethBalance[user] = stethBalance[user] - steth;
    }

    function investInFundDefi() public payable {
        // approve
        defiToken.approve(address(this), msg.value);

        // update rate
        updateRate(100, 100);

        uint256[] memory crpyto1Amount;
        uint256[] memory crpyto2Amount;
        uint256[] memory crpyto3Amount;
        uint256[] memory crpyto4Amount;
        uint256[] memory crpyto5Amount;
        uint256[] memory crpyto6Amount;
        uint256[] memory crpyto7Amount;
        uint256[] memory crpyto8Amount;
        uint256[] memory crpyto9Amount;
        uint256[] memory crpyto10Amount;

        uint256 deadline = block.timestamp + 15; // using ‘now’ for convenience, for mainnet pass deadline from frontend!

        crpyto1Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto1), vault, deadline);

        crpyto2Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto2), vault, deadline);

        crpyto3Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto3), vault, deadline);

        crpyto4Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto4), vault, deadline);

        crpyto5Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto5), vault, deadline);

        crpyto6Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto6), vault, deadline);

        crpyto7Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto7), vault, deadline);

        crpyto8Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto8), vault, deadline);

        crpyto9Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto9), vault, deadline);

        crpyto10Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto10), vault, deadline);

        setUpDataDeFi(
            crpyto1Amount[1],
            crpyto2Amount[1],
            crpyto3Amount[1],
            crpyto4Amount[1],
            crpyto5Amount[1],
            crpyto6Amount[1],
            crpyto7Amount[1],
            crpyto8Amount[1],
            crpyto9Amount[1],
            crpyto10Amount[1],
            msg.sender
        );
        uint256 cryptoAmount = msg.value;
        uint256 tokenAmount = cryptoAmount.mul(currentRate.numerator).div(
            currentRate.denominator
        );
        defiToken.mint(msg.sender, tokenAmount);
        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function withdrawFromFundTOPTokens(uint256 tokenAmount, uint256 percentage)
        public
        payable
    {
        require(percentage > 0 && percentage <= 100);

        // IDT Token Burn
        TransferHelper.safeTransferFrom(
            address(defiToken),
            msg.sender,
            address(this),
            tokenAmount
        );
        TransferHelper.safeApprove(
            address(defiToken),
            address(this),
            tokenAmount
        );

        defiToken.burn(address(this), tokenAmount);
        // -------------------------------------------------------------------------------------------- //

        //Getting Investment Back From Vault to Contract

        uint256 amount1Per = btcBalance[msg.sender].mul(percentage);
        uint256 amount2Per = ethBalance[msg.sender].mul(percentage);
        uint256 amount3Per = shibaBalance[msg.sender].mul(percentage);
        uint256 amount4Per = xrpBalance[msg.sender].mul(percentage);
        uint256 amount5Per = ltcBalance[msg.sender].mul(percentage);
        uint256 amount6Per = daiBalance[msg.sender].mul(percentage);
        uint256 amount7Per = lunaBalance[msg.sender].mul(percentage);
        uint256 amount8Per = linkBalance[msg.sender].mul(percentage);
        uint256 amount9Per = uniBalance[msg.sender].mul(percentage);
        uint256 amount10Per = stethBalance[msg.sender].mul(percentage);

        uint256 amount1 = amount1Per.div(100);
        uint256 amount2 = amount2Per.div(100);
        uint256 amount3 = amount3Per.div(100);
        uint256 amount4 = amount4Per.div(100);
        uint256 amount5 = amount5Per.div(100);
        uint256 amount6 = amount6Per.div(100);
        uint256 amount7 = amount7Per.div(100);
        uint256 amount8 = amount8Per.div(100);
        uint256 amount9 = amount9Per.div(100);
        uint256 amount10 = amount10Per.div(100);

        TransferHelper.safeTransferFrom(
            address(crypto1),
            vault,
            address(this),
            amount1
        );
        TransferHelper.safeApprove(
            address(crypto1),
            address(pancakeSwapRouter),
            amount1
        );

        TransferHelper.safeTransferFrom(
            address(crypto2),
            vault,
            address(this),
            amount2
        );
        TransferHelper.safeApprove(
            address(crypto2),
            address(pancakeSwapRouter),
            amount2
        );

        TransferHelper.safeTransferFrom(
            address(crypto3),
            vault,
            address(this),
            amount3
        );
        TransferHelper.safeApprove(
            address(crypto3),
            address(pancakeSwapRouter),
            amount3
        );

        TransferHelper.safeTransferFrom(
            address(crypto4),
            vault,
            address(this),
            amount4
        );
        TransferHelper.safeApprove(
            address(crypto4),
            address(pancakeSwapRouter),
            amount4
        );

        TransferHelper.safeTransferFrom(
            address(crypto5),
            vault,
            address(this),
            amount5
        );
        TransferHelper.safeApprove(
            address(crypto5),
            address(pancakeSwapRouter),
            amount6
        );

        TransferHelper.safeTransferFrom(
            address(crypto6),
            vault,
            address(this),
            amount6
        );
        TransferHelper.safeApprove(
            address(crypto6),
            address(pancakeSwapRouter),
            amount6
        );

        TransferHelper.safeTransferFrom(
            address(crypto7),
            vault,
            address(this),
            amount7
        );
        TransferHelper.safeApprove(
            address(crypto7),
            address(pancakeSwapRouter),
            amount7
        );

        TransferHelper.safeTransferFrom(
            address(crypto8),
            vault,
            address(this),
            amount8
        );
        TransferHelper.safeApprove(
            address(crypto8),
            address(pancakeSwapRouter),
            amount8
        );

        TransferHelper.safeTransferFrom(
            address(crypto9),
            vault,
            address(this),
            amount9
        );
        TransferHelper.safeApprove(
            address(crypto9),
            address(pancakeSwapRouter),
            amount9
        );

        TransferHelper.safeTransferFrom(
            address(crypto10),
            vault,
            address(this),
            amount10
        );
        TransferHelper.safeApprove(
            address(crypto10),
            address(pancakeSwapRouter),
            amount10
        );

        // ------------------------------------------------------------------------------------------------ //

        // Converting back to BNB

        uint256 deadline = block.timestamp + 15;

        pancakeSwapRouter.swapExactTokensForETH(
            amount1,
            0,
            getPathForToken(crypto1),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount2,
            0,
            getPathForToken(crypto2),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount3,
            0,
            getPathForToken(crypto3),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount4,
            0,
            getPathForToken(crypto4),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount5,
            0,
            getPathForToken(crypto5),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount6,
            0,
            getPathForToken(crypto6),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount7,
            0,
            getPathForToken(crypto7),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount8,
            0,
            getPathForToken(crypto8),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount9,
            0,
            getPathForToken(crypto9),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount10,
            0,
            getPathForToken(crypto10),
            msg.sender,
            deadline
        );

        editDataDeFi(
            amount1,
            amount2,
            amount3,
            amount4,
            amount5,
            amount6,
            amount7,
            amount8,
            amount9,
            amount10,
            msg.sender
        );
    }

    // function addLiquidity() public payable{
    //   uint deadline = block.timestamp + 15;
    //   token.approve(pancakeSwapAddress,1000000000000000000000000000);
    //   // pancakeSwapRouter.addLiquidityEth{value: msg.value}();
    // }
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
