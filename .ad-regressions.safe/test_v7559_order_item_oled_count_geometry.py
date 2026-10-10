"""v7.619: probe-backed order-item OLED theming + quantity badge centering."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]
t=(R/'src/Tweak.xm').read_text()
control=(R/'layout/DEBIAN/control').read_text()
assert 'Version: 7.619~handoff-regression-repair' in control
assert '#define AD_VERSION "v7.619-handoff-regression-repair"' in t
start=t.index('static NSString *ADPDPProbeBackedFixesJS7458(void){')
end=t.index('static NSString *ADCoreWebJS7271(void)', start)
seg=t[start:end]
# Exact probe-backed route/family gate: do not make a generic section#pop global owner.
gate='section#pop.layout__background:has(.item-view__qty-large)'
assert gate in seg
# Captured white card family becomes OLED; authored separators become neutral gray.
assert gate+' .pop-card{background:#000!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;}' in seg
# Captured touch rows are OLED, gray-bordered, light-text and do not flash stock white on press.
row=gate+' .pop-card a.a-touch-link.a-box'
assert row+'{background:#000!important;border-color:#494d4d!important;outline-color:#494d4d!important;box-shadow:none!important;color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;-webkit-tap-highlight-color:transparent!important;}' in seg
assert row+':is(:active,:focus,:focus-visible){background:#202324!important;border-color:#747a7c!important;box-shadow:none!important;}' in seg
# Primary/secondary text and dynamic authored colors follow the established algorithm.
assert 'color:#e8e6e3!important;-webkit-text-fill-color:#e8e6e3!important;' in seg
assert ':is(.a-color-secondary,.a-color-tertiary)' in seg and 'color:#b1aaa0!important' in seg
assert ':is(.a-color-link,.a-link-normal,.a-color-price' in seg and '-webkit-text-fill-color:currentColor!important;' in seg
# Chevron painter is border-based in the supplied FULL probe.
assert gate+' .pop-card i.a-icon.a-icon-touch-link{border-color:#e8e6e3!important;}' in seg
# Exact captured 30x30 count owner gets gray/white styling and true flex centering.
qty=seg.split(gate+' .item-view__qty-large{',1)[1].split('}',1)[0]
for token in ('background:#303335!important','color:#fff!important','-webkit-text-fill-color:#fff!important','border-color:#747a7c!important','display:flex!important','align-items:center!important','justify-content:center!important','text-align:center!important','line-height:1!important','padding:0!important','box-sizing:border-box!important'):
    assert token in qty, token
# Do not move/resize the authored circle; only the glyph's layout is centered inside it.
for forbidden in ('width','height','min-width','min-height','top','left','right','bottom','transform','margin','border-radius','font-size'):
    assert not any(part.lstrip().startswith(forbidden+':') for part in qty.split(';')), (forbidden,qty)
# Exact product raster gets configured TWB; blue Share/link icon is excluded.
assert gate+' .item-view__inner-col>a.a-link-normal>img:not(.connection-share-icon)' in seg
assert 'filter:brightness(%.3f)!important' in seg
# Production path remains declarative/event-free.
for forbidden in ('MutationObserver','setInterval(','requestAnimationFrame(','addEventListener(\'scroll\'','addEventListener("scroll"','setTimeout(','dispatch_after'):
    assert forbidden not in seg, forbidden
# Account remains evidence-deferred, as required by v7.558.
for banned in ('kADPersonRedirectedRoot7557','kADPersonRedirectedRoot7558','kADPersonRedirectedRoot7559','ADPersonRedirectedRoot7557','ADPersonRedirectedRoot7558','ADPersonRedirectedRoot7559'):
    assert banned not in t, banned
print('PASS: v7.619 order-item OLED cards/text/dividers, dynamic color preservation, TWB, and centered count geometry')
