# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2022-08-25
- Initial Uniswap V2 like implementation. 
- Support:
    - Create pool.
    - Swapping assets.
    - Adding or removing liqudity.

## [0.1.2] - 2022-08-25
- Changing creating pool without deposit any coin.
- Add freeze operation to the pool so that user could not swap or adding liqudity to the pool.

## [0.1.3] - 2022-08-26
- Adding pool index to the pool struct

## [0.1.3] - 2022-08-27
- Add slippage control.

## [0.1.5] - 2022-09-03
- Upgrade the dependency aptos core to branch `@e6e2f9f7`

## [0.1.6] - 2022-09-18
- Upgrade the dependency aptos core to newest devnet branch.
- Split the test and the implementations.
- Refactor and remove sending the pool account address each entrypoints in the smart contract. All the pools are now located in the package address.

## [0.2.0] - 2022-10-09
- Add pool_type for future implementation
- Add fee_direction to only collect admin fee for one direction
- Add incentive_fee, connect_fee and withdraw_fee
- Add total_trade_x and total_trade_y for statistics
- Add `K / lsp_supply` for computing APY in the frontend
- Add snapshot event for capturing price on chain
- Change fee structrue from upcast to downcast
- Refactor test
- Modify publish script

## [0.2.1] - 2022-10-10
- Bug fix for weekly sma computation
- Add `bank` structure for storing the coin for admin and emit events for deposit and withdraw