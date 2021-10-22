#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>






float fixed_to_float(uint32_t fixed, int bits, int intbits) {
	fixed = (fixed&((1<<bits)-1));
	bool sign = (fixed>>(bits-1));

	float ret = 0;
	if ( sign ) {
		uint32_t fixedneg = ((~fixed)+1)&((1<<bits)-1);
		//uint32_t fixedneg = (~fixed)+1;
		ret = -((float)fixedneg)/(1<<(bits-intbits));
	}
	else {
		ret = ((float)fixed)/(1<<(bits-intbits));
	}

	return ret;
}

uint32_t float_to_fixed(float radian, int bits, int intbits) {
	uint32_t integer_portion = (uint32_t)radian;
	uint32_t frac_portion = (uint32_t)((radian - integer_portion) * (1<<(bits-intbits)));
	uint32_t fixed = (integer_portion<<(bits-intbits))|frac_portion;

	return fixed&((1<<bits)-1);
}


extern "C" uint32_t bdpi_sqrt32(uint32_t data) {
	float r = sqrt(*(float*)&data);
	return *(uint32_t*)&r;
}
extern "C" uint64_t bdpi_sqrt64(uint64_t data) {
	double r = sqrt(*(double*)&data);
	//printf( "sqrt bdpi called %lf\n", r );
	return *(uint64_t*)&r;
}


extern "C" uint32_t bdpi_sincos(uint32_t data) {
	// input: phase in radians
	// only lower 16 bits are valid
	// fixed point, 3 bit integer part, 16-3=13 bit fraction
	// output: {sin,cos} 16 bits each, 2 bits integer fixed point
	float fdata = fixed_to_float(data, 16, 3);
	float fsin = sin(fdata);
	float fcos = cos(fdata);
	printf( "--- %f %f\n", fsin, fcos );
	return (float_to_fixed(fsin, 16, 2)<<16) | float_to_fixed(fcos, 16, 2);
}

extern "C" uint32_t bdpi_atan(uint32_t x, uint32_t y) {
	// input: cartesian, only 16 bits are valid for both x and y
	// fixed point, 2 bit integer part
	// output: atan, 16 bits, 3 bits integer part
	float fx = fixed_to_float(x, 16, 2);
	float fy = fixed_to_float(y, 16, 2);
	float fatan = atan2(fy, fx);
	printf( "--atan- %f\n", fatan );
	return float_to_fixed(fatan, 16, 3);
}

extern "C" uint32_t bdpi_divisor(uint32_t a, uint32_t b) {
	return a/b;
}
extern "C" uint32_t bdpi_divisor_remainder(uint32_t a, uint32_t b) {
	return a%b;
}

extern "C" uint32_t bdpi_divisor_float(uint32_t a, uint32_t b) {
	float ad = *((float*)&a);
	float bd = *((float*)&b);
	float rd = ad/bd;
	uint32_t r = *((uint32_t*)&rd);

	return r;
}

extern "C" uint64_t bdpi_mult_double(uint64_t a, uint64_t b) {
	double ad = *((double*)&a);
	double bd = *((double*)&b);
	double rd = ad*bd;
	uint64_t r = *((uint64_t*)&rd);

	return r;
}

extern "C" uint64_t bdpi_divisor_double(uint64_t a, uint64_t b) {
	double ad = *((double*)&a);
	double bd = *((double*)&b);
	double rd = ad/bd;
	uint64_t r = *((uint64_t*)&rd);

	return r;
}

extern "C" uint32_t bdpi_sqrt_cube32(uint32_t data) {
	float r = powf(*((float*)&data), 3.0/2.0);
	return *((uint32_t*)&r);
}
