//
//  MAWindowManager.m
//  MacTest
//
//  Created by 马英伦 on 2020/4/9.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MAWindowManager.h"

@interface MAWindowManager ()

@property (nonatomic, strong) NSMutableDictionary *windowMap;

@end

@implementation MAWindowManager

+ (instancetype )sharedManager {
    static MAWindowManager *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.windowMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)holdWindowController:(NSWindowController *)windowController
{
    if (windowController)
    {
        self.windowMap[NSStringFromClass(windowController.class)] = windowController;
    }
}

- (void)removeWindowController:(Class)windowControllerClass
{
    self.windowMap[NSStringFromClass(windowControllerClass)] = nil;
}


@end
