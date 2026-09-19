"""Approved v7.426 selector extensions; retain the older TWB golden contract."""
def strip_video7425(source):
    assert source.count('#search [class*=_navigationWrapper_8wyx7_] > [class*=_container_avw36_][class*=_Horizontal_avw36_],#search .swv-container [class*=_navigationWrapper_1qmu7_] > [class*=_container_avw36_][class*=_Horizontal_avw36_]{')==1
    source=source.replace('#search [class*=_navigationWrapper_8wyx7_] > [class*=_container_avw36_][class*=_Horizontal_avw36_],#search .swv-container [class*=_navigationWrapper_1qmu7_] > [class*=_container_avw36_][class*=_Horizontal_avw36_]{','#search [class*=_navigationWrapper_8wyx7_] > [class*=_container_avw36_][class*=_Horizontal_avw36_]{')
    assert source.count('[class*=_videoLink_1m98b_] > [class*=_videoOverlay_1m98b_],#search .swv-container [class*=_videoLink_x4voi_] > [class*=_videoOverlay_x4voi_]{')==1
    source=source.replace('[class*=_videoLink_1m98b_] > [class*=_videoOverlay_1m98b_],#search .swv-container [class*=_videoLink_x4voi_] > [class*=_videoOverlay_x4voi_]{','[class*=_videoLink_1m98b_] > [class*=_videoOverlay_1m98b_]{')
    return source
