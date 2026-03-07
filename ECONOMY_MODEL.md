# Economy Model

The economy is designed for a single-world market.

- direct faucets and sinks live in `scripts/economy_system.lua`
- trading and safeguards live in `scripts/trading_system.lua`
- auction listing and price history live in `scripts/auction_house.lua`
- market visibility is exposed through `world:getEconomyReport()`

Stability controls:

- suspicious flow detection
- sink pressure tracking
- price signal history
- audit events for trades and shop actions
- player-driven pricing through auction listings
