//
//  MAPeelVideoWindowController.m
//  MacTest
//
//  Created by 马英伦 on 2020/4/10.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MAMyPeelVideoWindowController.h"
#import <ffmpegmac/libavutil/log.h>
#import <ffmpegmac/libavformat/avformat.h>

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

@interface MAMyPeelVideoWindowController ()

@end

@implementation MAMyPeelVideoWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test2" ofType:@"mp4"];
    [self peelVideo:filePath];
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
        
        unsigned long start = out->size;
        unsigned long end = out->size;
        
        AVPacket spspssPkt;
        if (pkt_type == 5)
        {
            
            err = [self h264_extradata_to_annexb:fmt_ctx->streams[in->stream_index]->codecpar->extradata extraDataSize:fmt_ctx->streams[in->stream_index]->codecpar->extradata_size out_extradata:&spspssPkt pading:AV_INPUT_BUFFER_PADDING_SIZE];
            if (err < 0) return err;
            end = out->size;
            if (1508 > *length + start && 1508 < *length + end)
            {
                NSLog(@"mayinglun log 1");
            }
            start =  out->size;
            err = [self copyPacket:out spsPps:spspssPkt.data size:spspssPkt.size];
            if (err < 0) return err;
            end = out->size;
            if (1508 > *length + start && 1508 < *length + end)
            {
                NSLog(@"mayinglun log 2");
            }
            start =  out->size;
            err = [self copyPacket:out data:buf size:frameDataLength shortHeader:YES];
            if (err < 0) return err;
            end = out->size;
            if (1508 > *length + start && 1508 < *length + end)
            {
                NSLog(@"mayinglun log 3:%lu   %lu  %lu", out->size, *length + start, *length + end);
            }
            start =  out->size;
        } else {
            err = [self copyPacket:out data:buf size:frameDataLength shortHeader:NO];
            if (err < 0) return err;
            end = out->size;
            if (1508 > *length + start && 1508 < *length + end)
            {
                NSLog(@"mayinglun log 4:%lu   %lu  %lu", out->size, *length + start, *length + end);
                
            }
            start =  out->size;
        }
        
        buf += frameDataLength;
        
        *length += out->size;
        
        unsigned long len = fwrite(out->data, 1, out->size, dst_fd);
        if(len != out->size){
            av_log(NULL, AV_LOG_DEBUG, "warning, length of writed data isn't equal pkt.size(%lu, %d)\n",
                    len,
                    out->size);
        }
        fflush(dst_fd);
        
//        free(out.data);
        
    } while (buf < in->data + in->size);
    
    av_packet_unref(out);
    
//    fmt_ctx->streams[in->stream_index]->codecpar->extradata

    return 0;
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
