# Various BayLibre ACME related scripts and tools #

## ACME  Command Line API ##

The following scripts and Apps figure the ACME command-line API:

* dut-switch-on
* dut-switch-off
* dut-hard-reset
* dur-dump-probe

## Buildroot integration

the Buildroot package is located in the ACME repo. It will
build dut-probe-dump using the Buildroot toolchain, and deploy
it to the target using:

cd API && make CC= DESTDIR= install
