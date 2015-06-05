#!/bin/sh

# ACME revB testing common definitions.
#
# Copyright (C) 2015 Bartosz Golaszewski <bgolaszewski@baylibre.com>

I2C1_BUS_PATH="/sys/class/i2c-adapter/i2c-1"
I2C1_NEW_DEVICE="/sys/class/i2c-adapter/i2c-1/new_device"
I2C1_DEL_DEVICE="/sys/class/i2c-adapter/i2c-1/delete_device"

INA_ADDRS="0x40 0x41 0x42 0x43 0x44 0x45 0x46 0x47"
PROBE_EXPANDER_ADDR="0x20"