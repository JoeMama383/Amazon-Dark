# AmazonDark v7.388 — native work optimization

Built directly from the v7.387 source handoff in this conversation.

This release skips unrelated settings refreshes, avoids duplicate privacy protocol
array copies, prevents Search backing insertion from starting a nested theme pass,
and avoids rebuilding checkout appearances when their current properties already
match. It also fixes checkout transaction cleanup and the viewport helper's stale
package-version gate. The existing CSS/theme programs and probe capture scope are
preserved.

All 43 regression scripts pass. A clean local build compiles and links arm64 and
arm64e; the main fat dylib remains 1,513,280 bytes, equal to v7.387. The available
local compiler warns about arm64e ABI compatibility, so GitHub Actions remains the
required build for the installable rootless package. Device rendering and speed
have not been measured for this release.

See **AUDIT-v7.388.md** for scope, measurements and remaining opportunities, and
**COMMANDS.md** for the phone push/probe workflow. Run `sh scripts/validate.sh`
before pushing. Install the resulting Actions package, then open Amazon once.
