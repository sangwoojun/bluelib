#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

extern "C" uint32_t bdpi_sqrt32(uint32_t data) {
	float r = sqrt(*(float*)&data);
	return *(uint32_t*)&r;
}
extern "C" uint64_t bdpi_sqrt64(uint64_t data) {
	double r = sqrt(*(double*)&data);
	printf( "sqrt bdpi called %lf\n", r );
	return *(uint64_t*)&r;
}
