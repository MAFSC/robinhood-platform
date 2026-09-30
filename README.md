# Ad Exchange on Blockchain

Decentralized advertising exchange on Robinhood Chain (Arbitrum L2) where advertisers pay viewers for watching ads.

## Deployed Contracts (Robinhood Chain Testnet, Chain ID: 46630)

| Contract | Address |
|----------|---------|
| AdExchangeToken (axUSDG) | `0x6400f658357751ab22B9Bb3C1101532C91cfCb94` |
| MockStreamFlow | `0xbEeFed3671D12250cF77765203f52E0FCD1aB1F6` |
| AdvertiserRegistry | `0x493A40368E6B6E95479ef07f1a6bD70EB65216A8` |
| AdExchangeManager | `0x99856EA3b8b31cF4dA170ca05F48D6468C8E3e1e` |

## How it works

1. Advertiser creates a campaign with budget, tier1/tier2 rates, and viewer limit.
2. Viewer joins the campaign and starts watching.
3. Rewards accrue per second based on tier rate.
4. Viewer withdraws rewards anytime.

## Setup

    git clone git@github.com:MAFSC/robinhood-platform.git
    cd robinhood-platform

    curl -L https://foundry.paradigm.xyz | bash
    foundryup

    forge install foundry-rs/forge-std
    forge install OpenZeppelin/openzeppelin-contracts
    forge install PaulRBerg/prb-math
    forge install sablier-labs/flow
    forge install sablier-labs/evm-utils

    forge build

## Deploy

    cp .env.example .env
    # Edit .env with your PRIVATE_KEY

    forge script script/DeployAdExchange.s.sol:DeployAdExchange \
      --rpc-url https://rpc.testnet.chain.robinhood.com \
      --broadcast

## Frontend

See `docs/index.html`.
