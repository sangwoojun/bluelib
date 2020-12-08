#include <stdio.h>
#include <stdint.h>


extern "C" void bdpi_read_file(uint32_t* returnptr, uint32_t offset) {
	FILE* fin = fopen("/mnt/hdd0/data/hpc4/compressed0000.bin", "rb");
	fseek(fin, offset, SEEK_SET);
	fread(returnptr, 4, 4, fin);
	fclose(fin);
	//for ( int i = 0; i < (16/4); i++ ) returnptr[i] = 0;
}

extern "C" void bdpi_compare_file(uint32_t* data, uint32_t offset) {
	for ( int i = 0; i < 16; i++ ) {
		if ( ((char*)data)[i] == 0 ) break;
		printf( "%c", ((char*)data)[i] );
	}
}
