//
//  ViewController.m
//  MacTest
//
//  Created by 马英伦 on 2020/4/7.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "ViewController.h"
#import "MAPeelAudioWindowController.h"
#import "MAWindowManager.h"
#import "MAPeelVideoWindowController.h"
#import "MAMyPeelVideoWindowController.h"
#import "MACheckWindowController.h"
#import "MANDIWindowController.h"

@interface ViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSTableView *tableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tableView = [[NSTableView alloc] initWithFrame:self.view.bounds];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"field1"];
    column.width=162;
    [_tableView addTableColumn:column];
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.backgroundColor = [NSColor purpleColor];
    [scrollView setDocumentView:_tableView];
    [self.view addSubview:scrollView];
    [_tableView reloadData];


    
//    NSTableView *tableView = [[NSTableView alloc] initWithFrame:self.view.bounds];
////    tableView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
//    tableView.delegate = self;
//    tableView.dataSource = self;
//    [self.view addSubview:tableView];
//
//    tableView.wantsLayer = YES;
//    tableView.layer.backgroundColor = [NSColor yellowColor].CGColor;
//    self.tableView = tableView;
    
//    av_log_set_level(AV_LOG_INFO);
//
//    av_register_all();
//    avformat_network_init();
//
//    AVFormatContext *fmt_ctx = NULL;
//    int ret = avformat_open_input(&fmt_ctx, "rtmp://172.25.176.97:1935/wstv/home", 0, 0);
//    if (ret < 0)
//    {
//        NSLog(@"%s", av_err2str(ret));
//        avformat_close_input(&fmt_ctx);
//        return;
//    }
//
//    av_dump_format(fmt_ctx, 0, "rtmp://172.25.176.97:1935/wstv/home", 0);
//
//    avformat_close_input(&fmt_ctx);
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return 5;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (row == 0)
       {
           return @"Peel Audio";
       } else if (row == 1)
       {
           return @"Peel Video";
       } else if (row == 2) {
           return @"My Peel Video";
       } else if (row == 3) {
           return @"Check";
       } else {
           return @"ndi";
       }
    return [NSString stringWithFormat:@"%ld", (long)row];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    if (row == 0)
    {
        MAPeelAudioWindowController *windowController = [[MAPeelAudioWindowController alloc] initWithWindowNibName:@"MAPeelAudioWindowController"];
        [windowController.window center];
        [windowController.window makeKeyAndOrderFront:nil];
        [[MAWindowManager sharedManager] holdWindowController:windowController];
    } else if (row == 1)
    {
        MAPeelVideoWindowController *windowController = [[MAPeelVideoWindowController alloc] initWithWindowNibName:@"MAPeelVideoWindowController"];
        [windowController.window center];
        [windowController.window makeKeyAndOrderFront:nil];
        [[MAWindowManager sharedManager] holdWindowController:windowController];
    } else if (row == 2) {
        MAMyPeelVideoWindowController *windowController = [[MAMyPeelVideoWindowController alloc] initWithWindowNibName:@"MAMyPeelVideoWindowController"];
        [windowController.window center];
        [windowController.window makeKeyAndOrderFront:nil];
        [[MAWindowManager sharedManager] holdWindowController:windowController];
    } else if (row == 3) {
        MACheckWindowController *windowController = [[MACheckWindowController alloc] initWithWindowNibName:@"MACheckWindowController"];
        [windowController.window center];
        [windowController.window makeKeyAndOrderFront:nil];
        [[MAWindowManager sharedManager] holdWindowController:windowController];
    } else if (row == 4) {
        MANDIWindowController *windowController = [[MANDIWindowController alloc] initWithWindowNibName:@"MANDIWindowController"];
        [windowController.window center];
        [windowController.window makeKeyAndOrderFront:nil];
        [[MAWindowManager sharedManager] holdWindowController:windowController];
    }
    
    return YES;
}

@end
