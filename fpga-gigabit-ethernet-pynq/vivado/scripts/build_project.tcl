set script_dir [file dirname [file normalize [info script]]]
set design_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $design_dir vivado_project]
set project_name fpga_gigabit_ethernet_pynq
set target [string tolower [lindex $argv 0]]
if {$target eq ""} {
    set target prepare
}

if {$target ni {prepare synth impl timing bitstream sim crc_sim}} {
    error "Usage: vivado -mode batch -source build_project.tcl -tclargs prepare|synth|impl|timing|bitstream|sim|crc_sim"
}

create_project -force $project_name $project_dir -part xc7z020clg400-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [list \
    [file join $design_dir rtl crc32_d8.v] \
    [file join $design_dir rtl crc32_d8_parallel.v] \
    [file join $design_dir rtl rgmii_to_gmii.v] \
    [file join $design_dir rtl arp_cache_engine.v] \
    [file join $design_dir rtl udp_ip_tx.v] \
    [file join $design_dir rtl udp_ip_rx.v] \
    [file join $design_dir rtl axis_packet_generator.v] \
    [file join $design_dir rtl mac_ip_udp_axis_top.v]]
add_files -norecurse $rtl_files
add_files -fileset constrs_1 -norecurse \
    [file join $design_dir constraints external_rgmii_timing_template.xdc]
add_files -fileset sim_1 -norecurse \
    [file join $design_dir sim tb_mac_ip_udp.v]
add_files -fileset sim_1 -norecurse \
    [file join $design_dir sim tb_crc32_compare.v]

set_property top mac_ip_udp_axis_top [get_filesets sources_1]
if {$target eq "crc_sim"} {
    set_property top tb_crc32_compare [get_filesets sim_1]
} else {
    set_property top tb_mac_ip_udp [get_filesets sim_1]
}
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {$target eq "prepare"} {
    puts "Project prepared at $project_dir for external PL-connected RGMII PHY."
} elseif {$target eq "sim"} {
    launch_simulation
    run all
} elseif {$target eq "crc_sim"} {
    launch_simulation
    run all
} else {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
        error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
    }
    if {$target ne "synth"} {
        if {$target eq "bitstream"} {
            launch_runs impl_1 -to_step write_bitstream -jobs 4
        } else {
            launch_runs impl_1 -to_step route_design -jobs 4
        }
        wait_on_run impl_1
        set impl_status [get_property STATUS [get_runs impl_1]]
        if {$target eq "bitstream"} {
            if {$impl_status ne "write_bitstream Complete!"} {
                error "Bitstream generation failed: $impl_status"
            }
        } elseif {$impl_status ne "route_design Complete!"} {
            error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
        }
        open_run impl_1
        report_timing_summary -file [file join $project_dir timing_summary.rpt]
        if {$target eq "timing"} {
            report_timing -max_paths 50 -file [file join $project_dir timing_paths.rpt]
        }
    }
}
