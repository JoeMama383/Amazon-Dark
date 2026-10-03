# AmazonDark v7.560 audit — Returns success alert

Probe evidence: completed v7.556 FULL capture from the exact Returns Center screen. The remaining white card is `div.a-box.a-alert.a-alert-success` (396x116) with `div.a-box-inner.a-alert-container` (382x112). The outer alert carries Amazon-authored green borders: 2px top/right/bottom and a 12px left rail in `rgb(11,123,60)`.

v7.560 changes only the two captured white fill planes to OLED black and explicitly keeps their text white. It does not write border, border-color, radius, width, height, position, transform, or margin on the success alert, so the green perimeter/left rail remains authored and intact. Existing Returns link/semantic colors and all v7.559/v7.558 work remain unchanged.
