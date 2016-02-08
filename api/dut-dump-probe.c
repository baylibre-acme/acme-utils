/*
 * Copyright(C) BayLibre SAS 2016
 *
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

static struct probe_eeprom my_probe;

#define EEPROM_SIZE (3 * sizeof(uint32_t) + 1 + EEPROM_SERIAL_SIZE + EEPROM_TAG_SIZE)

#define EEPROM_OFF_TYPE		0
#define EEPROM_OFF_REV		sizeof(uint32_t)
#define EEPROM_OFF_SHUNT	(2 * sizeof(uint32_t))
#define EEPROM_OFF_PWR_SW	(3 * sizeof(uint32_t))
#define EEPROM_OFF_SERIAL	(3 * sizeof(uint32_t) + 1)
#define EEPROM_OFF_TAG		(EEPROM_OFF_SERIAL + EEPROM_SERIAL_SIZE)

static FILE *fout;
static int bus_number = 1;

#define ACME_PROBE_FIRST 1
#define ACME_PROBE_LAST  8
static int probe_number;

#define F_SERNUM 0x1
#define F_RSHUNT 0x2

static const struct option options[] = {
	{"help", no_argument, 0, 'h'},
	{"bus", required_argument, 0, 'b'},
	{"rshunt", no_argument, 0, 'r'},
	{"sernum", no_argument, 0, 's'},
	{0, 0, 0, 0},
};

static const char *options_descriptions[] = {
	"Show this help and quit.",
	"The number of the i2c bus, usually it will be i2c1.",
	"Only print the value of RShunt.",
	"Only print the serialnumber.",
};

static void dump_probe(struct probe_eeprom *p, int flags)
{
	if (!flags) {
		switch (p->type) {
		case EEPROM_PROBE_TYPE_USB:
			printf("PowerProbe USB @slot %d:", probe_number);
			break;
		case EEPROM_PROBE_TYPE_JACK:
			printf("PowerProbe JACK @slot %d:", probe_number);
			break;
		case EEPROM_PROBE_TYPE_HE10:
			printf("PowerProbe HE10 @slot %d:", probe_number);
			break;
		default:
			printf("Unknown probe type %d.", p->type);
			return;
		}

		switch (p->rev) {
		case 'B':
			printf("\tReB\n");
			break;
		default:
			printf("Unknown Revision '%c'\n", p->rev);
			return;
		}

		if (p->pwr_sw)
			printf("\tHas Power Switch\n");

		printf("\tR_Shunt: %d uOhm\n", p->shunt);

		printf("\tSerial Number: %x-%x-%x-%x\n",
		       ((unsigned int *)p->serial)[0],
		       ((unsigned int *)p->serial)[1],
		       ((unsigned int *)p->serial)[2],
		       ((unsigned int *)p->serial)[3]);
	} else if (flags & F_SERNUM)
		printf("%x-%x-%x-%x\n", ((unsigned int *)p->serial)[0],
		       ((unsigned int *)p->serial)[1],
		       ((unsigned int *)p->serial)[2],
		       ((unsigned int *)p->serial)[3]);
	else if (flags & F_RSHUNT)
		printf("%d\n", p->shunt);

}

static void usage(char *app)
{
	unsigned int i;

	printf
	    ("Usage:\n\t %s [-b/--bus <bus>] [-r/--rshunt] [-s/--sernum] <probe_number in 1..8> \n\nOptions:\n",
	     app);
	for (i = 0; options[i].name; i++)
		printf("\t-%c, --%s\n\t\t\t%s\n",
		       options[i].val, options[i].name,
		       options_descriptions[i]);
}

int main(int argc, char **argv)
{
	int c, option_index = 0, arg_index = 0, print_flags = 0;
	char temp[1024];

	while ((c = getopt_long(argc, argv, "+rshb:",
				options, &option_index)) != -1) {
		switch (c) {
		case 'h':
			usage(argv[0]);
			return EXIT_SUCCESS;
		case 'b':
			arg_index += 2;
			bus_number = argv[arg_index][0] - '0';
			break;
		case 'r':
			arg_index++;
			print_flags |= F_RSHUNT;
			break;
		case 's':
			arg_index++;
			print_flags |= F_SERNUM;
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

	probe_number = argv[arg_index][0] - '0';

	if ((probe_number > ACME_PROBE_LAST)
	    || (probe_number < ACME_PROBE_FIRST)) {
		fprintf(stderr, "Invalid probe number %d.\n\n", probe_number);
		usage(argv[0]);
		return EXIT_FAILURE;
	}

	sprintf(temp, "/sys/class/i2c-dev/i2c-%1d/device/%1d-005%1d/eeprom",
		bus_number, bus_number, probe_number - 1);

	printf("Trying %s\n", temp);

	fout = fopen(temp, "rb");
	if (!fout) {
		fprintf(stderr, "Could not open %s.\n", temp);
		return -2;
	}

	if (fread(&my_probe, sizeof(struct probe_eeprom), 1, fout) ==
	    sizeof(struct probe_eeprom))
		dump_probe(&my_probe, print_flags);

	return 0;
}
