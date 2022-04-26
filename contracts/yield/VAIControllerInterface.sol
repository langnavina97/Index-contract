// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.5.16;

contract VAIControllerInterface {
    function getMintableVAI(address minter)
        public
        view
        returns (uint256, uint256);

    function mintVAI(address minter, uint256 mintVAIAmount)
        external
        returns (uint256);

    function repayVAI(address repayer, uint256 repayVAIAmount)
        external
        returns (uint256);
}
