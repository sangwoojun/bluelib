#!/bin/bash
rm -rf kc705

vivado -mode batch -source synth-fp-kc705.tcl -nolog -nojournal

#mv kc705/fp_add32/fp_add32.xci kc705/
#mv kc705/fp_sub32/fp_sub32.xci kc705/
#mv kc705/fp_mult32/fp_mult32.xci kc705/
#mv kc705/fp_div32/fp_div32.xci kc705/
#
#mv kc705/fp_add64/fp_add64.xci kc705/
#mv kc705/fp_sub64/fp_sub64.xci kc705/
#mv kc705/fp_mult64/fp_mult64.xci kc705/
#mv kc705/fp_div64/fp_div64.xci kc705/
#
#mv kc705/fp_add32/fp_add32.dcp kc705/
#mv kc705/fp_sub32/fp_sub32.dcp kc705/
#mv kc705/fp_mult32/fp_mult32.dcp kc705/
#mv kc705/fp_div32/fp_div32.dcp kc705/
#
#mv kc705/fp_add64/fp_add64.dcp kc705/
#mv kc705/fp_sub64/fp_sub64.dcp kc705/
#mv kc705/fp_mult64/fp_mult64.dcp kc705/
#mv kc705/fp_div64/fp_div64.dcp kc705/
#
#rm -rf kc705/fp_add32
#rm -rf kc705/fp_sub32
#rm -rf kc705/fp_mult32
#rm -rf kc705/fp_div32
#rm -rf kc705/fp_add64
#rm -rf kc705/fp_sub64
#rm -rf kc705/fp_mult64
#rm -rf kc705/fp_div64

#vivado -mode batch -source synth-cordic.tcl -nolog -nojournal
#mv core/cordic_sincos/cordic_sincos.xci core/
#mv core/cordic_sincos/cordic_sincos.dcp core/
##rm -rf core/cordic_sincos
#mv core/cordic_atan/cordic_atan.xci core/
#mv core/cordic_atan/cordic_atan.dcp core/
##rm -rf core/cordic_atan
