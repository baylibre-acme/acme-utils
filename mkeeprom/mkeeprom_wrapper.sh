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

if [ ! "$#" == "2" ]
then
	echo "usage:"
	echo "	mkeeprom_wrapper.sh <path to mkeeprom> <serial number>"
	exit 1
fi

MKEEPROM=$1
SERIAL=$2

SERIAL_SIZE=$(echo $SERIAL | wc -c)
if [ $SERIAL_SIZE -gt 17 ] # Account for newline
then
	echo "serial number must be at most 16 chars in length"
	exit 1
fi

set -e
make_input
cat $INPUT_PATH | $MKEEPROM > /dev/null

echo "EEPROM data file stored at data.eeprom"
echo "This data file can be put in the BeagleBone EEPROM via the following command on a BeagleBone:"
echo "	'cat data.eeprom >/sys/bus/i2c/drivers/at24/1-005x/eeprom'"
echo
echo "Where:  5x is 54, 55, 56, 57 depending on Cape addressing."
