/* The game plays in landscape, the launcher stays as the player holds it (app_main.c,
 * bb_ios_start_game). A black window that allows only landscape covers the launcher first and the
 * scene turns under it, so the launcher's page is never seen sideways; the game's window then
 * opens over it at the landscape size, and SDL's window refuses portrait (SDL_HINT_ORIENTATIONS). */
#import <UIKit/UIKit.h>

@interface BBLandscapeCover : UIViewController
@end

@implementation BBLandscapeCover
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}
- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

static UIWindow *cover;

/* The launcher opens as the phone is held: an app that ended while the game had turned it to
 * landscape came back in landscape (the launcher allows every orientation, so nothing turned it
 * back). When its scene first becomes active, it turns to the device's orientation, portrait
 * unless the phone is held sideways. */
__attribute__((constructor)) static void follow_device_orientation(void) {
    static id observer;
    observer = [NSNotificationCenter.defaultCenter
        addObserverForName:UISceneDidActivateNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) {
                    [NSNotificationCenter.defaultCenter removeObserver:observer];
                    if (![note.object isKindOfClass:UIWindowScene.class]) return;
                    UIDeviceOrientation device = UIDevice.currentDevice.orientation;
                    UIInterfaceOrientationMask mask =
                        device == UIDeviceOrientationLandscapeLeft    ? UIInterfaceOrientationMaskLandscapeRight
                        : device == UIDeviceOrientationLandscapeRight ? UIInterfaceOrientationMaskLandscapeLeft
                                                                      : UIInterfaceOrientationMaskPortrait;
                    [(UIWindowScene *)note.object
                        requestGeometryUpdateWithPreferences:[[UIWindowSceneGeometryPreferencesIOS alloc]
                                                                 initWithInterfaceOrientations:mask]
                                                errorHandler:nil];
                }];
}

void bb_ios_landscape(void) {
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes)
        if ([candidate isKindOfClass:UIWindowScene.class]) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    if (!scene) return;
    /* The launcher steps aside for the game: its web view stops loading and leaves its window, and
     * its windows lose their controllers and are hidden, so WebKit neither draws nor lays out while
     * the game starts (its regions in this process grew 256 -> 512 MiB during the game's start,
     * the room the game ran short of). The app ends with the game, so nothing is put back. */
    Class webViewClass = NSClassFromString(@"WKWebView");
    for (UIWindow *window in scene.windows) {
        NSMutableArray<UIView *> *views = [NSMutableArray arrayWithObject:window];
        while (views.count) {
            UIView *view = views.lastObject;
            [views removeLastObject];
            if (webViewClass && [view isKindOfClass:webViewClass]) {
                [view performSelector:@selector(stopLoading)];
                [view removeFromSuperview];
                continue;
            }
            [views addObjectsFromArray:view.subviews];
        }
        window.rootViewController = nil;
        window.hidden = YES;
    }
    BBLandscapeCover *controller = [BBLandscapeCover new];
    controller.view.backgroundColor = UIColor.blackColor;
    cover = [[UIWindow alloc] initWithWindowScene:scene];
    cover.backgroundColor = UIColor.blackColor;
    cover.rootViewController = controller;
    [cover makeKeyAndVisible];
    [controller setNeedsUpdateOfSupportedInterfaceOrientations];
    if (!UIInterfaceOrientationIsLandscape(scene.effectiveGeometry.interfaceOrientation)) {
        UIWindowSceneGeometryPreferencesIOS *landscape =
            [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
        [scene requestGeometryUpdateWithPreferences:landscape
                                       errorHandler:^(NSError *error) {
                                           NSLog(@"Landscape: the rotation was refused: %@", error);
                                       }];
    }
    /* The rotation finishes on the main run loop: at most a second. */
    for (int i = 0; i < 100 && !UIInterfaceOrientationIsLandscape(scene.effectiveGeometry.interfaceOrientation); ++i)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    printf("iOS PoC: landscape %s\n", UIInterfaceOrientationIsLandscape(scene.effectiveGeometry.interfaceOrientation) ? "set" : "not set");
}
