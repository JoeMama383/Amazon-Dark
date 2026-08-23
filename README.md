# AmazonDark v7.0.37~probe

Probe workflow correction only. Diagnostic capture scope remains the same as v7.0.36.

## Historically working trigger restored

The older working AmazonDark probe used SIGUSR2.

When PID discovery was needed, Amazon appeared in `ps` using its full executable path
ending in `/Amazon.app/Amazon`, so matching only the bare process name was unreliable.

This build therefore listens for SIGUSR2.

The supplied NewTerm block uses:
- `ps`
- `grep`
- `head`
- zsh's own whitespace splitting to extract the PID

It does NOT use:
- notifyutil
- pgrep
- awk
- pidof

## Probe coverage

Current visible Home frame only:
- missing category-card visual leaves;
- large Home photo ads not receiving TWB;
- large seasonal/category glyph/media not receiving TWB;
- visible iframe and child-frame media where the all-frame bootstrap can respond.

No production styling changes.

## Performance

Diagnostic only:
- 0 querySelectorAll
- 0 MutationObserver
- 0 TreeWalker
- 0 scroll listeners
- 0 setInterval
- 0 requestAnimationFrame
- 0 recurring scanners/timers
