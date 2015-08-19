#!/bin/sh

# ACME revB USB probe validation script.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

source defs.sh
source cape.sh
source probe.sh

init_cape

echo
echo "	BayLibre ACME revB USB probe validation script"
echo
echo "This script will lead you through a manual validation of"
echo "the components of the ACME USB probe."
echo
echo "Please prepare the setup consisting of an ACME cape with at least "
echo "one USB probe attached. Insert the USB memory sticks into each probe's"
echo "USB port and connect the other end with a port of the USB hub. Connect"
echo "the hub with the BeagleBone Black."
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

				echo "Waiting for the USB disk"
				wait_for_sda
				test -b /dev/sda1 || die "USB memory stick not detected!"

				echo "Mounting the USB stick"
				mkdir /tmp/usb0 2> /dev/null
				set -e
				mount /dev/sda1 /tmp/usb0

				echo "Creating a file with random data"
				dd if=/dev/urandom of=/tmp/foo count=1 bs=16M 2>/dev/null

				echo "Copying the file to the USB stick"
				cp /tmp/foo /tmp/usb0/foo

				echo "Syncing"
				make_ina_dev $ADDR
				set_shunt 80000
				sync &
				echo "Current measurements during copying of data:"
				printf "power\t\tcurr\t\tVbus\t\tVshunt\n"
				for i in $(seq 1 3)
				do
					MSR=$(print_measurements | tee /dev/tty)
					usleep 50000
				done
				del_ina_dev $ADDR
				wait

				echo "Comparing files"
				cmp /tmp/foo /tmp/usb0/foo
				echo "Files equal"

				echo "Cleaning up"
				rm /tmp/foo /tmp/usb0/foo
				umount /tmp/usb0
				rmdir /tmp/usb0

				echo "Testing probe EEPROM"
				probes_eeprom_disable_wp
				make_probe_eeprom $ADDR
				test_probe_eeprom $ADDR
				del_probe_eeprom $ADDR
				probes_eeprom_enable_wp
				echo "EEPROM OK"

				echo "Reading serial number"
				SERIAL=$(probe_read_serial $ADDR | tee /dev/tty)
				echo "Reading MAC address"
				probe_read_mac $ADDR

				echo "Storing data in $LOG_FILE"
				echo "USB $ADDR $SERIAL	$MSR" >> $LOG_FILE
				set +e

				echo "USB probe at address $ADDR: all tests passed!"
				echo

				gpio_set $GPIO_NUM 0
				gpio_unexport $(gpio_num_from_addr $ADDR)
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
