# Amazon Dark

True dark mode for the Amazon Shopping iOS app — designed to look native rather than simply inverting the screen.

Rootless jailbreak, arm64 + arm64e, iOS 15+.

---

## Features

Amazon Dark themes both the web and native parts of the Amazon app using a combination of:

* **Dark Reader** for Amazon's web content
* Amazon's **built-in native dark-mode components**
* Custom theming for native UIKit and React Native surfaces
* Automatic correction of icons, buttons, text, backgrounds, ads, and other Amazon-specific UI
* Protection for product photos and other content that should keep its original appearance

The tweak is continuously adjusted for Amazon's constantly changing and dynamically loaded interface.

### White Background Taming

Amazon product photos often have extremely bright white backgrounds.

Optional **White Background Taming** reduces those bright areas while preserving the product itself.

Amazon Dark uses context-aware rules so normal icons, category artwork, Person-tab glyphs, ads, and other UI elements aren't incorrectly treated like product photos.

The strength can be adjusted in Settings.

### Dark Launch Screen

Amazon normally shows a bright white screen during a cold launch before the app loads.

Amazon Dark includes a SpringBoard component that temporarily covers this with a dark launch screen until Amazon is ready.

### 120 Hz

An optional setting requests up to **120 Hz** while using Amazon on supported devices.

iOS may still lower the refresh rate depending on Low Power Mode, temperature, hardware, or other system conditions.

---

## Settings

Settings → **AmazonDark**

Available options:

* Enabled
* Tame white backgrounds
* Taming strength
* Request 120 Hz

White Background Taming and 120 Hz are disabled by default.

---

## Build

Requires Theos:

```bash
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

GitHub Actions automatically builds and tests the rootless `.deb` on every push.

---

## Install

Install the generated `.deb` through your package manager or with `dpkg`.

After installing or updating, **respring and relaunch Amazon**.

Make sure tweak injection is enabled for Amazon in your jailbreak environment.

---

## Compatibility

Amazon uses a mixture of WebKit, UIKit, React Native, server-driven UI, custom icons, advertisements, and product media.

Because of this, Amazon Dark uses targeted fixes instead of applying one global filter over the entire app.

The goal is simple:

**Make Amazon look like it actually shipped with a proper dark mode.**

---

## Credits

Web theming is powered in part by [Dark Reader](https://github.com/darkreader/darkreader), licensed under the MIT License.

See `Resources/DARKREADER-LICENSE`.

Amazon Dark is an independent jailbreak tweak and is not affiliated with Amazon.
