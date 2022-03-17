#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define FILTER_WORDS (3*3*3+1)

int main(int argc, char** argv) {
	if ( argc < 2 ) {
		printf("usage: %s [weights_32f]\n", argv[0]);
		exit(1);
	}
	
	int blockbits = 8+(9*5); 

	printf( "Compressing to 3x3 MSFP12.\nEach block is %d bits\n", blockbits );
	printf( "Each sign+frac takes 5 bits (1 sign + 4 frac)\n4 bit frac to add back the normally omitted 1 bit for shifting\n\n" );

	FILE* fin = fopen(argv[1], "rb");

	float filter[FILTER_WORDS];
	int filtercnt = 0;
	while (!feof(fin) && filtercnt < 1) {
		filtercnt++;

		fread(filter, FILTER_WORDS*sizeof(float), 1, fin);


		for ( int i = 0; i < 3; i++ ) { // three channels
			float* cf = filter+(i*3*3);
			uint32_t* ci = (uint32_t*)cf;
			uint32_t maxexp = 0;
			for ( int j = 0; j < 9; j++ ) {
				uint32_t exp = (ci[i]>>23)&0xff;
				if ( exp > maxexp) {
					maxexp = exp;
				}
			}
			uint64_t payload = 0;
			for ( int j = 0; j < 9; j++ ) {
				//printf( "%f\n", cf[j] );
				uint32_t exp = (ci[j]>>23)&0xff;
				uint32_t fra = (ci[j]&((1<<23)-1)) | (1<<23); //adding back the omitted MSB 1
				uint32_t sign = (ci[j]>>31);
				if ( exp < maxexp ) {
					uint32_t expd = maxexp-exp;
					fra = (fra>>expd);
				}
				uint64_t newfra = (sign<<4) | (fra>>(23-3)); 
				//payload = (payload<<5) | newfra[j];
				payload |= (newfra<<(j*5));
				//printf( "%d %d\n",sign, fra );
			}

			printf( "%d'h%015lx\n",blockbits, (payload<<8)|maxexp );
			printf( "%d -> %d\n", maxexp, (((int)maxexp)-127) );
		}
	}
}
