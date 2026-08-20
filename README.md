# AmazonDark v6.0.164

Built on **v6.0.159** (`a8957c0`), with the v6.0.163 instrumentation retained so the
next capture measures the delta directly. Two perf fixes and one rendering fix, all
derived from the 163 dump rather than from theory.

## 1. Attach dedupe was O(payload) — the 22.3ms/call

`ADAttachThreeSymbolsUserScript605` and `ADAttachWhiteTameUserScript446` both deduped
by running `containsString:` over every already-installed user script's source.
`ucc.userScripts` holds the 346KB Dark Reader bootstrap, and `-[WKUserScript source]`
returns a copy on each access, so every call searched roughly half a megabyte of JS.
The symbols helper runs on every `WKWebView -didMoveToWindow`, which is exactly where
the measured **22,347 µs/call** came from — 290.5ms across 13 calls, 31% of all time.

Both now mark the controller with an associated object and answer in constant time.
The source scan is kept as a fallback for a controller that was populated before the
marker existed, and sets the marker when it finds a match.

## 2. Person-raster layout queried semantics before geometry

`RCTView -layoutSubviews` measured **115.5 µs/call**, 3,566 calls, **411.7ms — 44% of
all time**. `ADPersonRasterLayout6150` read associated objects and semantics
(`accessibilityLabel`, then `ADWTViewText362`'s `isKindOfClass` / `respondsToSelector`
/ `performSelector` chain) *before* testing whether the view could be a candidate at
all. The geometry test is pure arithmetic on `bounds`, and on a screen of RCT views
almost nothing passes it.

The cheap reject now runs first. Views already holding a claim still fall through, so
stale-claim retirement is unchanged.

## 3. Reviews tab rendered blank

`-[CALayer setContents:]` suppressed with `%orig(nil)` when
`(!hasSemantic || live==stored)`. The `!hasSemantic` arm is the bug. A recycled RCT
view whose text has not been bound yet reports `hasSemantic=NO`, which satisfied the
suppression **and** failed the retirement test directly above it (that one requires
`hasSemantic && live!=stored`). So its contents were set to nil and the claim was never
released. If RN never issues another `setContents:` on that layer, it stays blank
permanently. Review cards land inside the kind-2 window (105–300 × 42–88), which is why
that tab voids out while the surrounding page renders.

Suppression now requires positive confirmation: `hasSemantic && live==stored`. A view
is blanked only while it is actually carrying a Person-matching label.

**The trade, stated plainly:** if a genuine Person card ever has no label at the moment
its contents arrive, it will now render untamed instead of being claimed. That is the
right side to err on — an untamed Person card is a cosmetic miss, a blanked Reviews tab
is unusable content.

## New counters

The dump gains `Person-raster claims taken=N  contents suppressed=N`. On a Reviews
capture, suppressions should now be 0 where 163 would have blanked.

## Verification

- Suppression logic checked as a truth table against 163: the recycled-card case flips
  from blanked to rendered, the live Person card still blanks, and both retirement
  cases are unchanged. 5/5.
- All six injected JS payloads **byte-identical to v6.0.159**.
- Whole-file brace/paren/bracket balance 0/0/0, `scripts/lint-logos.sh`.
