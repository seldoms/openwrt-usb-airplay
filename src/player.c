#include "libmaru.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <soxr.h>
int main(int argc,char **argv) {
 maru_context *ctx=NULL;
 struct maru_stream_desc want={.sample_rate=48000,.channels=2,.bits=16};
 maru_error e=maru_create_context_from_vid_pid(&ctx,0xe5b7,0x0811,&want);
 if(e){fprintf(stderr,"USB init failed: %d\n",e);return 1;}
 fprintf(stderr,"USB audio initialized, streams=%u\n",maru_get_num_streams(ctx));
 if(argc>1 && !strcmp(argv[1],"--probe")){maru_destroy_context(ctx);return 0;}
 int stream=maru_find_available_stream(ctx);
 want.buffer_size=32768;want.fragment_size=4096;
 if(stream<0 || (e=maru_stream_open(ctx,stream,&want))){fprintf(stderr,"stream open failed: %d\n",e);return 2;}
 int16_t buf[2048];
 if(argc>1 && !strcmp(argv[1],"--tone")){
  for(int frame=0;frame<48000;){int n=48000-frame;if(n>1024)n=1024;
   for(int j=0;j<n;j++){double fade=fmin(1.0,fmin((frame+j)/2400.0,(48000-frame-j)/2400.0));int16_t v=500*fade*sin(2*3.141592653589793*440*(frame+j)/48000);buf[2*j]=buf[2*j+1]=v;}
   if(maru_stream_write(ctx,stream,buf,n*4)!=n*4)return 3;frame+=n;
  }
 } else {
 soxr_error_t err;soxr_io_spec_t io=soxr_io_spec(SOXR_INT16_I,SOXR_INT16_I);
 soxr_t rs=soxr_create(44100,48000,2,&err,&io,NULL,NULL);
 if(!rs){fprintf(stderr,"resampler: %s\n",err);return 4;}
 unsigned char input[8192];size_t carry=0;ssize_t n;
 while((n=read(0,input+carry,sizeof(input)-carry))>0){
  size_t bytes=carry+n,frames=bytes/4,used=0;
  while(used<frames){size_t idone=0,odone=0;
   err=soxr_process(rs,input+used*4,frames-used,&idone,buf,1024,&odone);
   if(err || (!idone&&!odone))return 4;
   if(odone && maru_stream_write(ctx,stream,buf,odone*4)!=odone*4)return 3;
   used+=idone;
  }
  carry=bytes%4;memmove(input,input+bytes-carry,carry);
 }
 soxr_delete(rs);
 }
 usleep(250000);maru_stream_close(ctx,stream);maru_destroy_context(ctx);return 0;
}
