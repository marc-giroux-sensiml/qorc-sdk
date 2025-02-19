#!/bin/bash

# fpga-load-quit: m4+fpga debugging usage only!
# load fpga design using JLink Commander and quit
# we check if the current project has an fpga design (fpga/ dir) and accordingly
#    generate a 'custom' JLink Commander Script which loads the design onto the EOS-S3 and quits
# the fpga design is loaded using the generated (*.jlink) script file from the Symbiflow tooling.
# this is a HELPER SCRIPT to be used only while debugging an fpga + m4 project using JLink (VS Code)
# details:
# Because the Symbiflow tooling only generates a JLink Commander Script, which can only be run
#   using the JLink Commander, and not gdb, we cannot ask gdb to load this automatically.
#   So, once the m4 code is loaded, and we reach the breakpoint at main(), we use this script
#   to load the fpga design, and then 'resume' debugging.


# REQ:
# 1. JLink probe is connected to EOS-S3 and the EOS-S3 is booted in DEBUG mode
# 2. JLinkExe is available in the path ('source envsetup.sh' of the QORC SDK has been done)
# 3. fpga jlink commandfile (.jlink) has been generated by adding a 'jlink' to the -dump command to ql_symbiflow 
#    the current makefile for fpga add the jlink to -dump by default

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# get the JLink Commander executable
JLINK_EXE_PATH=$(which JLinkExe)

# sanity checks
if [ -z "$JLINK_EXE_PATH" ] ; then
    printf "\nERROR: JLINK_EXE_PATH is not defined!\n"
    printf "\nJLinkExe should be on the path, is the QORC SDK initialized with 'source envsetup.sh'?\n"
    usage
    exit 1
fi

# confirmation print
printf "\n"
printf "JLINK_EXE_PATH=$JLINK_EXE_PATH\n"
printf "\n"


PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_FPGA_DIR="${PROJECT_DIR}/fpga"


# check if we have fpga design in the current project
PROJECT_FPGA_DESIGN_JLINK=
if [ -d "$PROJECT_FPGA_DIR" ] ; then
    PROJECT_RTL_DIR="${PROJECT_FPGA_DIR}/rtl"
    PROJECT_FPGA_DESIGN_JLINK=$(ls "$PROJECT_RTL_DIR"/config_bit_gen/*.jlink)
    if [ ! -f "$PROJECT_FPGA_DESIGN_JLINK" ] ; then
        printf "\nERROR: fpga .jlink does not exist! (is build done?)\n"
        exit 1
    fi
else
    printf "\nThis project does not have an 'fpga/' directory\n\n!"
    exit 0
fi


# generate a 'custom' jlink script to:
# load the fpga design (.jlink generated), quit jlink commander

CUSTOM_JLINK_SCRIPT="custom_eoss3_fpga.jlink"
CUSTOM_JLINK_SCRIPT_LOG="custom_eoss3_fpga.jlink.log"

# [step 0]
# write "NOTHING" into file, i.e. reset the contents, faster than delete + touch.
#https://askubuntu.com/a/549672
: > "$CUSTOM_JLINK_SCRIPT"


# [step 1] load the fpga design (.jlink generated)
# copy the contents of the generated .jlink as is
if [ -f "$PROJECT_FPGA_DESIGN_JLINK" ] ; then
    cat "$PROJECT_FPGA_DESIGN_JLINK" >> "$CUSTOM_JLINK_SCRIPT"
    echo "" >> "$CUSTOM_JLINK_SCRIPT"
    echo "" >> "$CUSTOM_JLINK_SCRIPT"
fi

# [step 2] quit jlink
echo "q" >> "$CUSTOM_JLINK_SCRIPT"
echo "" >> "$CUSTOM_JLINK_SCRIPT"


# moar: https://wiki.segger.com/J-Link_Commander
# 'h' to halt
# 'i' to read JTAG ID (0x2BA01477)
# 'mem32 ADDR COUNT' to read COUNT words from ADDR 'mem32 0x40005484 1'
# 'w4 ADDR VAL' to write 4 byte word VAL into ADDR 'w4 0x2007C000, 0xAABBCCDD'
# 'savebin PATH_TO_SAVE_BIN, FROM_ADDR, NUM_BYTES' to dump RAM content into binary file 'savebin saved_mem.bin, 0x0, 0x20000'
# 'verifybin PATH_TO_ORIG_BIN, FROM_ADDR, NUM_BYTES' to compare and verify bin is loaded


# run custom jlink script : note that the JLinkExe will still be running after load, enter 'q' to quit
"$JLINK_EXE_PATH" -Device Cortex-M4 -If SWD -Speed 4000 -commandFile "$CUSTOM_JLINK_SCRIPT" -Log "$CUSTOM_JLINK_SCRIPT_LOG"

# remove the custom script/log (disable for debugging the script)
rm "$CUSTOM_JLINK_SCRIPT"
rm "$CUSTOM_JLINK_SCRIPT_LOG"
