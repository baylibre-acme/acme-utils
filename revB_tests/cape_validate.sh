#!/bin/sh

# ACME revB cape validation script.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

source cape.sh

init_cape

echo
echo "	BayLibre ACME revB cape validation script"
echo
echo "This script will lead you through a manual validation of"
echo "the components of the ACME cape."
echo

echo "Manual switch test"
echo "Set the switch to bus #2 mode and press ENTER"
read
check_expander 2 || die "Cape not detected on bus #2"
echo "OK"
echo "Set the switch back to bus #1 mode"
read
check_expander 1 || die "Cape not detected on bus #1"
echo "OK"

echo "Cape EEPROM micro-switch tests"
echo "Addresses corresponding with each switch setting:"
echo
echo "Facing 'up' (towards the power ethernet port)"
echo
echo "0x54    0x55    0x56     0x57"
echo "X  X    |  X    X  |     |  |"
echo "|  |    X  |    |  X     X  X"
echo
echo "Set the switcher to the desired setting and press ENTER"
read
EEPROM_ADDR=$(get_cape_eeprom_addr)
test "$EEPROM_ADDR" == "0" && die "Cape EEPROM not found on any address"
echo "Cape EEPROM found at address $EEPROM_ADDR"
echo "Is it correct? [Y/n]"
get_user_confirm || die "Error detecting the cape EEPROM"

echo "Cape signal switch test"
set -e
make_cape_expander_dev
echo "Switching to probes' line"
set_switch_probes
check_switch_probes
echo "OK"
echo "Switching to cape line"
set_switch_cape
check_switch_cape $EEPROM_ADDR
echo "OK"
set +e

echo "Cape EEPROM write and readback test"
set -e
echo "Instantiating the EEPROM device"
make_cape_eeprom_dev $EEPROM_ADDR
echo "Write-protection should be enabled by default - testing"
set +e
cape_eeprom_write $EEPROM_ADDR "dummy" && echo "Write-protection not working"
echo "OK"
set -e
echo "Disabling write-protection"
cape_eeprom_disable_wp
echo "OK"
echo "Writing $CAPE_EEPROM_SIZE random bytes to the cape EEPROM"
BYTES=$(dd if=/dev/urandom bs=$CAPE_EEPROM_SIZE count=1 2> /dev/null | uuencode foo | tr -d '\n' | tr -d ' ' | dd bs=$CAPE_EEPROM_SIZE count=1 2> /dev/null)
cape_eeprom_write $EEPROM_ADDR $BYTES
echo "Reading back the data and comparing"
READ_BACK_BUF=$(cape_eeprom_read $EEPROM_ADDR $CAPE_EEPROM_SIZE)
test "$BYTES" == "$READ_BACK_BUF" || die "EEPROM contents are not the same as the bytes written"
echo "OK"
echo "Cape EEPROM functionality OK"
echo "Restoring cape EEPROM write-protection"
cape_eeprom_enable_wp
del_cape_eeprom_dev $EEPROM_ADDR

echo
echo "All done, cape is fully functional!"

exit 0
