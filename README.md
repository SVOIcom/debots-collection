# debots-collection
This is repository with debots, developed for the second stage of DEX contest.

# Introduction
![photo_2020-12-15_20-21-41](https://user-images.githubusercontent.com/18599919/111032509-ac9fbd80-841d-11eb-9639-843ef2d758b3.jpg)
Hello there! \
SVOI dev team greets you and would like to present the results of created Decentralized Exchange for the FreeTON Community contest: \
#23 FreeTon DEX Implementation Stage 2 Contest.

Goal of this work is to create Decentralized Exchange based on Liquidity Pool mechanism and develop instruments, such as 
debot and [site](https://tonswap.com) for interacting with developed smart contracts.
 
# Links
[![Channel on Telegram](https://img.shields.io/badge/-TON%20Swap%20TG%20chat-blue)](https://t.me/tonswap) 

Repository for smart contracts compilation and deployment - [https://github.com/SVOIcom/ton-testing-suite](https://github.com/SVOIcom/ton-testing-suite)

Used ton-solidity compiler - [solidity compiler v0.39.0](https://github.com/broxus/TON-Solidity-Compiler/tree/98892ddbd2817784857b54436d75b64a3fdf6eb1)

Used tvm-linker - [latest tvm linker](https://github.com/tonlabs/TVM-linker)

# Debots description

## SwapPairExplorer

This debot is developed to provide explorer functionality:
1. Explore existing swap pairs, created at specified Swap Pair Root contract;
2. Check swap pairs pool volumes, and some details;
3. Create new swap pairs;

Interactions with this debot require user to have Multisig wallet or to provide TONs\
to swap pair root contract in advance. Currently other wallets are not supported (i.e. Surf).

## TonSwapDebot

This debot is used to perform swap operations for given swap pair.

This smart contract supports TIP-3 wallets that are controlled with \
Multisig wallet or with keypair.

## TonLiquidityDebot

This debot is used to perform liquidity providing opertaions via two tokens.

This smart contract supports TIP-3 wallets that are controlled with \
Multisig wallet or with keypair.

## TonLiquidityOneDebot

This debot is used to perform liquidity providing operations via one token.

This smart contract supports TIP-3 wallets that are controlled with \
Multisig wallet or with keypair.

## TonLiquidityWithdrawingDebot

This debot is used to perform liquidity withdrawing operations via two tokens.

This smart contract supports TIP-3 wallets that are controlled with \
Multisig wallet or with keypair.

## TonLiquidityWithdrawingOneDebot

This debot is used to perform liquidity withdrawing operations via one token.

This smart contract supports TIP-3 wallets that are controlled with \
Multisig wallet or with keypair.

# Debot devnet addresses

1. SwapPairExplorer: ```0:20ca87d76e89e036aa58a809f80f85af92b030bab7e106341eb1343c1dffbcfa```
2. TonSwapDebot: ```0:9fc27ee8c29378a3a448a7ec8678c4139ea2ae474235de539537765a6e98f00e```
3. TonLiquidityDebot: ```0:d33edbb6564bc82a2450b5f72cc33af0fee4c3a830491f4df2b278f4e1934e9a```
4. TonLiquidityOneDebot: ```0:a98acd66dcc328e2f20c53cd25d0d8c6f0d8458ee556bf609e9b8617df4d9f07```
5. TonLiquidityWithdrawingDebot: ```0:342054fa708cd5f63e3634999fff46177bfb9e85f9aa28eb5fbcfa9c8113a82b```
6. TonLiquidityWithdrawingOneDebot: ```0:928c63b6a2e34b12f1bbcc2d9e8b4e275b64f99f75ea8fe3f471feae3200a9b2```
