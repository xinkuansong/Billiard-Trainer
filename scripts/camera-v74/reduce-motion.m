// Simulator-only verification utility. Never linked into CuePhys.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc == 2) {
            void *library = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW);
            void (*setMotion)(unsigned char) = library ? dlsym(library, "_AXSSetReduceMotionEnabled") : NULL;
            if (!setMotion) return 2;
            setMotion(atoi(argv[1]) != 0);
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        }
        BOOL enabled = UIAccessibilityIsReduceMotionEnabled();
        printf("{\"reduceMotion\":%s}\n", enabled ? "true" : "false");
        return argc == 2 && enabled != (atoi(argv[1]) != 0) ? 3 : 0;
    }
}
