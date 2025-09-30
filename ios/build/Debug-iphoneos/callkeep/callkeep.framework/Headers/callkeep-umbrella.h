#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "CallKeep.h"
#import "CallKeepPushDelegate.h"
#import "FlutterCallkeepPlugin.h"

FOUNDATION_EXPORT double callkeepVersionNumber;
FOUNDATION_EXPORT const unsigned char callkeepVersionString[];

