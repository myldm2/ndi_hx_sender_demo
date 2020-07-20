//
//  MACheckWindowController.m
//  MacTest
//
//  Created by 马英伦 on 2020/4/24.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MACheckWindowController.h"

@interface MACheckWindowController ()

@end

@implementation MACheckWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSString *filePath1 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Test/test.h264"];
    NSString *filePath2 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Test/test2.h264"];
    
    NSData *data1 = [NSData dataWithContentsOfFile:filePath1];
    NSData *data2 = [NSData dataWithContentsOfFile:filePath2];
    
    for (unsigned long i = 0; i < data1.length; i ++) {
        uint8_t i1 = ((uint8_t *)data1.bytes)[i];
        uint8_t i2 = ((uint8_t *)data2.bytes)[i];
        if (i1 != i2)
        {
            NSLog(@"%lu  r:%u  w:%u", i, i1, i2);
        }
    }
}

@end
