#!/bin/sh

source cape.sh
init_cape

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
	dd if=/sys/class/i2c-adapter/i2c-1/1-005c/eeprom bs=8 skip=1 count=1 | hexdump -ve '1/1 "%.2x"'
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

echo 24c32 0x54 > /sys/class/i2c-adapter/i2c-1/new_device
echo 24cs32 0x5c > /sys/class/i2c-adapter/i2c-1/new_device
SERIAL=$(cape_read_serial)
echo $SERIAL
echo pca9534 0x21  > /sys/class/i2c-adapter/i2c-1/new_device
set -e
echo 505 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio505/direction
make_input
cat $INPUT_PATH | $MKEEPROM > /dev/null
cat $OUT > /sys/class/i2c-dev/i2c-1/device/1-0054/eeprom
echo 505 > /sys/class/gpio/unexport
echo 0x54 > /sys/class/i2c-adapter/i2c-1/delete_device
echo 0x5c > /sys/class/i2c-adapter/i2c-1/delete_device
echo 0x21  > /sys/class/i2c-adapter/i2c-1/delete_device

echo "data written to eeprom"
