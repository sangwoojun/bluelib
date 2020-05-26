#!/bin/bash
rm -rf vc707

vivado -mode batch -source synth-fp-vc707.tcl -nolog -nojournal
vivado -mode batch -source synth-cordic-vc707.tcl -nolog -nojournal
vivado -mode batch -source synth-divisor-vc707.tcl -nolog -nojournal

