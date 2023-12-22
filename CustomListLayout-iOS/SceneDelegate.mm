//
//  SceneDelegate.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/22/23.
//

#import "SceneDelegate.hpp"
#import "ListViewController.hpp"

@interface SceneDelegate ()
@end

@implementation SceneDelegate

- (void)dealloc {
    [_window release];
    [super dealloc];
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    ListViewController *listViewController = [ListViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:listViewController];
    navigationController.navigationBar.prefersLargeTitles = YES;
    [listViewController release];
    window.rootViewController = navigationController;
    [navigationController release];
    [window makeKeyAndVisible];
    self.window = window;
    [window release];
}

@end
