#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

#define INPUT_DATE_BYTES (1024*1024*32)

uint32_t* g_input_data = NULL;
uint32_t* g_output_data = NULL;

bool g_simdone = false;

void init() {
	if ( g_input_data != NULL ) return;

	g_input_data = (uint32_t*)malloc(INPUT_DATE_BYTES);
	g_output_data = (uint32_t*)malloc(INPUT_DATE_BYTES);

	srand(time(NULL));
	for ( size_t i = 0; i < INPUT_DATE_BYTES/sizeof(uint32_t); i++ ) {
		//g_input_data[i] = (rand()&0xffffff) + ((rand()%32)<<25);
		g_input_data[i] = rand();
		g_output_data[i] = rand();
	}
}

extern "C" uint32_t bdpi_readinput(uint32_t addr) {
	init();

	return g_input_data[addr];
}
extern "C" void bdpi_writeoutput(uint32_t addr, uint32_t data) {
	init();

	if ( g_simdone ) {
		//printf( "Output received after simulation finished!\n" );
		//fflush(stdout);
	}
	g_output_data[addr] = data;
}

extern "C" void bdpi_verify(uint32_t cnt_, uint32_t cycles) {
	uint32_t cnt = cnt_ * 4;
	printf( "Verifying %d output from %d cycles\n", cnt, cycles );

	uint32_t total_buckets = 0;
	uint32_t last_bucket = 0;
	uint32_t burst_len = 0;
	for ( size_t i = 0; i < (size_t)cnt; i++ ) {
		uint32_t cur = g_output_data[i];
		uint32_t bucket = cur % 128; //(cur>>(32-7));
		if ( bucket != last_bucket ) {
			last_bucket = bucket;
			burst_len = 0;
			total_buckets ++;
		}
		burst_len ++;
	}

	printf( "Bucket cnt: %d\n", total_buckets );
	printf( "Average elements per bucket: %d\n", cnt/total_buckets );
	g_simdone = true;
}
