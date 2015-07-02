#!/bin/sh

# ACME revB probe interaction helper routines.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

source defs.sh
source cape.sh
source util.sh

PROBE_EXPANDER_NAME="pca9535"
INA_NAME="ina226"
PROBE_EEPROM_NAME="24c02"

touch_probes_expander() {
	set -e
	i2cset -y 1 0x20 0x00
	set +e
}

make_probes_expander_dev() {
	echo $PROBE_EXPANDER_NAME $PROBE_EXPANDER_ADDR > $I2C1_NEW_DEVICE
}

del_probes_expander_dev() {
	echo $PROBE_EXPANDER_ADDR > $I2C1_DEL_DEVICE
}

detect_probe_at_addr() {
	_ADDR=$1

	i2cget -y 1 $_ADDR > /dev/null 2> /dev/null

	return $?
}

detect_probe_eeprom_at_addr() {
	_ADDR=$1

	i2cget -y 1 $_ADDR > /dev/null 2> /dev/null

	return $?
}

detect_probe_serial_at_addr() {
	_ADDR=$1

	i2cget -y 1 $_ADDR > /dev/null 2> /dev/null

	return $?
}

make_ina_dev() {
	_ADDR=$1

	echo $INA_NAME $_ADDR > $I2C1_NEW_DEVICE
}

del_ina_dev() {
	_ADDR=$1

	echo $_ADDR > $I2C1_DEL_DEVICE
}

read_hwmon0() {
	_FILE=$1

	cat /sys/class/hwmon/hwmon0/$_FILE
}

show_pwr() {
	echo - | awk -v val="$1" '{ print val / 1000000 }'
}

show_curr_vol() {
	echo - | awk -v val="$1" '{ print val / 1000 }'
}

print_measurements() {
	PWR=$(show_pwr $(read_hwmon0 "power1_input"))
	CURR=$(show_curr_vol $(read_hwmon0 "curr1_input"))
	VBUS=$(show_curr_vol $(read_hwmon0 "in1_input"))
	VSHUNT=$(show_curr_vol $(read_hwmon0 "in0_input"))

	printf "%.3f W\t\t%.3f A\t\t%.3f V\t\t%.3f V\n" $PWR $CURR $VBUS $VSHUNT
}

set_shunt() {
	echo $1 > /sys/class/hwmon/hwmon0/shunt_resistor
}

gpio_num_from_addr() {
	_ADDR=$1

	if [ "$_ADDR" == "0x40" ]
	then
		echo "495"
	elif [ "$_ADDR" == "0x41" ]
	then
		echo "496"
	elif [ "$_ADDR" == "0x42" ]
	then
		echo "491"
	elif [ "$_ADDR" == "0x43" ]
	then
		echo "500"
	elif [ "$_ADDR" == "0x44" ]
	then
		echo "493"
	elif [ "$_ADDR" == "0x45" ]
	then
		echo "498"
	elif [ "$_ADDR" == "0x46" ]
	then
		echo "489"
	else
		echo "497"
	fi
}

probe_eeprom_write() {
	_ADDR=$1
	_BUF=$2

	echo -ne $_BUF | dd of=$(get_eeprom_path $_ADDR) bs=128 seek=1 2>/dev/null
}

probe_eeprom_read() {
	_ADDR=$1
	_SIZE=$2

	dd if=$(get_eeprom_path $_ADDR) bs=$_SIZE count=1 skip=1 2> /dev/null
}

make_probe_eeprom() {
	_ADDR=$(printf "0x%x\n" $(( $1 + 0x10 )))

	echo $PROBE_EEPROM_NAME $_ADDR > $I2C1_NEW_DEVICE
}

del_probe_eeprom() {
	_ADDR=$(printf "0x%x\n" $(( $1 + 0x10 )))

	echo $_ADDR > $I2C1_DEL_DEVICE
}

test_probe_eeprom() {
	_ADDR=$(printf "0x%x\n" $(( $1 + 0x10 )))
	NUM_BYTES=128

	echo "Writing $NUM_BYTES random bytes to the probe EEPROM"
	BYTES=$(dd if=/dev/urandom bs=$NUM_BYTES count=1 2> /dev/null | uuencode foo | tr -d '\n' | tr -d ' ' | dd bs=$NUM_BYTES count=1 2> /dev/null)
	probe_eeprom_write $_ADDR $BYTES
	echo "Reading back the data and comparing"
	READ_BACK_BUF=$(probe_eeprom_read $_ADDR $NUM_BYTES)
	test "$BYTES" == "$READ_BACK_BUF" || die "EEPROM contents are not the same as the bytes written"
}

probe_read_serial() {
	_ADDR=$(printf "0x%x\n" $(( $1 + 0x18 )))

	printf "serial: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n" \
		$(i2cget -y 1 $_ADDR 0x80) $(i2cget -y 1 $_ADDR 0x81) $(i2cget -y 1 $_ADDR 0x82) $(i2cget -y 1 $_ADDR 0x83) \
		$(i2cget -y 1 $_ADDR 0x84) $(i2cget -y 1 $_ADDR 0x85) $(i2cget -y 1 $_ADDR 0x86) $(i2cget -y 1 $_ADDR 0x87) \
		$(i2cget -y 1 $_ADDR 0x88) $(i2cget -y 1 $_ADDR 0x89) $(i2cget -y 1 $_ADDR 0x8a) $(i2cget -y 1 $_ADDR 0x8b) \
		$(i2cget -y 1 $_ADDR 0x8c) $(i2cget -y 1 $_ADDR 0x8d) $(i2cget -y 1 $_ADDR 0x8e) $(i2cget -y 1 $_ADDR 0x8f)
}

probe_read_mac() {
	_ADDR=$(printf "0x%x\n" $(( $1 + 0x18 )))

	printf "MAC address: %02x %02x %02x %02x %02x %02x\n" \
		$(i2cget -y 1 $_ADDR 0x9a) $(i2cget -y 1 $_ADDR 0x9b) $(i2cget -y 1 $_ADDR 0x9c) $(i2cget -y 1 $_ADDR 0x9d) $(i2cget -y 1 $_ADDR 0x9e) $(i2cget -y 1 $_ADDR 0x9f)
}

wait_for_sda() {
	for SEC in $(seq 1 10)
	do
		sleep 1
		test -b /dev/sda1 && return 0
	done

	die "USB disk not detected"
}
