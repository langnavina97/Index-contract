// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.5.16;

import "./VToken.sol";
import "./ErrorReporter.sol";
import "./Exponential.sol";
import "./PriceOracle.sol";
import "./ComptrollerInterface.sol";
import "./ComptrollerStorage.sol";
import "./Unitroller.sol";
import "./XVS.sol";

/**
 * @title Venus's Comptroller Contract
 * @author Venus
 */
contract Comptroller is
    ComptrollerStorage,
    ComptrollerInterface,
    ComptrollerErrorReporter,
    Exponential
{
    /// @notice Emitted when an admin supports a market
    event MarketListed(VToken vToken);

    /// @notice Emitted when an account enters a market
    event MarketEntered(VToken vToken, address account);

    /// @notice Emitted when an account exits a market
    event MarketExited(VToken vToken, address account);

    /// @notice Emitted when close factor is changed by admin
    event NewCloseFactor(
        uint256 oldCloseFactorMantissa,
        uint256 newCloseFactorMantissa
    );

    /// @notice Emitted when a collateral factor is changed by admin
    event NewCollateralFactor(
        VToken vToken,
        uint256 oldCollateralFactorMantissa,
        uint256 newCollateralFactorMantissa
    );

    /// @notice Emitted when liquidation incentive is changed by admin
    event NewLiquidationIncentive(
        uint256 oldLiquidationIncentiveMantissa,
        uint256 newLiquidationIncentiveMantissa
    );

    /// @notice Emitted when maxAssets is changed by admin
    event NewMaxAssets(uint256 oldMaxAssets, uint256 newMaxAssets);

    /// @notice Emitted when price oracle is changed
    event NewPriceOracle(
        PriceOracle oldPriceOracle,
        PriceOracle newPriceOracle
    );

    /// @notice Emitted when pause guardian is changed
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

    /// @notice Emitted when an action is paused globally
    event ActionPaused(string action, bool pauseState);

    /// @notice Emitted when an action is paused on a market
    event ActionPaused(VToken vToken, string action, bool pauseState);

    /// @notice Emitted when market venus status is changed
    event MarketVenus(VToken vToken, bool isVenus);

    /// @notice Emitted when Venus rate is changed
    event NewVenusRate(uint256 oldVenusRate, uint256 newVenusRate);

    /// @notice Emitted when a new Venus speed is calculated for a market
    event VenusSpeedUpdated(VToken indexed vToken, uint256 newSpeed);

    /// @notice Emitted when XVS is distributed to a supplier
    event DistributedSupplierVenus(
        VToken indexed vToken,
        address indexed supplier,
        uint256 venusDelta,
        uint256 venusSupplyIndex
    );

    /// @notice Emitted when XVS is distributed to a borrower
    event DistributedBorrowerVenus(
        VToken indexed vToken,
        address indexed borrower,
        uint256 venusDelta,
        uint256 venusBorrowIndex
    );

    /// @notice Emitted when VAIController is changed
    event NewVAIController(
        VAIControllerInterface oldVAIController,
        VAIControllerInterface newVAIController
    );

    /// @notice Emitted when VAI mint rate is changed by admin
    event NewVAIMintRate(uint256 oldVAIMintRate, uint256 newVAIMintRate);

    /// @notice Emitted when protocol state is changed by admin
    event ActionProtocolPaused(bool state);

    /// @notice The threshold above which the flywheel transfers XVS, in wei
    uint256 public constant venusClaimThreshold = 0.001e18;

    /// @notice The initial Venus index for a market
    uint224 public constant venusInitialIndex = 1e36;

    // closeFactorMantissa must be strictly greater than this value
    uint256 internal constant closeFactorMinMantissa = 0.05e18; // 0.05

    // closeFactorMantissa must not exceed this value
    uint256 internal constant closeFactorMaxMantissa = 0.9e18; // 0.9

    // No collateralFactorMantissa may exceed this value
    uint256 internal constant collateralFactorMaxMantissa = 0.9e18; // 0.9

    // liquidationIncentiveMantissa must be no less than this value
    uint256 internal constant liquidationIncentiveMinMantissa = 1.0e18; // 1.0

    // liquidationIncentiveMantissa must be no greater than this value
    uint256 internal constant liquidationIncentiveMaxMantissa = 1.5e18; // 1.5

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyProtocolAllowed() {
        require(protocolPaused == false, "protocol is paused");
        _;
    }

    /*** Assets You Are In ***/

    /**
     * @notice Returns the assets an account has entered
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account)
        external
        view
        returns (VToken[] memory)
    {
        return accountAssets[account];
    }

    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param vToken The vToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, VToken vToken)
        external
        view
        returns (bool)
    {
        return markets[address(vToken)].accountMembership[account];
    }

    /**
     * @notice Add assets to be included in account liquidity calculation
     * @param vTokens The list of addresses of the vToken markets to be enabled
     * @return Success indicator for whether each corresponding market was entered
     */
    function enterMarkets(address[] memory vTokens)
        public
        returns (uint256[] memory)
    {
        uint256 len = vTokens.length;

        uint256[] memory results = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            VToken vToken = VToken(vTokens[i]);

            results[i] = uint256(addToMarketInternal(vToken, msg.sender));
        }

        return results;
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param vToken The market to enter
     * @param borrower The address of the account to modify
     * @return Success indicator for whether the market was entered
     */
    function addToMarketInternal(VToken vToken, address borrower)
        internal
        returns (Error)
    {
        Market storage marketToJoin = markets[address(vToken)];

        if (!marketToJoin.isListed) {
            // market is not listed, cannot join
            return Error.MARKET_NOT_LISTED;
        }

        if (marketToJoin.accountMembership[borrower] == true) {
            // already joined
            return Error.NO_ERROR;
        }

        if (accountAssets[borrower].length >= maxAssets) {
            // no space, cannot join
            return Error.TOO_MANY_ASSETS;
        }

        // survived the gauntlet, add to list
        // NOTE: we store these somewhat redundantly as a significant optimization
        //  this avoids having to iterate through the list for the most common use cases
        //  that is, only when we need to perform liquidity checks
        //  and not whenever we want to check if an account is in a particular market
        marketToJoin.accountMembership[borrower] = true;
        accountAssets[borrower].push(vToken);

        emit MarketEntered(vToken, borrower);

        return Error.NO_ERROR;
    }

    /**
     * @notice Removes asset from sender's account liquidity calculation
     * @dev Sender must not have an outstanding borrow balance in the asset,
     *  or be providing necessary collateral for an outstanding borrow.
     * @param vTokenAddress The address of the asset to be removed
     * @return Whether or not the account successfully exited the market
     */
    function exitMarket(address vTokenAddress) external returns (uint256) {
        VToken vToken = VToken(vTokenAddress);
        /* Get sender tokensHeld and amountOwed underlying from the vToken */
        (uint256 oErr, uint256 tokensHeld, uint256 amountOwed, ) = vToken
            .getAccountSnapshot(msg.sender);
        require(oErr == 0, "getAccountSnapshot failed"); // semi-opaque error code

        /* Fail if the sender has a borrow balance */
        if (amountOwed != 0) {
            return
                fail(
                    Error.NONZERO_BORROW_BALANCE,
                    FailureInfo.EXIT_MARKET_BALANCE_OWED
                );
        }

        /* Fail if the sender is not permitted to redeem all of their tokens */
        uint256 allowed = redeemAllowedInternal(
            vTokenAddress,
            msg.sender,
            tokensHeld
        );
        if (allowed != 0) {
            return
                failOpaque(
                    Error.REJECTION,
                    FailureInfo.EXIT_MARKET_REJECTION,
                    allowed
                );
        }

        Market storage marketToExit = markets[address(vToken)];

        /* Return true if the sender is not already ‘in’ the market */
        if (!marketToExit.accountMembership[msg.sender]) {
            return uint256(Error.NO_ERROR);
        }

        /* Set vToken account membership to false */
        delete marketToExit.accountMembership[msg.sender];

        /* Delete vToken from the account’s list of assets */
        // In order to delete vToken, copy last item in list to location of item to be removed, reduce length by 1
        VToken[] storage userAssetList = accountAssets[msg.sender];
        uint256 len = userAssetList.length;
        uint256 i;
        for (; i < len; i++) {
            if (userAssetList[i] == vToken) {
                userAssetList[i] = userAssetList[len - 1];
                userAssetList.length--;
                break;
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        assert(i < len);

        emit MarketExited(vToken, msg.sender);

        return uint256(Error.NO_ERROR);
    }

    /*** Policy Hooks ***/

    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param vToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function mintAllowed(
        address vToken,
        address minter,
        uint256 mintAmount
    ) external onlyProtocolAllowed returns (uint256) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[vToken], "mint is paused");

        // Shh - currently unused
        mintAmount;

        if (!markets[vToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // Keep the flywheel moving
        updateVenusSupplyIndex(vToken);
        distributeSupplierVenus(vToken, minter, false);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates mint and reverts on rejection. May emit logs.
     * @param vToken Asset being minted
     * @param minter The address minting the tokens
     * @param actualMintAmount The amount of the underlying asset being minted
     * @param mintTokens The number of tokens being minted
     */
    function mintVerify(
        address vToken,
        address minter,
        uint256 actualMintAmount,
        uint256 mintTokens
    ) external {
        // Shh - currently unused
        vToken;
        minter;
        actualMintAmount;
        mintTokens;
    }

    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param vToken The market to verify the redeem against
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of vTokens to exchange for the underlying asset in the market
     * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function redeemAllowed(
        address vToken,
        address redeemer,
        uint256 redeemTokens
    ) external onlyProtocolAllowed returns (uint256) {
        uint256 allowed = redeemAllowedInternal(vToken, redeemer, redeemTokens);
        if (allowed != uint256(Error.NO_ERROR)) {
            return allowed;
        }

        // Keep the flywheel moving
        updateVenusSupplyIndex(vToken);
        distributeSupplierVenus(vToken, redeemer, false);

        return uint256(Error.NO_ERROR);
    }

    function redeemAllowedInternal(
        address vToken,
        address redeemer,
        uint256 redeemTokens
    ) internal view returns (uint256) {
        if (!markets[vToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (!markets[vToken].accountMembership[redeemer]) {
            return uint256(Error.NO_ERROR);
        }

        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        (
            Error err,
            ,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(
                redeemer,
                VToken(vToken),
                redeemTokens,
                0
            );
        if (err != Error.NO_ERROR) {
            return uint256(err);
        }
        if (shortfall > 0) {
            return uint256(Error.INSUFFICIENT_LIQUIDITY);
        }

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates redeem and reverts on rejection. May emit logs.
     * @param vToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function redeemVerify(
        address vToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    ) external {
        // Shh - currently unused
        vToken;
        redeemer;

        // Require tokens is zero or amount is also zero
        require(redeemTokens != 0 || redeemAmount == 0, "redeemTokens zero");
    }

    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param vToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function borrowAllowed(
        address vToken,
        address borrower,
        uint256 borrowAmount
    ) external onlyProtocolAllowed returns (uint256) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!borrowGuardianPaused[vToken], "borrow is paused");

        if (!markets[vToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        if (!markets[vToken].accountMembership[borrower]) {
            // only vTokens may call borrowAllowed if borrower not in market
            require(msg.sender == vToken, "sender must be vToken");

            // attempt to add borrower to the market
            Error err = addToMarketInternal(VToken(vToken), borrower);
            if (err != Error.NO_ERROR) {
                return uint256(err);
            }
        }

        if (oracle.getUnderlyingPrice(VToken(vToken)) == 0) {
            return uint256(Error.PRICE_ERROR);
        }

        (
            Error err,
            ,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(
                borrower,
                VToken(vToken),
                0,
                borrowAmount
            );
        if (err != Error.NO_ERROR) {
            return uint256(err);
        }
        if (shortfall > 0) {
            return uint256(Error.INSUFFICIENT_LIQUIDITY);
        }

        // Keep the flywheel moving
        Exp memory borrowIndex = Exp({mantissa: VToken(vToken).borrowIndex()});
        updateVenusBorrowIndex(vToken, borrowIndex);
        distributeBorrowerVenus(vToken, borrower, borrowIndex, false);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates borrow and reverts on rejection. May emit logs.
     * @param vToken Asset whose underlying is being borrowed
     * @param borrower The address borrowing the underlying
     * @param borrowAmount The amount of the underlying asset requested to borrow
     */
    function borrowVerify(
        address vToken,
        address borrower,
        uint256 borrowAmount
    ) external {
        // Shh - currently unused
        vToken;
        borrower;
        borrowAmount;

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
    }

    /**
     * @notice Checks if the account should be allowed to repay a borrow in the given market
     * @param vToken The market to verify the repay against
     * @param payer The account which would repay the asset
     * @param borrower The account which would borrowed the asset
     * @param repayAmount The amount of the underlying asset the account would repay
     * @return 0 if the repay is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function repayBorrowAllowed(
        address vToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external onlyProtocolAllowed returns (uint256) {
        // Shh - currently unused
        payer;
        borrower;
        repayAmount;

        if (!markets[vToken].isListed) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        // Keep the flywheel moving
        Exp memory borrowIndex = Exp({mantissa: VToken(vToken).borrowIndex()});
        updateVenusBorrowIndex(vToken, borrowIndex);
        distributeBorrowerVenus(vToken, borrower, borrowIndex, false);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates repayBorrow and reverts on rejection. May emit logs.
     * @param vToken Asset being repaid
     * @param payer The address repaying the borrow
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function repayBorrowVerify(
        address vToken,
        address payer,
        address borrower,
        uint256 actualRepayAmount,
        uint256 borrowerIndex
    ) external {
        // Shh - currently unused
        vToken;
        payer;
        borrower;
        actualRepayAmount;
        borrowerIndex;

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
    }

    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param vTokenBorrowed Asset which was borrowed by the borrower
     * @param vTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external onlyProtocolAllowed returns (uint256) {
        // Shh - currently unused
        liquidator;

        if (
            !markets[vTokenBorrowed].isListed ||
            !markets[vTokenCollateral].isListed
        ) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        /* The borrower must have shortfall in order to be liquidatable */
        (Error err, , uint256 shortfall) = getAccountLiquidityInternal(
            borrower
        );
        if (err != Error.NO_ERROR) {
            return uint256(err);
        }
        if (shortfall == 0) {
            return uint256(Error.INSUFFICIENT_SHORTFALL);
        }

        /* The liquidator may not repay more than what is allowed by the closeFactor */
        uint256 borrowBalance = VToken(vTokenBorrowed).borrowBalanceStored(
            borrower
        );
        (MathError mathErr, uint256 maxClose) = mulScalarTruncate(
            Exp({mantissa: closeFactorMantissa}),
            borrowBalance
        );
        if (mathErr != MathError.NO_ERROR) {
            return uint256(Error.MATH_ERROR);
        }
        if (repayAmount > maxClose) {
            return uint256(Error.TOO_MUCH_REPAY);
        }

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates liquidateBorrow and reverts on rejection. May emit logs.
     * @param vTokenBorrowed Asset which was borrowed by the borrower
     * @param vTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function liquidateBorrowVerify(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 actualRepayAmount,
        uint256 seizeTokens
    ) external {
        // Shh - currently unused
        vTokenBorrowed;
        vTokenCollateral;
        liquidator;
        borrower;
        actualRepayAmount;
        seizeTokens;

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
    }

    /**
     * @notice Checks if the seizing of assets should be allowed to occur
     * @param vTokenCollateral Asset which was used as collateral and will be seized
     * @param vTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeAllowed(
        address vTokenCollateral,
        address vTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external onlyProtocolAllowed returns (uint256) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!seizeGuardianPaused, "seize is paused");

        // Shh - currently unused
        seizeTokens;

        if (
            !markets[vTokenCollateral].isListed ||
            !markets[vTokenBorrowed].isListed
        ) {
            return uint256(Error.MARKET_NOT_LISTED);
        }

        if (
            VToken(vTokenCollateral).comptroller() !=
            VToken(vTokenBorrowed).comptroller()
        ) {
            return uint256(Error.COMPTROLLER_MISMATCH);
        }

        // Keep the flywheel moving
        updateVenusSupplyIndex(vTokenCollateral);
        distributeSupplierVenus(vTokenCollateral, borrower, false);
        distributeSupplierVenus(vTokenCollateral, liquidator, false);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates seize and reverts on rejection. May emit logs.
     * @param vTokenCollateral Asset which was used as collateral and will be seized
     * @param vTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeVerify(
        address vTokenCollateral,
        address vTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external {
        // Shh - currently unused
        vTokenCollateral;
        vTokenBorrowed;
        liquidator;
        borrower;
        seizeTokens;

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
    }

    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param vToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of vTokens to transfer
     * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function transferAllowed(
        address vToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external onlyProtocolAllowed returns (uint256) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!transferGuardianPaused, "transfer is paused");

        // Currently the only consideration is whether or not
        //  the src is allowed to redeem this many tokens
        uint256 allowed = redeemAllowedInternal(vToken, src, transferTokens);
        if (allowed != uint256(Error.NO_ERROR)) {
            return allowed;
        }

        // Keep the flywheel moving
        updateVenusSupplyIndex(vToken);
        distributeSupplierVenus(vToken, src, false);
        distributeSupplierVenus(vToken, dst, false);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Validates transfer and reverts on rejection. May emit logs.
     * @param vToken Asset being transferred
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of vTokens to transfer
     */
    function transferVerify(
        address vToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external {
        // Shh - currently unused
        vToken;
        src;
        dst;
        transferTokens;

        // Shh - we don't ever want this hook to be marked pure
        if (false) {
            maxAssets = maxAssets;
        }
    }

    /*** Liquidity/Liquidation Calculations ***/

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `vTokenBalance` is the number of vTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint256 sumCollateral;
        uint256 sumBorrowPlusEffects;
        uint256 vTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRateMantissa;
        uint256 oraclePriceMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (
            Error err,
            uint256 liquidity,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(account, VToken(0), 0, 0);

        return (uint256(err), liquidity, shortfall);
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code,
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidityInternal(address account)
        internal
        view
        returns (
            Error,
            uint256,
            uint256
        )
    {
        return
            getHypotheticalAccountLiquidityInternal(account, VToken(0), 0, 0);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param vTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidity(
        address account,
        address vTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (
            Error err,
            uint256 liquidity,
            uint256 shortfall
        ) = getHypotheticalAccountLiquidityInternal(
                account,
                VToken(vTokenModify),
                redeemTokens,
                borrowAmount
            );
        return (uint256(err), liquidity, shortfall);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param vTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @dev Note that we calculate the exchangeRateStored for each collateral vToken using stored data,
     *  without calculating accumulated interest.
     * @return (possible error code,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        VToken vTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    )
        internal
        view
        returns (
            Error,
            uint256,
            uint256
        )
    {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        uint256 oErr;
        MathError mErr;

        // For each asset the account is in
        VToken[] memory assets = accountAssets[account];
        for (uint256 i = 0; i < assets.length; i++) {
            VToken asset = assets[i];

            // Read the balances and exchange rate from the vToken
            (
                oErr,
                vars.vTokenBalance,
                vars.borrowBalance,
                vars.exchangeRateMantissa
            ) = asset.getAccountSnapshot(account);
            if (oErr != 0) {
                // semi-opaque error code, we assume NO_ERROR == 0 is invariant between upgrades
                return (Error.SNAPSHOT_ERROR, 0, 0);
            }
            vars.collateralFactor = Exp({
                mantissa: markets[address(asset)].collateralFactorMantissa
            });
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> bnb (normalized price value)
            (mErr, vars.tokensToDenom) = mulExp3(
                vars.collateralFactor,
                vars.exchangeRate,
                vars.oraclePrice
            );
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // sumCollateral += tokensToDenom * vTokenBalance
            (mErr, vars.sumCollateral) = mulScalarTruncateAddUInt(
                vars.tokensToDenom,
                vars.vTokenBalance,
                vars.sumCollateral
            );
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(
                vars.oraclePrice,
                vars.borrowBalance,
                vars.sumBorrowPlusEffects
            );
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // Calculate effects of interacting with vTokenModify
            if (asset == vTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(
                    vars.tokensToDenom,
                    redeemTokens,
                    vars.sumBorrowPlusEffects
                );
                if (mErr != MathError.NO_ERROR) {
                    return (Error.MATH_ERROR, 0, 0);
                }

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(
                    vars.oraclePrice,
                    borrowAmount,
                    vars.sumBorrowPlusEffects
                );
                if (mErr != MathError.NO_ERROR) {
                    return (Error.MATH_ERROR, 0, 0);
                }
            }
        }

        /// @dev VAI Integration^
        (mErr, vars.sumBorrowPlusEffects) = addUInt(
            vars.sumBorrowPlusEffects,
            mintedVAIs[account]
        );
        if (mErr != MathError.NO_ERROR) {
            return (Error.MATH_ERROR, 0, 0);
        }
        /// @dev VAI Integration$

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (
                Error.NO_ERROR,
                vars.sumCollateral - vars.sumBorrowPlusEffects,
                0
            );
        } else {
            return (
                Error.NO_ERROR,
                0,
                vars.sumBorrowPlusEffects - vars.sumCollateral
            );
        }
    }

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in vToken.liquidateBorrowFresh)
     * @param vTokenBorrowed The address of the borrowed vToken
     * @param vTokenCollateral The address of the collateral vToken
     * @param actualRepayAmount The amount of vTokenBorrowed underlying to convert into vTokenCollateral tokens
     * @return (errorCode, number of vTokenCollateral tokens to be seized in a liquidation)
     */
    function liquidateCalculateSeizeTokens(
        address vTokenBorrowed,
        address vTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256, uint256) {
        /* Read oracle prices for borrowed and collateral markets */
        uint256 priceBorrowedMantissa = oracle.getUnderlyingPrice(
            VToken(vTokenBorrowed)
        );
        uint256 priceCollateralMantissa = oracle.getUnderlyingPrice(
            VToken(vTokenCollateral)
        );
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            return (uint256(Error.PRICE_ERROR), 0);
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint256 exchangeRateMantissa = VToken(vTokenCollateral)
            .exchangeRateStored(); // Note: reverts on error
        uint256 seizeTokens;
        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;
        MathError mathErr;

        (mathErr, numerator) = mulExp(
            liquidationIncentiveMantissa,
            priceBorrowedMantissa
        );
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        (mathErr, denominator) = mulExp(
            priceCollateralMantissa,
            exchangeRateMantissa
        );
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        (mathErr, ratio) = divExp(numerator, denominator);
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        (mathErr, seizeTokens) = mulScalarTruncate(ratio, actualRepayAmount);
        if (mathErr != MathError.NO_ERROR) {
            return (uint256(Error.MATH_ERROR), 0);
        }

        return (uint256(Error.NO_ERROR), seizeTokens);
    }

    /*** Admin Functions ***/

    /**
     * @notice Sets a new price oracle for the comptroller
     * @dev Admin function to set a new price oracle
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setPriceOracle(PriceOracle newOracle) public returns (uint256) {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_PRICE_ORACLE_OWNER_CHECK
                );
        }

        // Track the old oracle for the comptroller
        PriceOracle oldOracle = oracle;

        // Set comptroller's oracle to newOracle
        oracle = newOracle;

        // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewPriceOracle(oldOracle, newOracle);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets the closeFactor used when liquidating borrows
     * @dev Admin function to set closeFactor
     * @param newCloseFactorMantissa New close factor, scaled by 1e18
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setCloseFactor(uint256 newCloseFactorMantissa)
        external
        returns (uint256)
    {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_CLOSE_FACTOR_OWNER_CHECK
                );
        }

        Exp memory newCloseFactorExp = Exp({mantissa: newCloseFactorMantissa});
        Exp memory lowLimit = Exp({mantissa: closeFactorMinMantissa});
        if (lessThanOrEqualExp(newCloseFactorExp, lowLimit)) {
            return
                fail(
                    Error.INVALID_CLOSE_FACTOR,
                    FailureInfo.SET_CLOSE_FACTOR_VALIDATION
                );
        }

        Exp memory highLimit = Exp({mantissa: closeFactorMaxMantissa});
        if (lessThanExp(highLimit, newCloseFactorExp)) {
            return
                fail(
                    Error.INVALID_CLOSE_FACTOR,
                    FailureInfo.SET_CLOSE_FACTOR_VALIDATION
                );
        }

        uint256 oldCloseFactorMantissa = closeFactorMantissa;
        closeFactorMantissa = newCloseFactorMantissa;
        emit NewCloseFactor(oldCloseFactorMantissa, closeFactorMantissa);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets the collateralFactor for a market
     * @dev Admin function to set per-market collateralFactor
     * @param vToken The market to set the factor on
     * @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setCollateralFactor(
        VToken vToken,
        uint256 newCollateralFactorMantissa
    ) external returns (uint256) {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_COLLATERAL_FACTOR_OWNER_CHECK
                );
        }

        // Verify market is listed
        Market storage market = markets[address(vToken)];
        if (!market.isListed) {
            return
                fail(
                    Error.MARKET_NOT_LISTED,
                    FailureInfo.SET_COLLATERAL_FACTOR_NO_EXISTS
                );
        }

        Exp memory newCollateralFactorExp = Exp({
            mantissa: newCollateralFactorMantissa
        });

        // Check collateral factor <= 0.9
        Exp memory highLimit = Exp({mantissa: collateralFactorMaxMantissa});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return
                fail(
                    Error.INVALID_COLLATERAL_FACTOR,
                    FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION
                );
        }

        // If collateral factor != 0, fail if price == 0
        if (
            newCollateralFactorMantissa != 0 &&
            oracle.getUnderlyingPrice(vToken) == 0
        ) {
            return
                fail(
                    Error.PRICE_ERROR,
                    FailureInfo.SET_COLLATERAL_FACTOR_WITHOUT_PRICE
                );
        }

        // Set market's collateral factor to new collateral factor, remember old value
        uint256 oldCollateralFactorMantissa = market.collateralFactorMantissa;
        market.collateralFactorMantissa = newCollateralFactorMantissa;

        // Emit event with asset, old collateral factor, and new collateral factor
        emit NewCollateralFactor(
            vToken,
            oldCollateralFactorMantissa,
            newCollateralFactorMantissa
        );

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets maxAssets which controls how many markets can be entered
     * @dev Admin function to set maxAssets
     * @param newMaxAssets New max assets
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setMaxAssets(uint256 newMaxAssets) external returns (uint256) {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_MAX_ASSETS_OWNER_CHECK
                );
        }

        uint256 oldMaxAssets = maxAssets;
        maxAssets = newMaxAssets;
        emit NewMaxAssets(oldMaxAssets, newMaxAssets);

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Sets liquidationIncentive
     * @dev Admin function to set liquidationIncentive
     * @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
     * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
     */
    function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa)
        external
        returns (uint256)
    {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_LIQUIDATION_INCENTIVE_OWNER_CHECK
                );
        }

        // Check de-scaled min <= newLiquidationIncentive <= max
        Exp memory newLiquidationIncentive = Exp({
            mantissa: newLiquidationIncentiveMantissa
        });
        Exp memory minLiquidationIncentive = Exp({
            mantissa: liquidationIncentiveMinMantissa
        });
        if (lessThanExp(newLiquidationIncentive, minLiquidationIncentive)) {
            return
                fail(
                    Error.INVALID_LIQUIDATION_INCENTIVE,
                    FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION
                );
        }

        Exp memory maxLiquidationIncentive = Exp({
            mantissa: liquidationIncentiveMaxMantissa
        });
        if (lessThanExp(maxLiquidationIncentive, newLiquidationIncentive)) {
            return
                fail(
                    Error.INVALID_LIQUIDATION_INCENTIVE,
                    FailureInfo.SET_LIQUIDATION_INCENTIVE_VALIDATION
                );
        }

        // Save current value for use in log
        uint256 oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;

        // Set liquidation incentive to new incentive
        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(
            oldLiquidationIncentiveMantissa,
            newLiquidationIncentiveMantissa
        );

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Add the market to the markets mapping and set it as listed
     * @dev Admin function to set isListed and add support for the market
     * @param vToken The address of the market (token) to list
     * @return uint 0=success, otherwise a failure. (See enum Error for details)
     */
    function _supportMarket(VToken vToken) external returns (uint256) {
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SUPPORT_MARKET_OWNER_CHECK
                );
        }

        if (markets[address(vToken)].isListed) {
            return
                fail(
                    Error.MARKET_ALREADY_LISTED,
                    FailureInfo.SUPPORT_MARKET_EXISTS
                );
        }

        vToken.isVToken(); // Sanity check to make sure its really a VToken

        markets[address(vToken)] = Market({
            isListed: true,
            isVenus: false,
            collateralFactorMantissa: 0
        });

        _addMarketInternal(address(vToken));

        emit MarketListed(vToken);

        return uint256(Error.NO_ERROR);
    }

    function _addMarketInternal(address vToken) internal {
        for (uint256 i = 0; i < allMarkets.length; i++) {
            require(allMarkets[i] != VToken(vToken), "market already added");
        }
        allMarkets.push(VToken(vToken));
    }

    /**
     * @notice Admin function to change the Pause Guardian
     * @param newPauseGuardian The address of the new Pause Guardian
     * @return uint 0=success, otherwise a failure. (See enum Error for details)
     */
    function _setPauseGuardian(address newPauseGuardian)
        public
        returns (uint256)
    {
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_PAUSE_GUARDIAN_OWNER_CHECK
                );
        }

        // Save current value for inclusion in log
        address oldPauseGuardian = pauseGuardian;

        // Store pauseGuardian with value newPauseGuardian
        pauseGuardian = newPauseGuardian;

        // Emit NewPauseGuardian(OldPauseGuardian, NewPauseGuardian)
        emit NewPauseGuardian(oldPauseGuardian, pauseGuardian);

        return uint256(Error.NO_ERROR);
    }

    function _setVAIMintRate(uint256 newVAIMintRate)
        external
        returns (uint256)
    {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(Error.UNAUTHORIZED, FailureInfo.SET_VAI_MINT_RATE_CHECK);
        }

        uint256 oldVAIMintRate = vaiMintRate;
        vaiMintRate = newVAIMintRate;
        emit NewVAIMintRate(oldVAIMintRate, newVAIMintRate);

        return uint256(Error.NO_ERROR);
    }

    function _become(Unitroller unitroller) public {
        require(msg.sender == unitroller.admin(), "only unitroller admin can");
        require(unitroller._acceptImplementation() == 0, "not authorized");
    }

    /*** Venus Distribution ***/

    /**
     * @notice Recalculate and update Venus speeds for all Venus markets
     */
    function refreshVenusSpeeds() public {
        require(msg.sender == tx.origin, "only externally owned accounts can");
        refreshVenusSpeedsInternal();
    }

    function refreshVenusSpeedsInternal() internal {
        uint256 i;
        VToken vToken;
        for (i = 0; i < allMarkets.length; i++) {
            vToken = allMarkets[i];
            Exp memory borrowIndex = Exp({mantissa: vToken.borrowIndex()});
            updateVenusSupplyIndex(address(vToken));
            updateVenusBorrowIndex(address(vToken), borrowIndex);
        }

        Exp memory totalUtility = Exp({mantissa: 0});
        Exp[] memory utilities = new Exp[](allMarkets.length);
        for (i = 0; i < allMarkets.length; i++) {
            vToken = allMarkets[i];
            if (markets[address(vToken)].isVenus) {
                Exp memory assetPrice = Exp({
                    mantissa: oracle.getUnderlyingPrice(vToken)
                });
                Exp memory utility = mul_(assetPrice, vToken.totalBorrows());
                utilities[i] = utility;
                totalUtility = add_(totalUtility, utility);
            }
        }

        for (i = 0; i < allMarkets.length; i++) {
            vToken = allMarkets[i];
            uint256 newSpeed = totalUtility.mantissa > 0
                ? mul_(venusRate, div_(utilities[i], totalUtility))
                : 0;
            venusSpeeds[address(vToken)] = newSpeed;
            emit VenusSpeedUpdated(vToken, newSpeed);
        }
    }

    /**
     * @notice Accrue XVS to the market by updating the supply index
     * @param vToken The market whose supply index to update
     */
    function updateVenusSupplyIndex(address vToken) internal {
        VenusMarketState storage supplyState = venusSupplyState[vToken];
        uint256 supplySpeed = venusSpeeds[vToken];
        uint256 blockNumber = getBlockNumber();
        uint256 deltaBlocks = sub_(blockNumber, uint256(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint256 supplyTokens = VToken(vToken).totalSupply();
            uint256 venusAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0
                ? fraction(venusAccrued, supplyTokens)
                : Double({mantissa: 0});
            Double memory index = add_(
                Double({mantissa: supplyState.index}),
                ratio
            );
            venusSupplyState[vToken] = VenusMarketState({
                index: safe224(index.mantissa, "new index overflows"),
                block: safe32(blockNumber, "block number overflows")
            });
        } else if (deltaBlocks > 0) {
            supplyState.block = safe32(blockNumber, "block number overflows");
        }
    }

    /**
     * @notice Accrue XVS to the market by updating the borrow index
     * @param vToken The market whose borrow index to update
     */
    function updateVenusBorrowIndex(
        address vToken,
        Exp memory marketBorrowIndex
    ) internal {
        VenusMarketState storage borrowState = venusBorrowState[vToken];
        uint256 borrowSpeed = venusSpeeds[vToken];
        uint256 blockNumber = getBlockNumber();
        uint256 deltaBlocks = sub_(blockNumber, uint256(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint256 borrowAmount = div_(
                VToken(vToken).totalBorrows(),
                marketBorrowIndex
            );
            uint256 venusAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0
                ? fraction(venusAccrued, borrowAmount)
                : Double({mantissa: 0});
            Double memory index = add_(
                Double({mantissa: borrowState.index}),
                ratio
            );
            venusBorrowState[vToken] = VenusMarketState({
                index: safe224(index.mantissa, "new index overflows"),
                block: safe32(blockNumber, "block number overflows")
            });
        } else if (deltaBlocks > 0) {
            borrowState.block = safe32(blockNumber, "block number overflows");
        }
    }

    /**
     * @notice Calculate XVS accrued by a supplier and possibly transfer it to them
     * @param vToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute XVS to
     */
    function distributeSupplierVenus(
        address vToken,
        address supplier,
        bool distributeAll
    ) internal {
        VenusMarketState storage supplyState = venusSupplyState[vToken];
        Double memory supplyIndex = Double({mantissa: supplyState.index});
        Double memory supplierIndex = Double({
            mantissa: venusSupplierIndex[vToken][supplier]
        });
        venusSupplierIndex[vToken][supplier] = supplyIndex.mantissa;

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = venusInitialIndex;
        }

        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint256 supplierTokens = VToken(vToken).balanceOf(supplier);
        uint256 supplierDelta = mul_(supplierTokens, deltaIndex);
        uint256 supplierAccrued = add_(venusAccrued[supplier], supplierDelta);
        venusAccrued[supplier] = transferXVS(
            supplier,
            supplierAccrued,
            distributeAll ? 0 : venusClaimThreshold
        );
        emit DistributedSupplierVenus(
            VToken(vToken),
            supplier,
            supplierDelta,
            supplyIndex.mantissa
        );
    }

    /**
     * @notice Calculate XVS accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param vToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute XVS to
     */
    function distributeBorrowerVenus(
        address vToken,
        address borrower,
        Exp memory marketBorrowIndex,
        bool distributeAll
    ) internal {
        VenusMarketState storage borrowState = venusBorrowState[vToken];
        Double memory borrowIndex = Double({mantissa: borrowState.index});
        Double memory borrowerIndex = Double({
            mantissa: venusBorrowerIndex[vToken][borrower]
        });
        venusBorrowerIndex[vToken][borrower] = borrowIndex.mantissa;

        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint256 borrowerAmount = div_(
                VToken(vToken).borrowBalanceStored(borrower),
                marketBorrowIndex
            );
            uint256 borrowerDelta = mul_(borrowerAmount, deltaIndex);
            uint256 borrowerAccrued = add_(
                venusAccrued[borrower],
                borrowerDelta
            );
            venusAccrued[borrower] = transferXVS(
                borrower,
                borrowerAccrued,
                distributeAll ? 0 : venusClaimThreshold
            );
            emit DistributedBorrowerVenus(
                VToken(vToken),
                borrower,
                borrowerDelta,
                borrowIndex.mantissa
            );
        }
    }

    /**
     * @notice Transfer XVS to the user, if they are above the threshold
     * @dev Note: If there is not enough XVS, we do not perform the transfer all.
     * @param user The address of the user to transfer XVS to
     * @param userAccrued The amount of XVS to (possibly) transfer
     * @return The amount of XVS which was NOT transferred to the user
     */
    function transferXVS(
        address user,
        uint256 userAccrued,
        uint256 threshold
    ) internal returns (uint256) {
        if (userAccrued >= threshold && userAccrued > 0) {
            XVS xvs = XVS(getXVSAddress());
            uint256 xvsRemaining = xvs.balanceOf(address(this));
            if (userAccrued <= xvsRemaining) {
                xvs.transfer(user, userAccrued);
                return 0;
            }
        }
        return userAccrued;
    }

    /**
     * @notice Claim all the xvs accrued by holder in all markets
     * @param holder The address to claim XVS for
     */
    function claimVenus(address holder) public {
        return claimVenus(holder, allMarkets);
    }

    /**
     * @notice Claim all the xvs accrued by holder in the specified markets
     * @param holder The address to claim XVS for
     * @param vTokens The list of markets to claim XVS in
     */
    function claimVenus(address holder, VToken[] memory vTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimVenus(holders, vTokens, true, true);
    }

    /**
     * @notice Claim all xvs accrued by the holders
     * @param holders The addresses to claim XVS for
     * @param vTokens The list of markets to claim XVS in
     * @param borrowers Whether or not to claim XVS earned by borrowing
     * @param suppliers Whether or not to claim XVS earned by supplying
     */
    function claimVenus(
        address[] memory holders,
        VToken[] memory vTokens,
        bool borrowers,
        bool suppliers
    ) public {
        uint256 j;
        for (uint256 i = 0; i < vTokens.length; i++) {
            VToken vToken = vTokens[i];
            require(markets[address(vToken)].isListed, "not listed market");
            if (borrowers == true) {
                Exp memory borrowIndex = Exp({mantissa: vToken.borrowIndex()});
                updateVenusBorrowIndex(address(vToken), borrowIndex);
                for (j = 0; j < holders.length; j++) {
                    distributeBorrowerVenus(
                        address(vToken),
                        holders[j],
                        borrowIndex,
                        true
                    );
                }
            }
            if (suppliers == true) {
                updateVenusSupplyIndex(address(vToken));
                for (j = 0; j < holders.length; j++) {
                    distributeSupplierVenus(address(vToken), holders[j], true);
                }
            }
        }
    }

    /*** Venus Distribution Admin ***/

    /**
     * @notice Set the amount of XVS distributed per block
     * @param venusRate_ The amount of XVS wei per block to distribute
     */
    function _setVenusRate(uint256 venusRate_) public {
        require(msg.sender == admin, "only admin can");

        uint256 oldRate = venusRate;
        venusRate = venusRate_;
        emit NewVenusRate(oldRate, venusRate_);

        refreshVenusSpeedsInternal();
    }

    /**
     * @notice Add markets to venusMarkets, allowing them to earn XVS in the flywheel
     * @param vTokens The addresses of the markets to add
     */
    function _addVenusMarkets(address[] memory vTokens) public {
        require(msg.sender == admin, "only admin can");

        for (uint256 i = 0; i < vTokens.length; i++) {
            _addVenusMarketInternal(vTokens[i]);
        }

        refreshVenusSpeedsInternal();
    }

    function _addVenusMarketInternal(address vToken) internal {
        Market storage market = markets[vToken];
        require(market.isListed == true, "venus market is not listed");
        require(market.isVenus == false, "venus market already added");

        market.isVenus = true;
        emit MarketVenus(VToken(vToken), true);

        if (
            venusSupplyState[vToken].index == 0 &&
            venusSupplyState[vToken].block == 0
        ) {
            venusSupplyState[vToken] = VenusMarketState({
                index: venusInitialIndex,
                block: safe32(getBlockNumber(), "block number overflows")
            });
        }

        if (
            venusBorrowState[vToken].index == 0 &&
            venusBorrowState[vToken].block == 0
        ) {
            venusBorrowState[vToken] = VenusMarketState({
                index: venusInitialIndex,
                block: safe32(getBlockNumber(), "block number overflows")
            });
        }
    }

    /**
     * @notice Remove a market from venusMarkets, preventing it from earning XVS in the flywheel
     * @param vToken The address of the market to drop
     */
    function _dropVenusMarket(address vToken) public {
        require(msg.sender == admin, "only admin can");

        Market storage market = markets[vToken];
        require(market.isVenus == true, "not venus market");

        market.isVenus = false;
        emit MarketVenus(VToken(vToken), false);

        refreshVenusSpeedsInternal();
    }

    /**
     * @notice Return all of the markets
     * @dev The automatic getter may be used to access an individual market.
     * @return The list of market addresses
     */
    function getAllMarkets() public view returns (VToken[] memory) {
        return allMarkets;
    }

    function getBlockNumber() public view returns (uint256) {
        return block.number;
    }

    /**
     * @notice Return the address of the XVS token
     * @return The address of XVS
     */
    function getXVSAddress() public view returns (address) {
        return 0xB9e0E753630434d7863528cc73CB7AC638a7c8ff;
    }

    /**
     * @notice Sets a new VAI controller
     * @dev Admin function to set a new VAI controller
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setVAIController(VAIControllerInterface vaiController_)
        public
        returns (uint256)
    {
        // Check caller is admin
        if (msg.sender != admin) {
            return
                fail(
                    Error.UNAUTHORIZED,
                    FailureInfo.SET_VAICONTROLLER_OWNER_CHECK
                );
        }

        VAIControllerInterface oldRate = vaiController;
        vaiController = vaiController_;
        emit NewVAIController(oldRate, vaiController_);
    }

    /**
     * @notice Get the minted VAI amount of the `owner`
     * @param owner The address of the account to query
     * @return The number of minted VAI by `owner`
     */
    function mintedVAIOf(address owner) external view returns (uint256) {
        return mintedVAIs[owner];
    }

    /**
     * @notice Set the minted VAI amount of the `owner`
     * @param owner The address of the account to set
     * @param amount The amount of VAI to set to the account
     * @return The number of minted VAI by `owner`
     */
    function setMintedVAIOf(address owner, uint256 amount)
        external
        onlyProtocolAllowed
        returns (uint256)
    {
        // Check caller is vaiController
        if (msg.sender != address(vaiController)) {
            return fail(Error.REJECTION, FailureInfo.SET_MINTED_VAI_REJECTION);
        }
        mintedVAIs[owner] = amount;

        return uint256(Error.NO_ERROR);
    }

    /**
     * @notice Get Mintable VAI amount
     */
    function getMintableVAI(address minter)
        public
        view
        returns (uint256, uint256)
    {
        return vaiController.getMintableVAI(minter);
    }

    /**
     * @notice Mint VAI
     */
    function mintVAI(uint256 mintVAIAmount)
        external
        onlyProtocolAllowed
        returns (uint256)
    {
        return vaiController.mintVAI(msg.sender, mintVAIAmount);
    }

    /**
     * @notice Repay VAI
     */
    function repayVAI(uint256 repayVAIAmount)
        external
        onlyProtocolAllowed
        returns (uint256)
    {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!repayVAIGuardianPaused, "repayVAI is paused");
        return vaiController.repayVAI(msg.sender, repayVAIAmount);
    }

    /**
     * @notice Get the VAI Mint Rate
     */
    function getVAIMintRate() external view returns (uint256) {
        return vaiMintRate;
    }

    /**
     * @notice Set whole protocol pause/unpause state
     */
    function _setProtocolPaused(bool state) public returns (bool) {
        require(msg.sender == admin, "only admin can");

        protocolPaused = state;
        emit ActionProtocolPaused(state);
        return state;
    }
}
