set script_dir [file dirname [file normalize [info script]]]
set design_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $design_dir vivado_project]
set project_name fpga_gigabit_ethernet_pynq
set target [string tolower [lindex $argv 0]]
if {$target eq ""} {
    set target prepare
}

if {$target ni {prepare synth impl timing bitstream sim}} {
    error "Usage: vivado -mode batch -source build_project.tcl -tclargs prepare|synth|impl|timing|bitstream|sim"
}

create_project -force $project_name $project_dir -part xc7z020clg400-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [list \
    [file join $design_dir rtl crc32_d8.v] \
    [file join $design_dir rtl rgmii_to_gmii.v] \
    [file join $design_dir rtl arp_cache_engine.v] \
    [file join $design_dir rtl udp_ip_tx.v] \
    [file join $design_dir rtl udp_ip_rx.v] \
    [file join $design_dir rtl axis_packet_generator.v] \
    [file join $design_dir rtl mac_ip_udp_axis_top.v]]
add_files -norecurse $rtl_files
add_files -fileset constrs_1 -norecurse \
    [file join $design_dir constraints pynq_z2_ethernet.xdc]
add_files -fileset sim_1 -norecurse \
    [file join $design_dir sim tb_mac_ip_udp.v]

set_property top mac_ip_udp_axis_top [get_filesets sources_1]
set_property top tb_mac_ip_udp [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {$target eq "prepare"} {
    puts "Project prepared at $project_dir for external PL-connected RGMII PHY."
} elseif {$target eq "sim"} {
    launch_simulation
    run all
} else {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
        error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
    }
    if {$target ne "synth"} {
        launch_runs impl_1 -to_step route_design -jobs 4
        wait_on_run impl_1
        if {[get_property STATUS [get_runs impl_1]] ne " route_design Complete!" &&
            [get_property STATUS [get_runs impl_1]] ne "route_design Complete!"} {
            error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
        }
        open_run impl_1
        report_timing_summary -file [file join $project_dir timing_summary.rpt]
        if {$target eq "timing"} {
            report_timing -max_paths 50 -file [file join $project_dir timing_paths.rpt]
        }
        if {$target eq "bitstream"} {
            launch_runs impl_1 -to_step write_bitstream -jobs 4
            wait_on_run impl_1
        }
    }
}
