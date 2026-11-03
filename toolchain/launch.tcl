# Launch the ZCU208 application over JTAG with XSDB.

set project_root [file dirname [file normalize [info script]]]

set bit_file [file join $project_root hardware zcu208_modulation_v6_adc_rrc_bypass.bit]
set ps_init_file [file join $project_root hardware psu_init.tcl]
set elf_file [file join $project_root vitis_workspace rfsoc_app build rfsoc_app.elf]

# If your build printed a different ELF path, edit elf_file above.
foreach {description path} [list \
    "Bitstream" $bit_file \
    "PS initialization script" $ps_init_file \
    "Application ELF" $elf_file] {

    if {![file isfile $path]} {
        error "$description not found: $path"
    }

    puts "$description: $path"
}

puts "\nConnecting to local hardware server..."
connect

puts "\nAvailable targets:"
puts [targets]

# Halt an earlier run before changing the FPGA configuration. After a
# JTAG-mode power-up, A53 #0 can instead already be stopped or in reset.
targets -set -nocase -filter {name =~ "*A53*#0"}

if {[catch {stop} stop_message]} {
    if {![regexp -nocase \
        {already stopped|already suspended|not running|in reset|is reset|reset asserted} \
        $stop_message]} {

        error "Could not halt Cortex-A53 #0: $stop_message"
    }

    puts "A53 #0 is already stopped or in reset: $stop_message"
}

# Use the PSU target for PL and PS setup.
targets -set -nocase -filter {name =~ "PSU"}

puts "\nProgramming the PL bitstream..."
fpga -file $bit_file

puts "\nInitializing the processing system..."
source $ps_init_file
psu_init

# Remove PS-to-PL isolation and release PL resets for AXI access.
after 1000
psu_ps_pl_isolation_removal
after 1000
psu_ps_pl_reset_config

puts "\nResetting Cortex-A53 #0..."
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor

puts "\nDownloading application ELF..."
dow $elf_file

puts "\nStarting Cortex-A53 #0..."
con

puts "\nLaunch commands completed. Check the serial terminal for application output."