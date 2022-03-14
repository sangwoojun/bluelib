#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

float channel1[9] = {
0.341195,
0.339992,
-0.044844,
0.232159,
0.089782,
-0.303314,
-0.072609,
-0.246675,
-0.336833
};

uint8_t testinput[3] = {
	5,
	200,
	2
};

extern "C" uint32_t bdpi_readinput(uint32_t addr) {
	return (testinput[2]<<16)|(testinput[1]<<8)|testinput[0];
}
extern "C" void bdpi_writeoutput(uint64_t data) { // 3 bfloat16
	float t0 = ((float)testinput[0])/256;
	float t1 = ((float)testinput[1])/256;
	float t2 = ((float)testinput[2])/256;

	float r0 = t0*channel1[0] + t1*channel1[3] + t2*channel1[6];
	float r1 = t0*channel1[1] + t1*channel1[4] + t2*channel1[7];
	float r2 = t0*channel1[2] + t1*channel1[5] + t2*channel1[8];

	uint32_t da[3] = {0};
	uint32_t d0 = data&0xffff;
	uint32_t d1 = (data>>16)&0xffff;
	uint32_t d2 = (data>>32)&0xffff;
	da[0] = d0; da[1] = d1; da[2] = d2;

	for ( int i = 0; i < 3; i++ ) {
		uint32_t d0 = da[i];
		uint32_t sign = 1&(d0>>15);
		uint32_t mantissa = d0&((1<<7)-1);
		uint32_t exp = (d0>>7)&0xff;
		int shamt = 0;
		while ( 1&(mantissa>>7) == 0 && shamt < 7 ) { // shift by 7 to account for the MSB 1, which will be truncated later
			shamt++;
			mantissa <<= 1;
			printf( "s" );
		}
		printf( "\n" );
		mantissa &= ((1<<7)-1);
		da[i] = (sign<<15)|((exp-shamt+2)<<7)|mantissa;
		da[i] <<= 16; // back to float32
	}






	printf( "Orig: %f %f %f\n", r0, r1, r2 );
	printf( "Core: %f %f %f\n", *(float*)&da[0],*(float*)&da[1],*(float*)&da[2] );
	exit(0);

	

}
