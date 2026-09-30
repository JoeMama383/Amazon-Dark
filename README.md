## v7.526 — Returns thumbnail + handoff regression repair

Direct parent: **v7.524~returns-thumbnail-render-geometry-revert**.

The v7.524 visual implementation is preserved: the real Returns thumbnail lane remains rendered/tamed, the white shell is cleared through rehydration, the v7.523 left-corner border fix remains intact, and the v7.522 text recenter is suppressed whenever the real thumbnail lane is present.

v7.526 fixes the handoff regression introduced in v7.524 only. `COMMANDS.md` is restored to the proven existing-clone workflow and the established FULL / VIEWPORT / TRANSITION command contract: `export full`, separate VIEWPORT `arm` and `export viewport`, and TRANSITION `arm transition` / `export`. No `git init`, no `.git` deletion, no remote recreation, and no force push.
