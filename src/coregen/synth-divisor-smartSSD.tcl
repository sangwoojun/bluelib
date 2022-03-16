proc genDivisorCore {corename propertyList} {
	set coredir "./smartSSD"
	file mkdir $coredir
	if [file exists ./$coredir/$corename] {
		file delete -force ./$coredir/$corename
	}

	create_project -name local_synthesized_ip -in_memory -part xcku15p-ffva1156-2LV-e 
	create_ip -name div_gen -version 5.1 -vendor xilinx.com -library ip -module_name $corename -dir ./$coredir
	set_property -dict $propertyList [get_ips $corename]

	generate_target {instantiation_template} [get_files ./$coredir/$corename/$corename.xci]
	generate_target all [get_files  ./$coredir/$corename/$corename.xci]
	create_ip_run [get_files -of_objects [get_fileset sources_1] ./$coredir/$corename/$corename.xci]
	generate_target {Synthesis} [get_files  ./$coredir/$corename/$corename.xci]
	read_ip ./$coredir/$corename/$corename.xci
	synth_ip [get_ips $corename]
}

genDivisorCore "udiv32" [list CONFIG.Component_Name {udiv32_high} CONFIG.algorithm_type {Radix2} CONFIG.dividend_and_quotient_width {32} CONFIG.divisor_width {32} CONFIG.remainder_type {Remainder} CONFIG.operand_sign {Unsigned} CONFIG.divisor_width {32} CONFIG.fractional_width {32} CONFIG.latency {34}]
