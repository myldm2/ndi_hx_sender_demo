//
//  MASendH264DataWindowController.m
//  MacTest
//
//  Created by 马英伦 on 2020/7/28.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MASendH264DataWindowController.h"
#include "Processing.NDI.Lib.h"
#include "Processing.NDI.Send.h"
#include "Processing.NDI.utilities.h"
#include "Processing.NDI.Embedded.h"

@interface MASendH264DataWindowController ()

@property (nonatomic) NDIlib_send_instance_t pSend;

@end

@implementation MASendH264DataWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        if (!NDIlib_initialize()) {
            NSException* myException = [NSException
                    exceptionWithName:@"FileNotFoundException"
                    reason:@"File Not Found on System"
                    userInfo:nil];
            @throw myException;
        } else {
            printf("Initialized NDIlib");
        }

        
        NDIlib_send_create_t create_params_Send;
        create_params_Send.p_ndi_name = "My Video 1";
        create_params_Send.p_groups = NULL;
        create_params_Send.clock_video = true;
        create_params_Send.clock_audio = true;
        self.pSend = NDIlib_send_create(&create_params_Send);
        
        
        for (int i = 0; i < 2; i ++) {

            NSString *pktFile = [NSString stringWithFormat:@"packet_%d", i];
            NSString *spsFile = [NSString stringWithFormat:@"sps_%d", i];
            NSString *frameFile = [NSString stringWithFormat:@"frame_%d", i];

            NSString *pktPath = [[NSBundle mainBundle] pathForResource:pktFile ofType:nil];
            NSString *spsPath = [[NSBundle mainBundle] pathForResource:spsFile ofType:nil];
            NSString *framePath = [[NSBundle mainBundle] pathForResource:frameFile ofType:nil];

            NSData *pkt = [[NSData alloc] initWithContentsOfFile:pktPath];
            NSData *sps = [[NSData alloc] initWithContentsOfFile:spsPath];
            NSData *frameData = [[NSData alloc] initWithContentsOfFile:framePath];

            NSMutableData *frame = [[NSMutableData alloc] initWithData:sps];
            [frame appendData:frameData];

            [self sendHeader:pkt frame:frame sps:sps];

//            [NSThread sleepForTimeInterval:5];
            
        }
        
        NDIlib_send_destroy(self.pSend);
    });
}

- (void)sendHeader:(NSData *)pkt frame:(NSData *)frameData sps:(NSData *)sps
{
    uint8_t** p_data_blocks = malloc(4);
    memset(p_data_blocks, 0, 4);
    int* p_data_blocks_size = malloc(4);
    memset(p_data_blocks_size, 0, 4);
    
    p_data_blocks[0] = (uint8_t*)pkt.bytes;
    p_data_blocks_size[0] = (int)pkt.length;
    p_data_blocks[1] = (uint8_t*)frameData.bytes;
    p_data_blocks_size[1] = (int)frameData.length;
    p_data_blocks[2] = (uint8_t*)sps.bytes;
    p_data_blocks_size[2] = (int)sps.length;
    
    
    NDIlib_video_frame_v2_t *frame = malloc(sizeof(NDIlib_video_frame_v2_t));
    frame->FourCC               = (NDIlib_FourCC_video_type_e)NDIlib_FourCC_video_type_ex_H264_highest_bandwidth;
    frame->xres                 = 1280;
    frame->yres                 = 720;
    frame->p_data               = NULL;
    frame->data_size_in_bytes   = 0;
    frame->frame_format_type    = NDIlib_frame_format_type_progressive;
    frame->picture_aspect_ratio = (float)1280 / (float)720;
//            frame.timecode = framePkt->pts;
    
//    NDIlib_frame_scatter_t   highQ_scatter = { p_data_blocks,  p_data_blocks_size };
     NDIlib_frame_scatter_t *  highQ_scatter = malloc(sizeof(NDIlib_frame_scatter_t));
    highQ_scatter->p_data_blocks = p_data_blocks;
    highQ_scatter->p_data_blocks_size = p_data_blocks_size;

    NDIlib_send_send_video_scatter_async(self.pSend, frame, highQ_scatter);
}

@end
