# REVIEW v7.531

## Why v7.530 failed CI
`COMMANDS.md` was left at v7.529 while the package/probe source had been bumped to v7.530. The normalized historical regression `test_v7375_checkout_prepaint_snapshot_hydration.py` correctly expected the current source ZIP identity in COMMANDS.md and failed.

## v7.531 repair
- Preserve all v7.530 Interests UI code.
- Synchronize package/probe identities to v7.531.
- Regenerate COMMANDS.md with the exact current source ZIP identity.
- Keep the frozen existing-clone push workflow and separate FULL / VIEWPORT / TRANSITION commands.
- Add a current regression that explicitly checks the source ZIP identity and frozen handoff contract.
