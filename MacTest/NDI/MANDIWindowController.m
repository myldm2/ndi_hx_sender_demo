//
//  MANDIWindowController.m
//  MacTest
//
//  Created by 马英伦 on 2020/7/16.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MANDIWindowController.h"
#import <ffmpegmac/libavutil/log.h>
#import <ffmpegmac/libavformat/avformat.h>
#include "Processing.NDI.Lib.h"
#include "Processing.NDI.Send.h"
#include "Processing.NDI.utilities.h"
#include "Processing.NDI.Embedded.h"

#ifndef AV_WB32
#   define AV_WB32(p, val) do {                 \
        uint32_t d = (val);                     \
        ((uint8_t*)(p))[3] = (d);               \
        ((uint8_t*)(p))[2] = (d)>>8;            \
        ((uint8_t*)(p))[1] = (d)>>16;           \
        ((uint8_t*)(p))[0] = (d)>>24;           \
    } while(0)
#endif

#ifndef AV_RB16
#   define AV_RB16(x)                           \
    ((((const uint8_t*)(x))[0] << 8) |          \
      ((const uint8_t*)(x))[1])
#endif

@interface MANDIWindowController ()

@property (nonatomic) NDIlib_send_instance_t pSend;

@end

@implementation MANDIWindowController

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
        create_params_Send.clock_video = false;
        create_params_Send.clock_audio = false;
        self.pSend = NDIlib_send_create(&create_params_Send);
        
        NDIlib_send_send_video_scatter(self.pSend, NULL, NULL);

        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test2" ofType:@"mp4"];
        [self peelVideo:filePath];
        
        NDIlib_send_send_video_scatter(self.pSend, NULL, NULL);
        
        NDIlib_send_destroy(self.pSend);
    });
    
}

- (int)h264_mp4toannexb:(AVFormatContext *)fmt_ctx packet:(AVPacket *)in file:(FILE *)dst_fd length:(unsigned long *)length
{
    const uint8_t *buf = in->data;
    AVPacket *out = av_packet_alloc();
    do {
        
        if (buf + 5 > in->data + in->size)
        {
            av_log(NULL, AV_LOG_ERROR, "packet data error \n");
            return -1;
        }
        
        uint32_t frameDataLength = 0;
        for (int i = 0; i < 4; i ++)
        {
            frameDataLength = (frameDataLength << 8 | buf[i]);
        }
        
        buf += 4;
        
        uint8 pkt_type = buf[0];
        pkt_type = (pkt_type & 0x1f);
        
//        buf ++;
        
        int err = 0;
        
        AVPacket spspssPkt;
        if (pkt_type == 5)
        {
//            NSLog(@"mayinglun log:%d", pkt_type);
            err = [self h264_extradata_to_annexb:fmt_ctx->streams[in->stream_index]->codecpar->extradata extraDataSize:fmt_ctx->streams[in->stream_index]->codecpar->extradata_size out_extradata:&spspssPkt pading:AV_INPUT_BUFFER_PADDING_SIZE];
            if (err < 0) return err;
            
//            NSMutableString *h264BufferText = [NSMutableString new];
//            for (int index = 0; index < spspssPkt.size; ++index) {
//                [h264BufferText appendFormat:index % 16 == 15 ? @"%@%02x, \n" : @"%@%02x, ", @"0x", spspssPkt.data[index]];
//            }
//            NSLog(@"h264Buffer: %@", h264BufferText);
            
            err = [self copyPacket:out spsPps:spspssPkt.data size:spspssPkt.size];
            if (err < 0) return err;

            err = [self copyPacket:out data:buf size:frameDataLength shortHeader:YES];
            if (err < 0) return err;
            
            
            AVPacket *send = av_packet_alloc();
            
            err = [self copyPacket:send spsPps:spspssPkt.data size:spspssPkt.size];
            if (err < 0) return err;

            err = [self copyPacket:send data:buf size:frameDataLength shortHeader:YES];
            if (err < 0) return err;
            
            send->pts = in->pts;
            send->dts = in->dts;
            
            
            [self sendFrameData:send keyFrame:1];
            
            av_packet_unref(send);

        } else if (pkt_type == 1) {
            
            err = [self copyPacket:out data:buf size:frameDataLength shortHeader:NO];
            if (err < 0) return err;
            
            AVPacket *send = av_packet_alloc();
            
            err = [self copyPacket:send data:buf size:frameDataLength shortHeader:YES];
            if (err < 0) return err;
            
            send->pts = in->pts;
            send->dts = in->dts;
            
            [self sendFrameData:send keyFrame:0];
            
            av_packet_unref(send);
            
        } else {
            err = [self copyPacket:out data:buf size:frameDataLength shortHeader:NO];
            if (err < 0) return err;
        }
        
        NSLog(@"mayinglun log:%d", pkt_type);
        
        buf += frameDataLength;
        
        *length += out->size;
        
        unsigned long len = fwrite(out->data, 1, out->size, dst_fd);
        if(len != out->size){
            av_log(NULL, AV_LOG_DEBUG, "warning, length of writed data isn't equal pkt.size(%lu, %d)\n",
                    len,
                    out->size);
        }
        fflush(dst_fd);
        
        [NSThread sleepForTimeInterval:0.01];
        
//        free(out.data);
        
    } while (buf < in->data + in->size);
    
    av_packet_unref(out);
    
//    fmt_ctx->streams[in->stream_index]->codecpar->extradata

    return 0;
}

- (void)sendFrameData:(AVPacket *)framePkt keyFrame:(int)keyframe
{
    NDIlib_video_frame_v2_t frame;
    frame.FourCC               = (NDIlib_FourCC_video_type_e)NDIlib_FourCC_video_type_ex_H264_highest_bandwidth;
    frame.xres                 = 1280;
    frame.yres                 = 720;
    frame.p_data               = NULL;
    frame.data_size_in_bytes   = 0;
    frame.frame_format_type    = NDIlib_frame_format_type_progressive;
    frame.picture_aspect_ratio = (float)1280 / (float)720;
    frame.timecode = framePkt->pts;
    
    NDIlib_compressed_packet_t packet;
    packet.version         = sizeof(NDIlib_compressed_packet_t);
    packet.pts             = framePkt->pts;
    packet.dts             = framePkt->dts;
    packet.flags           = keyframe;
    packet.data_size       = framePkt->size;
    packet.extra_data_size = 0;
    packet.fourCC          = NDIlib_compressed_FourCC_type_H264;
    
    AVPacket *send = av_packet_alloc();
    int headerSize = sizeof(NDIlib_compressed_packet_t);
    av_grow_packet(send, framePkt->size + headerSize);
    memcpy(send->data, (uint8_t*)&packet, headerSize);
    memcpy(send->data + headerSize, framePkt->data, framePkt->size);
    
    uint8_t* p_data_blocks[2] = {NULL};
    p_data_blocks[0] = (uint8_t*)(send->data);
    int p_data_blocks_size[2] = {0};
    p_data_blocks_size[0] = send->size;
    NDIlib_frame_scatter_t   highQ_scatter = { p_data_blocks,  p_data_blocks_size };
    
    NDIlib_send_send_video_scatter(self.pSend, &frame, &highQ_scatter);
    
    av_packet_unref(send);
}

- (int)h264_extradata_to_annexb:(const uint8_t *)codec_extradata extraDataSize:(const int)codec_extradata_size out_extradata:(AVPacket *)out_extradata pading:(int)padding
{
    uint8_t *out = NULL;
    uint32_t total_size = 0;
    static const uint8_t nalu_header[4] = { 0, 0, 0, 1 };
    
    const uint8_t *extradata = codec_extradata;
    extradata += 4;
    extradata++;
//    uint32_t spspss_data_length = *extradata++ & 0x3;
    uint32_t sps_nb = *extradata++ & 0x1f;
    int err = 0;
    
    while (sps_nb --) {
        
        uint16_t sps_unit_length = AV_RB16(extradata);
        extradata += 2;
        
        if (extradata + sps_unit_length > codec_extradata + codec_extradata_size)
        {
            if (out) free(out);
            return -1;
        }
        
        total_size += sps_unit_length + 4;
        
        if ((err = av_reallocp(&out, total_size + padding)) < 0)
        {
            if (out) free(out);
            return err;
        }
        
        memcpy(out + total_size - sps_unit_length - 4, nalu_header, 4);
        memcpy(out + total_size - sps_unit_length, extradata, sps_unit_length);
        extradata += sps_unit_length;
        
    }
    
    uint32_t pss_nb = *extradata++ & 0x1f;
    
    while (pss_nb --) {
        
        uint16_t pss_unit_length = AV_RB16(extradata);
        extradata += 2;
        
        if (extradata + pss_unit_length > codec_extradata + codec_extradata_size)
        {
            if (out) free(out);
            return -1;
        }
//        NSLog(@"mayinglun log:%d", pss_unit_length);
        
        total_size += pss_unit_length + 4;
        
        if ((err = av_reallocp(&out, total_size + padding)) < 0)
        {
            free(out);
            return err;
        }
        
        memcpy(out + total_size - pss_unit_length - 4, nalu_header, 4);
        memcpy(out + total_size - pss_unit_length, extradata, pss_unit_length);
        extradata += pss_unit_length;
        
        
        
    }
    
//    NSData *data1 = [[NSData alloc] initWithBytes:out length:total_size];
//    NSLog(@"%@", data1);
    
//    if (out) memset(out + total_size - padding, 0, padding);
    
//    NSData *data2 = [[NSData alloc] initWithBytes:out length:total_size];
//    NSLog(@"%@", data2);
    
    out_extradata->data = out;
    out_extradata->size = total_size;
    
    return err;
}

- (int)peelVideo:(NSString*)filePath
{
    NSString *dicPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Test"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dicPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *targetPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Test/test2.h264"];

    int err_code;
    char errors[1024];

    const char *src_filename = filePath.UTF8String;
    const char *dst_filename = targetPath.UTF8String;

    FILE *dst_fd = NULL;

    int video_stream_index = -1;

    //AVFormatContext *ofmt_ctx = NULL;
    //AVOutputFormat *output_fmt = NULL;
    //AVStream *out_stream = NULL;

    AVFormatContext *fmt_ctx = NULL;
    AVPacket pkt;

    //AVFrame *frame = NULL;

//    av_log_set_level(AV_LOG_DEBUG);

    if(src_filename == NULL || dst_filename == NULL){
        av_log(NULL, AV_LOG_ERROR, "src or dts file is null, plz check them!\n");
        goto fail;
    }

    /*register all formats and codec*/
    av_register_all();

    dst_fd = fopen(dst_filename, "wb");
    if (!dst_fd) {
        av_log(NULL, AV_LOG_DEBUG, "Could not open destination file %s\n", dst_filename);
        goto fail;
    }

    int ret = 0;
    ret = avformat_open_input(&fmt_ctx, src_filename, NULL, NULL);
    if (ret < 0)
    {
        av_log(NULL, AV_LOG_ERROR, " %s\n", dst_filename);
        goto fail;
    }
    
    int best_stream = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (best_stream < 0)
    {
        av_log(NULL, AV_LOG_ERROR, "find best stream error %s", dst_filename);
        goto fail;
    }
    
    unsigned long length = 0;
    
    while (av_read_frame(fmt_ctx, &pkt) >= 0) {
        
        if (best_stream == pkt.stream_index)
        {
            [self h264_mp4toannexb:fmt_ctx packet:&pkt file:dst_fd length:&length];
        }
        av_packet_unref(&pkt);
    }
    
fail:
    if (fmt_ctx)
    {
        avformat_close_input(&fmt_ctx);
        fmt_ctx = NULL;
    }
    if (dst_fd)
    {
        fclose(dst_fd);
        dst_fd = NULL;
    }
    return -1;
}

- (int)copyPacket:(AVPacket *)out spsPps:(const uint8_t *)sps_pps size:(uint32_t)sps_pps_size
{
    uint32_t offset         = out->size;
    int err;
    err = av_grow_packet(out, sps_pps_size);
    if (err < 0)
    {
        return err;
    }
    memcpy(out->data + offset, sps_pps, sps_pps_size);
    return 0;
}

- (int)copyPacket:(AVPacket *)out data:(const uint8_t *)data size:(uint32_t)size shortHeader:(BOOL)shortHeader
{
    uint32_t offset         = out->size;
    uint8_t nal_header_size = 4;
    int err;
    err = av_grow_packet(out, nal_header_size + size);
    if (err < 0)
    {
        return err;
    }
//    if (0 == offset)
    if (offset == 0 || shortHeader)
    {
        out->data[offset + 0] = 0;
        out->data[offset + 1] = 0;
        out->data[offset + 2] = 0;
        out->data[offset + 3] = 1;
    } else {
        out->data[offset + 0] = 0;
        out->data[offset + 1] = 0;
        out->data[offset + 2] = 1;
        out->data[offset + 3] = 0;
    }
    memcpy(out->data + offset + nal_header_size, data, size);
    return 0;
}

@end

