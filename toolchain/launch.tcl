# ZCU208 JTAG launch: initialize the PS with an A53 FSBL, then run the app.
# Place this file in the project root alongside hardware/
# Use the matching, unstripped A53 FSBL built by zcu208_platform.

set project_root [file dirname [file normalize [info script]]]
set bit_file [file join $project_root hardware zcu208_modulation_v6_rrc_bypass_2.bit]
set xsa_file [file join $project_root hardware zcu208_modulation_v6_rrc_bypass_2.xsa]

set workspace {C:/Xilinx/vitis_workspace}
set fsbl_file [file join $workspace zcu208_platform zynqmp_fsbl build fsbl.elf]
set app_file  [file join $workspace rfsoc_app build rfsoc_app.elf]

foreach {description path} [list \
    "Bitstream" $bit_file \
    "Hardware design" $xsa_file \
    "FSBL ELF" $fsbl_file \
    "Application ELF" $app_file] {
    if {![file isfile $path]} {
        error "$description not found: $path"
    }
    puts "$description: $path"
}

puts "\nConnecting to hardware..."
connect
puts [targets]

puts "\nResetting the system..."
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 3000

puts "\nProgramming PL..."
targets -set -nocase -filter {name =~ "PSU"}
fpga -file $bit_file

puts "\nLoading the hardware memory map..."
targets -set -nocase -filter {name =~ "APU*"}
loadhw -hw $xsa_file

# Match the debugger's ability to access memory before PS initialization.
set saved_force_access [configparams force-mem-accesses]
configparams force-mem-accesses 1

try {
    set mode [expr {[lindex [mrd -force -value 0xFF5E0200] 0] & 0xF}]
    puts [format "\nBoot mode: 0x%X" $mode]
    if {$mode != 0} {
        error "Expected JTAG boot mode (0). Check boot switches and power-cycle."
    }

    puts "\nResetting Cortex-A53 #0 and loading FSBL..."
    targets -set -nocase -filter {name =~ "*A53*#0"}
    rst -processor
    dow $fsbl_file

    puts "\nRunning FSBL until XFsbl_Exit..."
    set fsbl_bp [bpadd -addr &XFsbl_Exit]
    if {[catch {con -block -timeout 60} run_error]} {
        catch {stop}
        catch {bpremove $fsbl_bp}
        error "FSBL failed to halt within 60 seconds or could not run: $run_error"
    }

    # A blocked continue can return for reasons other than our breakpoint.
    if {[catch {bpstatus $fsbl_bp} bp_info]} {
        catch {bpremove $fsbl_bp}
        error "Could not check FSBL breakpoint: $bp_info"
    }
    puts "FSBL breakpoint status: $bp_info"
    if {![regexp -nocase {HitCount[[:space:]:]+([0-9]+)} $bp_info -> hits] || $hits < 1} {
        catch {bpremove $fsbl_bp}
        error "A53 stopped, but the XFsbl_Exit breakpoint was not confirmed."
    }
    bpremove $fsbl_bp

    # Standard ZynqMP FSBL reports completion as 0 in this register and
    # writes a nonzero code on an error path. XFsbl_Exit alone is not enough.
    set fsbl_status [lindex [mrd -force -value 0xFFD80060] 0]
    puts [format "FSBL status register: 0x%08X" $fsbl_status]
    if {$fsbl_status != 0} {
        error "FSBL reported a nonzero status. Check the UART and FSBL configuration."
    }

    puts "\nResetting Cortex-A53 #0 and loading the application..."
    targets -set -nocase -filter {name =~ "*A53*#0"}
    rst -processor
    dow $app_file

    puts "\nStarting application..."
    con
    puts "\nApplication started. Check the PS UART for output."
} finally {
    configparams force-mem-accesses $saved_force_access
}
