#
# Copyright (c) 2016 BayLibre SAS
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

DESTDIR?=$(INSTALL_MOD_PATH)/usr/bin
CC?=$(CROSS_COMPILE)gcc
CFLAGS?=-Wall -g -O1

TARGETS:=dut-dump-probe \
	dut-switch-on \
	dut-switch-off \
	dut-hard-reset

all: $(TARGETS)

dut-dump-probe: dut-dump-probe.c
	$(CC) -o $@ dut-dump-probe.c $(CFLAGS)

install: $(TARGETS)
	fakeroot install -s -v  dut-dump-probe $(DESTDIR)
	fakeroot install -v dut-switch-on $(DESTDIR)
	fakeroot install -v dut-switch-off $(DESTDIR)
	fakeroot install -v dut-hard-reset $(DESTDIR)

clean:
	rm -f dut-dump-probe *.o
