/*
 * Author: Marc Titinger <mtitinger@baylibre.com>
 *
 * This is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * */

#include <getopt.h>
#include <iio.h>
#include <signal.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <assert.h>


#define EEPROM_SERIAL_SIZE		16
#define EEPROM_TAG_SIZE			32

#define EEPROM_PROBE_TYPE_USB		1
#define EEPROM_PROBE_TYPE_JACK		2
#define EEPROM_PROBE_TYPE_HE10		3

struct probe_eeprom {
	uint32_t type;
	uint32_t rev;
	uint32_t shunt;
	uint8_t pwr_sw;
	uint8_t serial[EEPROM_SERIAL_SIZE];
	int8_t tag[EEPROM_TAG_SIZE];
};

static struct probe_eeprom *my_probe;

#define EEPROM_SIZE (3 * sizeof(uint32_t) + 1 + EEPROM_SERIAL_SIZE + EEPROM_TAG_SIZE)

#define EEPROM_OFF_TYPE		0
#define EEPROM_OFF_REV		sizeof(uint32_t)
#define EEPROM_OFF_SHUNT	(2 * sizeof(uint32_t))
#define EEPROM_OFF_PWR_SW	(3 * sizeof(uint32_t))
#define EEPROM_OFF_SERIAL	(3 * sizeof(uint32_t) + 1)
#define EEPROM_OFF_TAG		(EEPROM_OFF_SERIAL + EEPROM_SERIAL_SIZE)

static const uint8_t enrg_i2c_addrs[] = {
	0x40, 0x41, 0x44, 0x45, 0x42, 0x43, 0x46, 0x47,
};


static FILE *fout;
static int bus_number = 1;


static const struct option options[] = {
	{"help", no_argument, 0, 'h'},
	{"bus", required_argument, 0, 'b'},
	{0, 0, 0, 0},
};

static const char *options_descriptions[] = {
	"Show this help and quit.",
	"the number of the i2c bus, usually it will be i2c1.",
};


static void dump_probe(struct probe_eeprom *p)
{

}

static void usage(char* app)
{
	unsigned int i;

	printf("Usage:\n\t %s [-b <bus>] <probe_number> \n\nOptions:\n", app);
	for (i = 0; options[i].name; i++)
		printf("\t-%c, --%s\n\t\t\t%s\n",
		       options[i].val, options[i].name,
		       options_descriptions[i]);
}

static char bus_path[128] = "/sys/class/i2c-dev/i2c-1";
static char device_path[128] = "1-0050";

int main(int argc, char **argv)
{
	int c, option_index = 0, arg_index = 0;
	char temp[1024];

	while ((c = getopt_long(argc, argv, "+hb:",
				options, &option_index)) != -1) {
		switch (c) {
		case 'h':
			usage(argv[0]);
			return EXIT_SUCCESS;
		case 'b':
			arg_index += 2;
			bus_number = argv[arg_index][0];
			bus_path[strlen(bus_path)-1] = bus_number;
			printf("Using bus path %s\n", bus_path);
			break;
		case '?':
			return EXIT_FAILURE;
		}
	}

	if (++arg_index >= argc) {
		fprintf(stderr, "Incorrect number of arguments.\n\n");
		usage(argv[0]);
		return EXIT_FAILURE;
	}

	device_path[strlen(device_path)-1] = argv[arg_index][0];
	device_path[0] = bus_number;

	sprintf(temp,"%s/device/%s/eeprom", bus_path, device_path);

	printf("Trying %s\n", temp);

	fout = fopen(temp, "rb");
	if (!fout) {
		fprintf(stderr, "Could not open %s.\n", temp);
		return -2;
	}

	if (fread(my_probe, sizeof(struct probe_eeprom), 1, fout) == sizeof(struct probe_eeprom))
		dump_probe(my_probe);

	return 0;
}
