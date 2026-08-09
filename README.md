# Amazon Dark

True dark mode for the Amazon Shopping iOS app — designed to look native instead of simply inverting the screen.

Rootless jailbreak, arm64 + arm64e, iOS 15+.

## Install

### Sileo

**[Add Amazon Dark to Sileo](sileo://source/https://colindavidr.github.io/Amazon-Dark/)**

Add the repository, search for **Amazon Dark**, and install it directly through Sileo.

### Manual Install

Prefer installing the `.deb` yourself?

**[Download the latest release](https://github.com/colindavidr/Amazon-Dark/releases/latest)**

After installing or updating, respring and relaunch Amazon.

Make sure tweak injection is enabled for Amazon in your jailbreak environment.

---

## Features

Amazon Dark themes both the web and native parts of the Amazon Shopping app using a combination of:

* **Dark Reader** for web content
* Amazon's **native dark-mode components**
* Custom theming for UIKit and React Native surfaces
* Automatic correction of icons, buttons, text, backgrounds, ads, and other Amazon-specific UI
* Protection for product photos and artwork that should retain their original appearance
* Optional **White Background Taming**
* Dark cold-launch screen
* Optional **120 Hz** support

The tweak is continuously adjusted for Amazon's dynamically loaded and frequently changing interface.

### White Background Taming

Amazon product photos often use extremely bright white backgrounds.

Optional **White Background Taming** reduces those bright areas while preserving the product itself.

Context-aware rules prevent normal icons, category artwork, Person-tab glyphs, ads, and other interface elements from being incorrectly treated like product photos.

Taming strength can be adjusted in Settings.

### Dark Launch Screen

Amazon normally displays a bright white screen during a cold launch before the app has loaded.

Amazon Dark replaces this period with a temporary dark launch screen for a more consistent dark-mode experience.

### 120 Hz

Amazon Dark can optionally request up to **120 Hz** while using Amazon on supported devices.

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

## Compatibility

Amazon uses a mixture of WebKit, UIKit, React Native, server-driven UI, custom icons, advertisements, and product media.

Amazon Dark uses targeted fixes for each type of content instead of applying one global visual filter over the app.

The goal is simple:

**Make Amazon look like it actually shipped with a proper dark mode.**

---

## Credits

Web theming is powered in part by [Dark Reader](https://github.com/darkreader/darkreader), licensed under the MIT License.

Amazon Dark is an independent jailbreak tweak and is not affiliated with Amazon.
