#include "ADServiceRaster7565.h"
static const void *kADServiceLogoOriginal7565=&kADServiceLogoOriginal7565;
static const void *kADServiceLogoPaint7565=&kADServiceLogoPaint7565;
static UIImage *ADServiceLogo7565(UIImage *im,BOOL banner){
    CGImageRef cg=im.CGImage;if(!cg)return im;
    size_t w=CGImageGetWidth(cg),h=CGImageGetHeight(cg);
    if(!w||!h||w>1200||h>512)return im;
    unsigned char *pixels=(unsigned char *)calloc(w*h,4);if(!pixels)return im;
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx=CGBitmapContextCreate(pixels,w,h,8,w*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);if(!ctx){free(pixels);return im;}
    CGContextDrawImage(ctx,CGRectMake(0,0,w,h),cg);
    for(size_t i=0;i<w*h;i++){
        if(banner)ADServiceBannerPixel7565(pixels+i*4);else ADServiceLogoPixel7565(pixels+i*4);
    }
    CGImageRef out=CGBitmapContextCreateImage(ctx);
    UIImage *result=out?[UIImage imageWithCGImage:out scale:im.scale orientation:im.imageOrientation]:im;
    if(out)CGImageRelease(out);CGContextRelease(ctx);free(pixels);return result?:im;
}
static void ADServiceImage7565(UIImageView *iv){
    if(!iv||gADMenuImageWrite7255)return;
    UIImage *original=objc_getAssociatedObject(iv,kADServiceLogoOriginal7565);
    UIImage *paint=objc_getAssociatedObject(iv,kADServiceLogoPaint7565);
    if(!ADServiceRoot7565(iv)){
        if(original&&iv.image==paint){gADMenuImageWrite7255=YES;@try{iv.image=original;}@finally{gADMenuImageWrite7255=NO;}}
        return;
    }
    if(!iv.image)return;
    CGFloat w=iv.bounds.size.width,h=iv.bounds.size.height;
    BOOL glyph=w>=7&&w<=20&&h>=7&&h<=20;
    BOOL logo=w>=100&&h>=20&&h<=60;
    BOOL banner=w>=300&&h>=70&&h<=120; // captured Ask Health AI raster, never the 80pt map
    if(glyph||logo||banner){
        if(iv.image!=paint&&iv.image!=original){
            original=iv.image;
            paint=glyph?[original imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]:ADServiceLogo7565(original,banner);
            objc_setAssociatedObject(iv,kADServiceLogoOriginal7565,original,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(iv,kADServiceLogoPaint7565,paint,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if(iv.image!=paint){gADMenuImageWrite7255=YES;@try{iv.image=paint;}@finally{gADMenuImageWrite7255=NO;}}
        if(glyph)iv.tintColor=ADLightText706();
        // Ask Health AI is lettering/glyph artwork, not a photograph.
        ADMenuRemoveTWB7255(iv);
    }else if(w>=52&&h>=52){
        // Use the existing single preference-controlled overlay, not a second dimming layer.
        if(gP.whiteTame)ADEnsureNativeTWBOverlay7270(iv);else ADMenuRemoveTWB7255(iv);
    }
}
