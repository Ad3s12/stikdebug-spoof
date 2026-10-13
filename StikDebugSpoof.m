// StikDebugSpoof: tweak do LiveContainer.
// Sprawia, ze canOpenURL: zwraca YES dla schematow StikDebug, bo w LC
// sandbox nie widzi LSApplicationQueriesSchemes aplikacji hosta.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL (*origCanOpenURL)(id, SEL, NSURL *);

static BOOL isStikScheme(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    return [scheme isEqualToString:@"stikdebug"] || [scheme isEqualToString:@"stikjit"];
}

static BOOL hookedCanOpenURL(id self, SEL _cmd, NSURL *url) {
    if (url && isStikScheme(url)) {
        return YES;
    }
    return origCanOpenURL(self, _cmd, url);
}

__attribute__((constructor))
static void StikDebugSpoofInit(void) {
    Method m = class_getInstanceMethod([UIApplication class], @selector(canOpenURL:));
    if (!m) return;
    origCanOpenURL = (BOOL (*)(id, SEL, NSURL *))method_getImplementation(m);
    method_setImplementation(m, (IMP)hookedCanOpenURL);
}
