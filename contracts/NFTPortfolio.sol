// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./IPancakeRouter02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IToken.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

contract NFTPortfolio {
    address internal constant pancakeSwapAddress =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3; //Router for pancake bsc testnet
    // address internal constant pancakeSwapAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E; //Router for bsc mainnet
    IPancakeRouter02 public pancakeSwapRouter;

    address private vault = 0x6056773C28c258425Cf9BC8Ba5f86B8031863164;

    IToken public nftToken;

    using SafeMath for uint256;

    address private crypto11 = 0xf34D883EcdE3238B153f38230987a0F4c221a48F; // AXS
    address private crypto12 = 0x8bf2dF0Ff8528088475183a68678bd1Cd7691b69; // MANA
    address private crypto13 = 0x1631A54AC95Ecb0085dB6b8ACf80c4Cee72AEB06; // SAND
    address private crypto14 = 0x19A5E53eC7B385dbE2E587Ba989eA2AB8F7EaF1e; // THETA -- stop
    address private crypto15 = 0xe5c48084E1974a971Bd5dF4d9B01daCCA86d5567; // FLOW
    address private crypto16 = 0xC5De9d5B0BA5b408a3e9530A1BC310d8F2dCC26a; // XTZ
    address private crypto17 = 0x4bf1CE8E4c4c86126E57Fa9fc3f1a9631661641c; // GALA
    address private crypto18 = 0xdeEC6f0C22970b9b8a47069bE619bfAe646dEe26; // CHZ
    address private crypto19 = 0xb08A1959f57b9cC8e5A5F1d329EfD90EE3438F65; // ENJ
    address private crypto20 = 0x30c1AC77F4068A063648B549ffF96Ddb9d151325; // ROSE

    mapping(address => uint256) public axsBalance;
    mapping(address => uint256) public manaBalance;
    mapping(address => uint256) public sandBalance;
    mapping(address => uint256) public thetaBalance;
    mapping(address => uint256) public flowalance;
    mapping(address => uint256) public xtzBalance;
    mapping(address => uint256) public galaBalance;
    mapping(address => uint256) public chzBalance;
    mapping(address => uint256) public enjBalance;
    mapping(address => uint256) public roseBalance;

    struct rate {
        uint256 numerator;
        uint256 denominator;
    }
    mapping(address => uint256) admins;
    rate public currentRate;

    constructor() {
        pancakeSwapRouter = IPancakeRouter02(pancakeSwapAddress);
        nftToken = IToken(0x817ea2A5Fd281d15CA70B05abB5E094356C42996);
    }

    function updateRate(uint256 _numerator, uint256 _denominator) public {
        require(_numerator != 0);
        require(_denominator != 0);
        currentRate.numerator = _numerator;
        currentRate.denominator = _denominator;
    }

    function setUpDataNFT(
        uint256 axs,
        uint256 mana,
        uint256 sand,
        uint256 theta,
        uint256 flow,
        uint256 xtz,
        uint256 gala,
        uint256 chz,
        uint256 enj,
        uint256 rose,
        address user
    ) public {
        axsBalance[user] = axsBalance[user] + axs;
        manaBalance[user] = manaBalance[user] + mana;
        sandBalance[user] = sandBalance[user] + sand;
        thetaBalance[user] = thetaBalance[user] + theta;
        flowalance[user] = flowalance[user] + flow;
        xtzBalance[user] = xtzBalance[user] + xtz;
        galaBalance[user] = galaBalance[user] + gala;
        chzBalance[user] = chzBalance[user] + chz;
        enjBalance[user] = enjBalance[user] + enj;
        roseBalance[user] = roseBalance[user] + rose;
    }

    function editDataNFT(
        uint256 axs,
        uint256 mana,
        uint256 sand,
        uint256 theta,
        uint256 flow,
        uint256 xtz,
        uint256 gala,
        uint256 chz,
        uint256 enj,
        uint256 rose,
        address user
    ) public {
        axsBalance[user] = axsBalance[user] - axs;
        manaBalance[user] = manaBalance[user] - mana;
        sandBalance[user] = sandBalance[user] - sand;
        thetaBalance[user] = thetaBalance[user] - theta;
        flowalance[user] = flowalance[user] - flow;
        xtzBalance[user] = xtzBalance[user] - xtz;
        galaBalance[user] = galaBalance[user] - gala;
        chzBalance[user] = chzBalance[user] - chz;
        enjBalance[user] = enjBalance[user] - enj;
        roseBalance[user] = roseBalance[user] - rose;
    }

    function investInFundDefi() public payable {
        // approve
        nftToken.approve(address(this), msg.value);

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
        }(0, getPathForETH(crypto11), vault, deadline);

        crpyto2Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto12), vault, deadline);

        crpyto3Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto13), vault, deadline);

        crpyto4Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto14), vault, deadline);

        crpyto5Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto15), vault, deadline);

        crpyto6Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto16), vault, deadline);

        crpyto7Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto17), vault, deadline);

        crpyto8Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto18), vault, deadline);

        crpyto9Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto19), vault, deadline);

        crpyto10Amount = pancakeSwapRouter.swapExactETHForTokens{
            value: msg.value / 10
        }(0, getPathForETH(crypto20), vault, deadline);

        setUpDataNFT(
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
        nftToken.mint(msg.sender, tokenAmount);
        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    function withdrawFromFundNFT(uint256 tokenAmount) public payable {
        uint256 amount1 = axsBalance[msg.sender];
        uint256 amount2 = manaBalance[msg.sender];
        uint256 amount3 = sandBalance[msg.sender];
        uint256 amount4 = thetaBalance[msg.sender];
        uint256 amount5 = flowalance[msg.sender];
        uint256 amount6 = xtzBalance[msg.sender];
        uint256 amount7 = galaBalance[msg.sender];
        uint256 amount8 = chzBalance[msg.sender];
        uint256 amount9 = enjBalance[msg.sender];
        uint256 amount10 = roseBalance[msg.sender];

        // IDT Token Burn
        TransferHelper.safeTransferFrom(
            address(nftToken),
            msg.sender,
            address(this),
            tokenAmount
        );
        TransferHelper.safeApprove(
            address(nftToken),
            address(this),
            tokenAmount
        );

        nftToken.burn(address(this), tokenAmount);
        // -------------------------------------------------------------------------------------------- //

        //Getting Investment Back From Vault to Contract
        TransferHelper.safeTransferFrom(
            address(crypto11),
            vault,
            address(this),
            amount1
        );
        TransferHelper.safeApprove(
            address(crypto11),
            address(pancakeSwapRouter),
            amount1
        );

        TransferHelper.safeTransferFrom(
            address(crypto12),
            vault,
            address(this),
            amount2
        );
        TransferHelper.safeApprove(
            address(crypto12),
            address(pancakeSwapRouter),
            amount2
        );

        TransferHelper.safeTransferFrom(
            address(crypto13),
            vault,
            address(this),
            amount3
        );
        TransferHelper.safeApprove(
            address(crypto13),
            address(pancakeSwapRouter),
            amount3
        );

        TransferHelper.safeTransferFrom(
            address(crypto14),
            vault,
            address(this),
            amount4
        );
        TransferHelper.safeApprove(
            address(crypto14),
            address(pancakeSwapRouter),
            amount4
        );

        TransferHelper.safeTransferFrom(
            address(crypto15),
            vault,
            address(this),
            amount5
        );
        TransferHelper.safeApprove(
            address(crypto15),
            address(pancakeSwapRouter),
            amount6
        );

        TransferHelper.safeTransferFrom(
            address(crypto16),
            vault,
            address(this),
            amount6
        );
        TransferHelper.safeApprove(
            address(crypto16),
            address(pancakeSwapRouter),
            amount6
        );

        TransferHelper.safeTransferFrom(
            address(crypto17),
            vault,
            address(this),
            amount7
        );
        TransferHelper.safeApprove(
            address(crypto17),
            address(pancakeSwapRouter),
            amount7
        );

        TransferHelper.safeTransferFrom(
            address(crypto18),
            vault,
            address(this),
            amount8
        );
        TransferHelper.safeApprove(
            address(crypto18),
            address(pancakeSwapRouter),
            amount8
        );

        TransferHelper.safeTransferFrom(
            address(crypto19),
            vault,
            address(this),
            amount9
        );
        TransferHelper.safeApprove(
            address(crypto19),
            address(pancakeSwapRouter),
            amount9
        );

        TransferHelper.safeTransferFrom(
            address(crypto20),
            vault,
            address(this),
            amount10
        );
        TransferHelper.safeApprove(
            address(crypto20),
            address(pancakeSwapRouter),
            amount10
        );

        // ------------------------------------------------------------------------------------------------ //

        // Converting back to BNB
        uint256 deadline = block.timestamp + 15;

        pancakeSwapRouter.swapExactTokensForETH(
            amount1,
            0,
            getPathForToken(crypto11),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount2,
            0,
            getPathForToken(crypto12),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount3,
            0,
            getPathForToken(crypto13),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount4,
            0,
            getPathForToken(crypto14),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount5,
            0,
            getPathForToken(crypto15),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount6,
            0,
            getPathForToken(crypto16),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount7,
            0,
            getPathForToken(crypto17),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount8,
            0,
            getPathForToken(crypto18),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount9,
            0,
            getPathForToken(crypto19),
            msg.sender,
            deadline
        );
        pancakeSwapRouter.swapExactTokensForETH(
            amount10,
            0,
            getPathForToken(crypto20),
            msg.sender,
            deadline
        );

        editDataNFT(
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
