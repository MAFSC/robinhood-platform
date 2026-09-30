# Ad Exchange on Blockchain

Decentralized advertising exchange on Robinhood Chain (Arbitrum L2) where advertisers pay viewers for watching ads.

## Deployed Contracts (Robinhood Chain Testnet, Chain ID: 46630)

| Contract | Address |
|----------|---------|
| AdExchangeToken (axUSDG) | `0xceC312921CaaaBa9b8091F1eb18FeedC529Fe9EC` |
| MockStreamFlow | `0x9b4e9f5A3E4aC4877CA3C77C14a16884C75D98a7` |
| AdvertiserRegistry | `0x614A438473815A077AA3809Ab8ed035280Cd0675` |
| AdExchangeManager | `0xa8d30976b3084Ad559C6C53CC3c3E608013Ee1f7` |

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
