// Premultiplied RGBA: lighten neutral dark logo lettering, preserving colored ink/alpha.
static void ADServiceLogoPixel7565(unsigned char *p){
    unsigned int a=p[3];if(a<16)return;
    unsigned int hi=p[0]>p[1]?p[0]:p[1];if(p[2]>hi)hi=p[2];
    unsigned int lo=p[0]<p[1]?p[0]:p[1];if(p[2]<lo)lo=p[2];
    if(hi*100<a*50&&(hi-lo)*100<=a*16){
        p[0]=(unsigned char)(a*232/255);p[1]=(unsigned char)(a*230/255);p[2]=(unsigned char)(a*227/255);
    }
}

// Only the captured Health AI lettering raster uses this policy.
static void ADServiceBannerPixel7565(unsigned char *p){
    unsigned int a=p[3];if(!a)return;
    unsigned int hi=p[0]>p[1]?p[0]:p[1];if(p[2]>hi)hi=p[2];
    unsigned int lo=p[0]<p[1]?p[0]:p[1];if(p[2]<lo)lo=p[2];
    // Include translucent antialiased pale edge pixels; the old alpha<16
    // early exit left the original rounded white edge visible over OLED.
    if(lo*100>=a*70&&(hi-lo)*100<=a*20){p[0]=p[1]=p[2]=0;return;}
    // Raise dark cyan lettering to a readable cyan, retaining its channel ratios.
    // Bright gradient/glyph colors already above this level remain unchanged.
    if(p[1]>p[0]&&p[2]>p[0]&&(hi-lo)*100>a*20&&hi*100<a*75){
        unsigned int target=a*75/100;
        p[0]=(unsigned char)(p[0]*target/hi);
        p[1]=(unsigned char)(p[1]*target/hi);
        p[2]=(unsigned char)(p[2]*target/hi);
        return;
    }
    ADServiceLogoPixel7565(p);
}
