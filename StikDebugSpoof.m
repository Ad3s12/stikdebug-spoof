// StikDebugSpoof: tweak do LiveContainer.
// Sprawia, ze canOpenURL: zwraca YES dla schematow StikDebug, bo w LC
// sandbox nie widzi LSApplicationQueriesSchemes aplikacji hosta.
//
// Diagnostyka: zapisuje Documents/StikDebugSpoof.log (widoczny w Plikach/LC),
// zeby bylo wiadomo, czy tweak sie zaladowal i czy canOpenURL jest wolany.
// Hook jest zakladany ponownie po starcie, bo LC moze nadpisac go swoim.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL (*origCanOpenURL)(id, SEL, NSURL *);
static BOOL hookedCanOpenURL(id self, SEL _cmd, NSURL *url);

static void spoofLog(NSString *msg) {
    @try {
        NSString *dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (!dir) return;
        NSString *path = [dir stringByAppendingPathComponent:@"StikDebugSpoof.log"];
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [line writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
            return;
        }
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } @catch (__unused NSException *e) {}
}

static BOOL isStikScheme(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    return [scheme isEqualToString:@"stikdebug"] || [scheme isEqualToString:@"stikjit"];
}

static BOOL hookedCanOpenURL(id self, SEL _cmd, NSURL *url) {
    BOOL stik = (url && isStikScheme(url));
    spoofLog([NSString stringWithFormat:@"canOpenURL: %@ -> %@", url, stik ? @"YES (spoofed)" : @"passthrough"]);
    if (stik) return YES;
    return origCanOpenURL ? origCanOpenURL(self, _cmd, url) : NO;
}

static void installHook(const char *reason) {
    Method m = class_getInstanceMethod([UIApplication class], @selector(canOpenURL:));
    if (!m) { spoofLog(@"canOpenURL: method not found"); return; }
    IMP cur = method_getImplementation(m);
    if (cur == (IMP)hookedCanOpenURL) return;
    // Zapamietaj aktualna implementacje (moze to byc hook LC) jako "oryginal".
    origCanOpenURL = (BOOL (*)(id, SEL, NSURL *))cur;
    method_setImplementation(m, (IMP)hookedCanOpenURL);
    spoofLog([NSString stringWithFormat:@"hook installed (%s)", reason]);
}

__attribute__((constructor))
static void StikDebugSpoofInit(void) {
    spoofLog([NSString stringWithFormat:@"tweak loaded in %@", NSBundle.mainBundle.bundleIdentifier]);
    installHook("constructor");

    // Zaloz ponownie, gdyby LC albo aplikacja nadpisaly hook pozniej.
    for (NSNumber *delay in @[@0.2, @1.0, @3.0, @8.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ installHook("delayed"); });
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil queue:nil
                                                  usingBlock:^(__unused NSNotification *n) { installHook("didBecomeActive"); }];
}
