
proc genCordicCore {corename propertyList} {
	set coredir "./kc705"
	file mkdir $coredir
	if [file exists ./$coredir/$corename] {
		file delete -force ./$coredir/$corename
	}

	create_project -name local_synthesized_ip -in_memory -part xc7k325tffg900-2
	set_property board_part xilinx.com:kc705:part0:1.5 [current_project]

	create_ip -name cordic -version 6.0 -vendor xilinx.com -library ip -module_name $corename -dir ./$coredir
	set_property -dict $propertyList [get_ips $corename]

	generate_target {instantiation_template} [get_files ./$coredir/$corename/$corename.xci]
	generate_target all [get_files  ./$coredir/$corename/$corename.xci]
	create_ip_run [get_files -of_objects [get_fileset sources_1] ./$coredir/$corename/$corename.xci]
	generate_target {Synthesis} [get_files  ./$coredir/$corename/$corename.xci]
	read_ip ./$coredir/$corename/$corename.xci
	synth_ip [get_ips $corename]
}

genCordicCore "cordic_sincos" [list CONFIG.Component_Name {cordic_sincos} CONFIG.Functional_Selection {Sin_and_Cos} CONFIG.Round_Mode {Truncate} CONFIG.Data_Format {SignedFraction} CONFIG.flow_control {Blocking} CONFIG.out_tready {true}]
genCordicCore "cordic_atan" [list CONFIG.Component_Name {cordic_atan} CONFIG.Functional_Selection {Arc_Tan} CONFIG.Data_Format {SignedFraction} CONFIG.flow_control {Blocking} CONFIG.out_tready {true}]
