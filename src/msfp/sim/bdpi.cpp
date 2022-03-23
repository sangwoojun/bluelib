#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>



float channel1[9] = {
1,1,1,1,1,1,1,1,1
};
//53'h01abcb223c54a7d
//125 -> -2
float channel2[9] = {
1,1,1,1,1,1,1,1,1
};
//53'h01eccb634c5ae7d
//125 -> -2
float channel3[9] = {
1,1,1,1,1,1,1,1,1
};
//53'h01dc674c46d8c7a
//122 -> -5

/*
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
//53'h01abcb223c54a7d
//125 -> -2
float channel2[9] = {
0.464184,
0.418108,
-0.048069,
0.305112,
0.103854,
-0.373141,
-0.076468,
-0.310707,
-0.464537
};
//53'h01eccb634c5ae7d
//125 -> -2
float channel3[9] = {
0.394167,
0.377403,
-0.045949,
0.267130,
0.099864,
-0.341009,
-0.075736,
-0.280342,
-0.416023
};
//53'h01dc674c46d8c7a
//122 -> -5
*/

uint8_t testinput[9] = {
	255,
	255,
	255,

	255,
	255,
	255,
	
	255,
	255,
	255
};

/*
uint8_t testinput[9] = {
	5,
	250,
	64,

	82,
	24,
	240,

	0,
	1,
	82
};
*/

extern "C" uint32_t bdpi_readinput(uint32_t addr, uint32_t offset) {
	return (testinput[2+offset]<<16)|(testinput[1+offset]<<8)|testinput[0+offset];
}
extern "C" void bdpi_writeoutput(uint64_t data) { // 3 bfloat16
	float fi[9];
	float* fw[3] = {channel1, channel2,channel3};
	for ( int i = 0; i < 9; i++ ) fi[i] = ((float)testinput[i])/256;

	float colsums[3] = {0};
	for ( int i = 0; i < 3; i++ ) { // channels
		for ( int col = 0; col < 3; col ++ ) { // cols
			for ( int row = 0; row < 3; row ++ ) { // rows
				colsums[col] += fi[i*3+row]*fw[i][row*3+col];
			}
		}
	}

	uint32_t da[3] = {0};
	uint32_t d0 = data&0xffff;
	uint32_t d1 = (data>>16)&0xffff;
	uint32_t d2 = (data>>32)&0xffff;
	da[0] = d0; da[1] = d1; da[2] = d2;

	for ( int i = 0; i < 3; i++ ) {
		da[i] <<= 16; // back to float32
	}






	//printf( "Orig: %f %f %f\n", a0+b0+c0, a1+b1+c1, a2+b2+c2 );
	printf( "Orig: %f %f %f\n", colsums[0], colsums[1], colsums[2] );
	printf( "Core: %f %f %f\n", *(float*)&da[0],*(float*)&da[1],*(float*)&da[2] );
}
