//
//  MAWindowManager.h
//  MacTest
//
//  Created by 马英伦 on 2020/4/9.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MAWindowManager : NSObject

+ (instancetype )sharedManager;

- (void)holdWindowController:(NSWindowController *)windowController;

- (void)removeWindowController:(Class)windowControllerClass;

@end

NS_ASSUME_NONNULL_END
