#!/bin/sh

if [ "$#" -ne "3" ]
then
	echo "usage:"
	echo "	flash_probe_eeproms.sh <path to probe_flasher> <probe type> <shunt resistance>"
	echo
	echo "Available probe types are: usb, jack, he10"
	echo
	echo "Only one type of probes with the same shunt resistor value can"
	echo "be flashed at a time, but there can be several of them."
	exit 1
fi

source defs.sh
source cape.sh
source probe.sh

FLASHER_PATH=$1

if [ "$2" == "usb" ]
then
	PROBE_TYPE=1
elif [ "$2" == "jack" ]
then
	PROBE_TYPE=2
else
	PROBE_TYPE=3
fi

SHUNT=$3

init_cape

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
				echo "Probe found at address $ADDR, flashing EEPROM"

				set -e

				echo "Reading serial number"
				SERIAL=$(probe_read_serial $ADDR | tee /dev/tty | sed 's/ //g' | cut -d":" -f2)
				echo "Probe serial: $SERIAL"

				echo "Flashing probe EEPROM"
				probes_eeprom_disable_wp
				make_probe_eeprom $ADDR
				echo "Writing contents to $(get_eeprom_path $(printf "0x%X\n" $(( $ADDR + 0x10 ))))"
				$FLASHER_PATH $PROBE_TYPE $SHUNT $SERIAL > $(get_eeprom_path $(printf "0x%X\n" $(( $ADDR + 0x10 ))))
				del_probe_eeprom $ADDR
				probes_eeprom_enable_wp
				echo "EEPROM OK"

				set +e

				echo "HE10 probe at address $ADDR: EEPROM flashed"
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
