# AmazonDark v7.614 — validation receipt

**Command run from the full source tree:**

```sh
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
```

**Result:** **PASS** (exit code 0; no tracebacks). `lint-logos: OK`; `python-regressions: OK (271)`.

The suite includes source-level regression contracts for every intervening version from v7.606 through v7.613, in addition to the v7.614 probe-version synchronization test and historical contracts. It checks the three probe helper identities, previous UI patches, JavaScript syntax and C/C++98 include compilation in the tests that require them. All 271 test scripts completed.

The previous v7.613 CI error `validate: version sync missing 'VER=7.613' in scripts/ui-probe.sh` is fixed by consistent versioning for the v7.614 release. Tests also required updating the release handoff, removing one dead static helper, and aligning historical runtime diagnostic markers; these were corrected and the entire strict command rerun successfully.

**Limitations:** The current environment does not include Theos/iOS SDK for building the jailbreak `.deb`, and it cannot verify on-device rendering or execute a remote GitHub push. The build/push must be done from the user's existing clone and CI.
