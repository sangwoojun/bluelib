#include <stdio.h>
#include <stdint.h>


extern "C" void bdpi_read_file(uint32_t* returnptr, uint32_t offset) {
	for ( int i = 0; i < (16/4); i++ ) returnptr[i] = 0;
}

extern "C" void bdpi_compare_file(uint32_t* data, uint32_t offset) {
	printf( "%x--(%d)\n", data, offset );
}
