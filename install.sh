#!/bin/bash

# Make dump tool
make -C api

# Copy binaries
cp api/dut-dump-probe /usr/local/bin/
cp api/dut-switch-on /usr/local/bin/
cp api/dut-switch-off /usr/local/bin/
cp pyacmed/pyacmed /usr/local/bin/
cp scripts/acme-iio-wakeup /usr/local/bin/
cp scripts/acme-iio-init /usr/local/bin/

# Install systemd services
cp pyacmed/pyacmed.service /etc/systemd/system/
cp scripts/acme-iio-init.service /etc/systemd/system
cp scripts/acme-iio-wakeup.service /etc/systemd/system
