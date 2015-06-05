#!/bin/sh

# ACME revB cape helper routines.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

source util.sh
source defs.sh

I2C_TOOLS="i2cget i2cset i2cdump i2cdetect"

EXPANDER_DRIVER="gpio-pca953x"
EEPROM_DRIVER="at24"
INA_DRIVER="ina2xx"
DRIVER_LIST="$EXPANDER_DRIVER $EEPROM_DRIVER $INA_DRIVER usb-storage"

CAPE_EEPROM_NAME="24c256"
CAPE_EXPANDER_NAME="pca9534"
PROBE_EXPANDER_NAME="pca9545"

CAPE_EXPANDER_ADDR="0x21"
CAPE_EEPROM_ADDRS="0x54 0x55 0x56 0x57"

SWITCHER_GPIO="504"
CAPE_WP_GPIO="505"
PROBES_WP_GPIO="506"
PROBES_EN_GPIOS="489 491 493 495 497 499 501 503"
GPIO_LIST="$SWITCHER_GPIO $CAPE_WP_GPIO $PROBES_WP_GPIO $PROBES_EN_GPIOS"

CAPE_EEPROM_SIZE=244

# Check if we can find all needed utilities before doing any actual work.
check_progs() {
	for PROG in $I2C_TOOLS
	do
		PROGPATH=$(which $PROG 2> /dev/null)
		test $? -ne 0 && die "$PROG not found!"
	done
}

check_i2c1() {
	test -h $I2C1_BUS_PATH || die "i2c-1 bus not found!"
}

unexport_gpios() {
	for GPIO in $GPIO_LIST
	do
		gpio_unexport $GPIO
	done
}

delete_devices() {
	for ADDR in $INA_ADDRS $CAPE_EXPANDER_ADDR \
			$PROBE_EXPANDER_ADDR $CAPE_EEPROM_ADDRS
	do
		echo $ADDR > $I2C1_DEL_DEVICE 2> /dev/null
	done
}

load_drivers() {
	set -e
	for DRV in $DRIVER_LIST
	do
		modprobe $DRV
	done
	set +e
}

touch_cape_expander() {
	set -e
	i2cset -y 1 0x21 0x00
	set +e
}

make_cape_expander_dev() {
	echo $CAPE_EXPANDER_NAME $CAPE_EXPANDER_ADDR > $I2C1_NEW_DEVICE
}

del_cape_expander_dev() {
	echo $CAPE_EXPANDER_ADDR > $I2C1_DEL_DEVICE
}

make_cape_eeprom_dev() {
	ADDR=$1

	echo $CAPE_EEPROM_NAME $ADDR > $I2C1_NEW_DEVICE
}

del_cape_eeprom_dev() {
	ADDR=$1

	echo $ADDR > $I2C1_DEL_DEVICE
}

get_eeprom_path() {
	ADDR=$1

	echo "/sys/class/i2c-dev/i2c-1/device/1-00$(echo $ADDR | cut -d"x" -f2)/eeprom"
}

reset_signal_switcher() {
	set -e
	make_cape_expander_dev
	gpio_set $SWITCHER_GPIO 1
	gpio_unexport $SWITCHER_GPIO
	del_cape_expander_dev
	set +e
}

# Bring the cape to a sane state. That includes deleting all i2c1 devices &
# reloading the drivers.
init_cape() {
	check_progs
	check_i2c1
	unexport_gpios
	delete_devices
	load_drivers
	touch_cape_expander
	reset_signal_switcher
}

check_expander() {
	BUS_NUM=$1

	i2cget -y $BUS_NUM $CAPE_EXPANDER_ADDR > /dev/null
	if [ $? -eq 0 ]
	then
		return 0
	else
		return 1
	fi
}

get_cape_eeprom_addr() {
	for ADDR in $CAPE_EEPROM_ADDRS
	do
		i2cget -y 1 $ADDR > /dev/null 2>/dev/null
		if [ "$?" == "0" ]
		then
			echo $ADDR
			return 0
		fi
	done

	echo "0"
}

set_switch_probes() {
	gpio_set $SWITCHER_GPIO 0
}

check_switch_probes() {
	i2cset -y 1 $PROBE_EXPANDER_ADDR 0x00
}

set_switch_cape() {
	gpio_set $SWITCHER_GPIO 1
}

check_switch_cape() {
	_ADDR=$1

	i2cget -y 1 $_ADDR > /dev/null
}

cape_eeprom_write() {
	_ADDR=$1
	_BUF=$2

	echo $_BUF > $(get_eeprom_path $_ADDR) 2> /dev/null
}

cape_eeprom_read() {
	_ADDR=$1
	_SIZE=$2

	dd if=$(get_eeprom_path $_ADDR) bs=$_SIZE count=1 2> /dev/null
}

cape_eeprom_disable_wp() {
	gpio_set $CAPE_WP_GPIO 0
}

cape_eeprom_enable_wp() {
	gpio_set $CAPE_WP_GPIO 1
}

probes_eeprom_disable_wp() {
	gpio_set $PROBES_WP_GPIO 0
}

probes_eeprom_enable_wp() {
	gpio_set $PROBES_WP_GPIO 1
}
