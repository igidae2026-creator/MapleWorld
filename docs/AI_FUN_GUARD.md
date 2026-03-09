# AI Fun Guard

Proxy optimization is useful for keeping the offline loop deterministic, but it can also damage gameplay feel. A system that only chases `combat_quality`, `economy_stability`, or `overall_quality_estimate` can converge toward smoother, safer, and more uniform content while quietly removing the uneven edges that make MapleLand-style progression memorable.

Stability and fun are not the same thing.

- Stability asks whether the loop avoids collapse, deadlocks, runaway inflation, or broken pacing.
- Fun asks whether different maps, rewards, risks, and route choices still feel distinct enough to create stories, preference, and surprise.

The fun guard exists to preserve variance instead of flattening it away.

Variance preservation means the autonomous loop must keep:

- uneven but readable regional identities
- reward spikes that players remember
- multiple route types instead of one universally best route
- early-game texture that feels like a journey instead of a proxy treadmill

The offline fun guard uses coarse range metrics. These are not direct player-truth measurements, but they are designed to catch destructive normalization before it lands.

## Guard Metrics

`distinctiveness`

- Measures whether regions and route loops still differ in identity, emphasis, and progression feel.
- Fails when the loop smooths regions into near-interchangeable content bands.

`variance_health`

- Measures whether drop-rate spread, rarity layering, and early progression gradient still contain useful variance.
- Fails when tables collapse toward uniform efficiency.

`memorable_rewards`

- Measures whether rare, elite, boss, and milestone rewards still produce standout moments.
- Fails when reward structure becomes too flat or too predictable.

`map_role_separation`

- Measures whether different maps or regions still support different dominant play roles.
- Fails when safe, alternative, and risky routes collapse into the same efficiency shape.

`early_loop_texture`

- Measures whether the 1 to 30 experience still contains recognizable early-game beats and route transitions.
- Fails when onboarding becomes mechanically stable but emotionally featureless.

## Guard Principle

If a proposed patch improves stability while reducing gameplay texture, the patch must be rejected.
