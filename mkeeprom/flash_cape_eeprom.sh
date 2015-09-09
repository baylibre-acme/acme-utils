#!/bin/sh

INPUT_PATH="/tmp/acme_eeprom_data"

make_input() {
	printf "\
ACME
revB
BayLibre
n/a
$SERIAL
0
0
0
0
4
9
18
1
3
1
1
1
0
2
9
17
1
2
1
1
1
0
2
9
19
1
2
1
1
1
0
3
9
20
1
3
1
1
1
0
3
\n" > $INPUT_PATH
}

do_i2cget() {
	i2cget -y 1 0x5c $1 2> /dev/null || echo 00
}

cape_read_serial() {
	printf "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x\n" \
		$(do_i2cget 0x80) $(do_i2cget 0x81) $(do_i2cget 0x82) $(do_i2cget 0x83) \
		$(do_i2cget 0x84) $(do_i2cget 0x85) $(do_i2cget 0x86) $(do_i2cget 0x87) \
		$(do_i2cget 0x88) $(do_i2cget 0x89) $(do_i2cget 0x8a) $(do_i2cget 0x8b) \
		$(do_i2cget 0x8c) $(do_i2cget 0x8d) $(do_i2cget 0x8e) $(do_i2cget 0x8f)
}

if [ ! "$#" == "1" ]
then
	echo "usage:"
	echo "	flash_cape_eeprom.sh <path to mkeeprom>"
	echo
	echo "EEPROM address is expected to be 0x54"
	exit 1
fi

MKEEPROM=$1
OUT=./data.eeprom

SERIAL=$(cape_read_serial)

modprobe at24 2> /dev/null
modprobe gpio-pca953x 2> /dev/null

set -e
echo 24c02 0x54 > /sys/class/i2c-adapter/i2c-1/new_device
echo pca9534 0x21  > /sys/class/i2c-adapter/i2c-1/new_device
echo 505 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio505/direction
make_input
cat $INPUT_PATH | $MKEEPROM > /dev/null
cat $OUT > /sys/class/i2c-dev/i2c-1/device/1-0054/eeprom
echo 505 > /sys/class/gpio/unexport
echo 0x54 > /sys/class/i2c-adapter/i2c-1/delete_device
echo 0x21  > /sys/class/i2c-adapter/i2c-1/delete_device

echo "data written to eeprom"
