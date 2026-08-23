# AmazonDark v7.0.20~probe

This restores the established probe workflow:

1. Open Amazon.
2. Position the below-carousel Home cards/floors you want captured.
3. Background Amazon once.
4. Wait 2–3 seconds.
5. Run the supplied NewTerm probe/export block.
6. That block copies the completed probe from Amazon's sandbox into the normal shared Documents/push folder.

Probe trigger:
- UIApplicationWillResignActiveNotification.

Probe scope:
- visible Home viewport only, excluding hero/carousel ancestry;
- visible bottom-navigation/background stack only;
- no document-wide walk;
- no MutationObserver;
- no recurring timer;
- no requestAnimationFrame loop;
- no scroll listener.

Bottom-nav production behavior remains background-only. No icon/symbology/tint changes are added.
