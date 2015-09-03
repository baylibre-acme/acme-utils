#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/types.h>

#define SERIAL_SIZE	16
#define TAG_SIZE	32

#define PROBE_USB	1
#define PROBE_JACK	2
#define PROBE_HE10	3

/* All integer types are in network byte order. */
struct eeprom_t {
	int type;
	int rev;
	unsigned long shunt;
	uint8_t pwr_sw;
	uint8_t serial[SERIAL_SIZE];
	char tag[TAG_SIZE];
} __attribute__((packed));

int main(int argc, char *argv[])
{
	struct eeprom_t eeprom;
	char *serial;
	int i;

	/*
	 * Arguments:
	 *   - probe type
	 *   - shunt resistance
	 *   - serial number
	 */

	assert(argc == 4);

	eeprom.type = atoi(argv[1]);
	assert(eeprom.type >= 1 || eeprom.type <= 3);

	eeprom.rev = (int)'B';

	eeprom.shunt = strtoul(argv[2], NULL, 10);
	assert(eeprom.shunt != 0);

	eeprom.pwr_sw = eeprom.type == 3 ? 0 : 1;

	serial = argv[3];
	assert(strlen(serial) == SERIAL_SIZE * 2);
	for (i = 0; i < SERIAL_SIZE; i++) {
		char tmp[3];
		tmp[0] = serial[i * 2];
		tmp[1] = serial[i * 2 + 1];
		tmp[2] = '\0';

		eeprom.serial[i] = (uint8_t)strtoul(tmp, NULL, 16);
	}

	memset(eeprom.tag, 0, TAG_SIZE);

	/* Adjust endianess. */
	eeprom.type = htonl(eeprom.type);
	eeprom.rev = htonl(eeprom.rev);
	eeprom.shunt = htonl(eeprom.shunt);

	fprintf(stderr, "EEPROM size: %u\n", sizeof(struct eeprom_t));
	fprintf(stderr, "EEPROM contents:\n");
	for (i = 0; i < sizeof(struct eeprom_t); i++) {
		fprintf(stderr, "%02x ", ((char *)&eeprom)[i]);
	}
	fprintf(stderr, "\n");

	write(STDOUT_FILENO, &eeprom, sizeof(struct eeprom_t));

	return 0;
}
