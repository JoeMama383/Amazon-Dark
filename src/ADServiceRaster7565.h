// Premultiplied RGBA: lighten neutral dark logo lettering, preserving colored ink/alpha.
static void ADServiceLogoPixel7565(unsigned char *p){
    unsigned int a=p[3];if(a<16)return;
    unsigned int hi=p[0]>p[1]?p[0]:p[1];if(p[2]>hi)hi=p[2];
    unsigned int lo=p[0]<p[1]?p[0]:p[1];if(p[2]<lo)lo=p[2];
    if(hi*100<a*50&&(hi-lo)*100<=a*16){
        p[0]=(unsigned char)(a*232/255);p[1]=(unsigned char)(a*230/255);p[2]=(unsigned char)(a*227/255);
    }
}

static void ADServiceBannerPixel7565(unsigned char *p){
    unsigned int a=p[3];if(a<16)return;
    unsigned int hi=p[0]>p[1]?p[0]:p[1];if(p[2]>hi)hi=p[2];
    unsigned int lo=p[0]<p[1]?p[0]:p[1];if(p[2]<lo)lo=p[2];
    if(lo*100>a*75&&(hi-lo)*100<=a*16){p[0]=p[1]=p[2]=0;return;}
    ADServiceLogoPixel7565(p);
}
