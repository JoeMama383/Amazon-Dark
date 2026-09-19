# AmazonDark v7.429 — compact stripe banner taming

Exact source parent: delivered v7.428. All prior fixes retained.

The supplied v7.427 FULL probe identifies the pictured blue banner as hp-stripe > hp-lucid-wrapper > a.stripe, containing stripe-headline and stripe-media-container/video. The banner and video both have filter:none; video is playing and ready. This is mounted main-document content, not the separate iframe ad above it.

The existing menu White Tame Brightness sheet now dims this exact banner family as one unit at the configured strength. Its image/video/canvas children have their own filter/opacity reset to prevent compounded dimming. Colors, playback, links, dimensions and layout remain intact. The same existing preference-refresh and cleanup paths apply. No additional scripts, observers, timers or capture changes.

FULL/VIEWPORT/TRANSITION identities advance to v7.429. No device rendering or iOS compilation is claimed. See VALIDATION-v7.429.md and COMMANDS.md.
