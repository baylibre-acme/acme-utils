# BayLibre ACME command line API

## Power Cycling Tools ##

* dut-power-on  {PROBE#}
* dut-power-off {PROBE#}
* dut-hard-reset {PROBE#}

## dut-dump-probe utility ##

### Purpose ###

This app shall dump the contents of a PowerProbe eeprom in the style of the ACME
command line API. A typical use will be:


```
  (target)#> dut-dump-probe  1
    PowerProbe USB at slot 1 details:
      Revision B
      RShunt is  80000 uOhm
      Serial Number is 123456
      ...
```

### ACME startup Shunt resistor configuration ###

This app can be used at startup from an init script to set the Shunt resistor values
in the driver.

```
  (target)#> dut-dump-probe 1 -r/--rshunt
  80000
```

