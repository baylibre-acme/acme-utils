#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

kversion=$(shell uname -r)

TARGETS := dut-dump-probe

CFLAGS = -Wall -g -O1

.PHONY: all clean

all: $(TARGETS)

dut-dump-probe: dut-dump-probe.c
	$(CROSS_COMPILE)gcc -o $@ dut-dump-probe.c $(CFLAGS)

#install: dut-dump-probe
#	sudo install -s -v $^ /usr/bin

clean:
	rm -f $(TARGETS) *.o
	rm -f ./*.mimetype ./*.dat ./*.png *.csv
