# v7.525 review

Direct parent: **v7.524~returns-thumbnail-render-geometry-revert**.

## Regression repaired

The v7.524 handoff accidentally rewrote `COMMANDS.md` to initialize a fresh temporary Git repository and changed the probe command syntax to unsupported shorthand. This broke the established workflow and violated frozen source regressions.

v7.525 restores the v7.523-proven contract verbatim except for release identity and commit text:

- existing clone at `/var/mobile/Amazon-Dark-phone`;
- stage downloaded source, copy it into the existing clone, validate, commit, normal `git push origin main`;
- FULL export uses `scripts/ui-probe.sh export full`;
- VIEWPORT arm and export remain separate commands;
- TRANSITION uses `arm transition` and a separate export;
- no `git init`, `.git` deletion, remote recreation, or force push.

The v7.524 Returns thumbnail/border/text behavior is otherwise unchanged.
