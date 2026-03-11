# Canon Lock

The autonomous loop is allowed to optimize around canon. It is not allowed to normalize canon away.

Canon locks preserve the parts of MapleWorld that define route memory, reward identity, and early-loop feel. These locks prevent the loop from improving metrics by deleting distinctive assets or replacing them with generic equivalents.

The current lock source is:

- `data/canon/locked_assets.json`

## Locked Asset Categories

`regions`

- Route anchors and leveling identities that must remain recognizable.
- These cannot be erased, merged into anonymous bands, or renamed into generic placeholders.

`bosses`

- Canon miniboss and boss anchors that preserve route memory and reward anticipation.
- These cannot be flattened into undifferentiated encounter buckets.

`rewards`

- Rare and milestone reward structures that preserve memorable acquisition moments.
- These cannot be normalized into generic tokens or smooth reward sludge.

`early_loop_segments`

- Named onboarding textures such as introductory hunting, potion sustain, route onboarding, and first-job setup.
- These cannot disappear from the early loop in pursuit of cleaner pacing.

## Reference Schema

Example JSON structure:

```json
{
  "regions": ["henesys", "lith_harbor"],
  "bosses": ["mano", "stumpy"],
  "rewards": ["route_cache", "boss_writ"],
  "early_loop_segments": ["introductory hunting", "potion sustain"]
}
```

## Enforcement Rule

If a locked region, boss, reward, or early-loop segment disappears or is normalized away, the patch must be rejected regardless of stability gains.
