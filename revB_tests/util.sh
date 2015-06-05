#!/bin/sh

# ACME revB cape utility helpers.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

GPIO_PATH="/sys/class/gpio/"
GPIO_EXPORT="$GPIO_PATH/export"
GPIO_UNEXPORT="$GPIO_PATH/unexport"

die() {
	echo $*
	exit 1
}

gpio_export() {
	NUM=$1

	test -h $GPIO_PATH/gpio$NUM || echo $NUM > $GPIO_EXPORT
}

gpio_unexport() {
	NUM=$1

	test -h $GPIO_PATH/gpio$NUM && echo $NUM > $GPIO_UNEXPORT
}

# Export and set a value for given gpio.
# Example: gpio_set 504 1
gpio_set() {
	NUM=$1
	VAL=$2

	gpio_export $NUM
	echo out > $GPIO_PATH/gpio$NUM/direction
	echo $VAL > $GPIO_PATH/gpio$NUM/value
}

get_user_confirm() {
	read ANSW
	if [ -z "$ANSW" ] || [ "$ANSW" == "y" ] || [ "$ANSW" == "yes" ] || [ "$ANSW" == "Y" ]
	then
		return 0
	else
		return 1
	fi
}
