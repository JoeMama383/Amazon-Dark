# v7.431 validation

## Completed in the packaging environment

- `scripts/lint-logos.sh`: PASS.
- `bash -n` on `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `scripts/validate.sh`: PASS.
- Python compile check for the full `tests/` tree: PASS.
- Current release identity verified across package control, runtime `AD_VERSION`, FULL/VIEWPORT probe payload, VIEWPORT helper, TRANSITION helper, native skeleton filenames, and SpringBoard launch log: v7.431.
- New `test_v7431_pdp_r2_r5_fix.py`: PASS.
- New direct-parent v7.430 -> v7.431 transition-probe handoff test: PASS.
- Critical inherited regressions explicitly rerun and passed: cold launch policy, universal UI probes, probe-handoff CI contract, optimization/cache contract, PDP payload execution and child-frame isolation, CSS cascade/semantic-color preservation, product-scroll/video border behavior, PDP completion, Sponsored footer restoration, PDP transition skeleton, compact stripe taming, v7.430 native review menu, Cart/BYG, and location ownership.

The long all-tests sequential wrapper is intentionally not presented as iOS compile/device proof here; GitHub Actions/device push still runs the shipped `scripts/validate.sh`. No iOS SDK/Theos compile or device rendering was available in this packaging environment.

## Device verification still required

After installing v7.431, re-check the four supplied r2-r5 screens: Product image gallery + hero ad footer, Yellow/Blue swatches, the `$59.97` ad/card, and Similar brands on Amazon. FULL/VIEWPORT/TRANSITION probe tooling has been regenerated as v7.431 for follow-up evidence.
