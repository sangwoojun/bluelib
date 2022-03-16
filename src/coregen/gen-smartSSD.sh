#!/bin/bash
rm -rf smartSSD

vivado -mode batch -source synth-fp-smartSSD.tcl -nolog -nojournal
vivado -mode batch -source synth-cordic-smartSSD.tcl -nolog -nojournal
vivado -mode batch -source synth-divisor-smartSSD.tcl -nolog -nojournal

