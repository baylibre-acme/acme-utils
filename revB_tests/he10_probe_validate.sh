#!/bin/sh

# ACME revB USB probe validation script.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

source defs.sh
source cape.sh
source probe.sh

init_cape

echo
echo "	BayLibre ACME revB HE10 probe validation script"
echo
echo "This script will lead you through a manual validation of"
echo "the components of the ACME HE10 probe."
echo
echo "Please prepare the setup consisting of an ACME cape with at least "
echo "one HE10 probe attached to a power-rail on the measured device."
echo
echo "Press ENTER when ready to proceed"
read

set -e
make_cape_expander_dev
set_switch_probes
touch_probes_expander
make_probes_expander_dev

for ADDR in $INA_ADDRS
do
	detect_probe_at_addr $ADDR
	if [ "$?" == "0" ]
	then
		detect_probe_eeprom_at_addr $(printf "0x%X\n" $(( $ADDR + 0x10 )))
		if [ "$?" == "0" ]
		then
			detect_probe_serial_at_addr $(printf "0x%X\n" $(( $ADDR + 0x18 )))
			if [ "$?" == "0" ]
			then
				GPIO_NUM=$(gpio_num_from_addr $ADDR)
				echo "Probe found at address $ADDR, running tests..."
				gpio_set $GPIO_NUM 1
				sleep 1 # Let the beagle turn-on

				make_ina_dev $ADDR
				sync &
				echo "Current measurements:"
				printf "power\t\tcurr\t\tVbus\t\tVshunt\n"
				for i in $(seq 1 3)
				do
					print_measurements
					usleep 50000
				done
				del_ina_dev $ADDR

				set -e
				echo "Testing probe EEPROM"
				probes_eeprom_disable_wp
				make_probe_eeprom $ADDR
				test_probe_eeprom $ADDR
				del_probe_eeprom $ADDR
				probes_eeprom_enable_wp
				echo "EEPROM OK"

				echo "Reading serial number"
				probe_read_serial $ADDR
				echo "Reading MAC address"
				probe_read_mac $ADDR
				set +e

				echo "HE10 probe at address $ADDR: all tests passed!"
				echo
			else
				echo "Probe found at address $ADDR, but no EEPROM with"
				echo "serial number was found."
				echo "Something is wrong - skipping this probe"
				continue
			fi
		else
			echo "Probe found at address $ADDR, but no EEPROM was found"
			echo "Something is wrong - skipping this probe"
			continue
		fi
	else
		echo "No probe at address $ADDR"
		continue
	fi
done