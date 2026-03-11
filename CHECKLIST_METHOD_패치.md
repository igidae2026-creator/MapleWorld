# Checklist Method - 패치

MapleWorld governance patches must follow this order.

## Patch Order

1. update `GOAL.md` if the objective changed
2. update `METAOS_CONSTITUTION.md` if an invariant or authority rule changed
3. update the relevant layer checklist
4. update `COVERAGE_AUDIT.csv`
5. update `CONFLICT_LOG.csv` if the change introduces, resolves, or sharpens a conflict
6. only then update lower-level implementation or reference files

## Patch Rules

- do not create a new lower-level governance skeleton when the top skeleton can absorb the rule
- keep diffs small and authority explicit
- prefer modifying canonical files over creating new governance markdown
- if a patch changes loop behavior, note the affected runtime file and metric path

## Reject Conditions

- governance changes appear only in lower-level docs
- a new mini-framework is added beneath the top skeleton
- coverage is reduced without explicit justification
- conflicts are silently ignored
