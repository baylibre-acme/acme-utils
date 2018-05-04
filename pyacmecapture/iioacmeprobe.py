#!/usr/bin/env python
""" Python ACME Capture Utility for NXP TPMP (Temperature-controlled Power Measurement Platform)

TBD description of the utility

Inspired by work done on the "iio-capture" tool done by:
    - Paul Cercueil <paul.cercueil@analog.com>,
    - Marc Titinger <mtitinger@baylibre.com>,
    - Fabrice Dreux <fdreux@baylibre.com>,
and the work done on "pyacmegraph" tool done by:
    - Sebastien Jan <sjan@baylibre.com>.
"""


from __future__ import print_function
import iio
import struct
import traceback
import numpy as np
from mltrace import MLTrace


__app_name__ = "IIO ACME Probe Python Library"
__license__ = "MIT"
__copyright__ = "Copyright 2018, Baylibre SAS"
__date__ = "2018/03/01"
__author__ = "Patrick Titiano"
__email__ =  "ptitiano@baylibre.com"
__contact__ = "ptitiano@baylibre.com"
__maintainer__ = "Patrick Titiano"
__status__ = "Development"
__version__ = "0.1"
__deprecated__ = False


# Channels mapping: 'explicit naming' vs 'IIO channel IDs'
channel_dict = {
            'Vshunt' : 'voltage0',
            'Vbat' : 'voltage1',
            'Time' : 'timestamp',
            'Ishunt' : 'current3',
            'Power' : 'power2'}

# Channels unit
channel_units = {
            'Vshunt' : 'mV',
            'Vbat' : 'mV',
            'Time' : 'ms',
            'Ishunt' : 'mA',
            'Power' : 'mW'}


class IIOAcmeProbe():
    def __init__(self, slot, type, shunt, pwr_switch, iio_device, verbose_level):
        self._slot = slot
        self._type = type
        self._shunt = shunt
        self._pwr_switch = pwr_switch
        self._iio_device = iio_device
        self._iio_buffer = None
        self._verbose_level = verbose_level
        self._trace = MLTrace(verbose_level, "Probe " + self._type + " Slot " + str(self._slot))

        self._trace.trace(2, "IIOAcmeProbe instance created with settings:")
        self._trace.trace(2, "Slot: " + str(self._slot) + " Type: " + self._type
                          + ", Shunt: " + str(self._shunt) + " uOhm" +
                          ", Power Switch: " + str(self._pwr_switch))
        if self._verbose_level >= 2:
            self._show_iio_device_attributes()

    def _show_iio_device_attributes(self):
        self._trace.trace(3, "======== IIO Device infos ========")
        self._trace.trace(3, "  ID: " +  self._iio_device.id)
        self._trace.trace(3, "  Name: " +  self._iio_device.name)
        if  self._iio_device is iio.Trigger:
            self._trace.trace(3, "  Trigger: yes (rate: %u Hz)" %  self._iio_device.frequency)
        else:
            self._trace.trace(3, "  Trigger: none")
        self._trace.trace(3, "  Device attributes found: %u" % len( self._iio_device.attrs))
        for attr in  self._iio_device.attrs:
            self._trace.trace(3, "    " + attr + ": " +  self._iio_device.attrs[attr].value)
        self._trace.trace(3, "  Device debug attributes found: %u" % len( self._iio_device.debug_attrs))
        for attr in  self._iio_device.debug_attrs:
            self._trace.trace(3, "    " + attr + ": " +  self._iio_device.debug_attrs[attr].value)
        self._trace.trace(3, "  Device channels found: %u" % len( self._iio_device.channels))
        for chn in  self._iio_device.channels:
            self._trace.trace(3, "    Channel ID: %s" % chn.id)
            self._trace.trace(3, "    Channel name: %s" % "" if chn.name is None else chn.name)
            self._trace.trace(3, "    Channel direction: %s" % ("output" if chn.output else 'input'))
            self._trace.trace(3, "    Channel attributes found: %u" % len(chn.attrs))
            for attr in chn.attrs:
                    self._trace.trace(3, "      " + attr + ": " + chn.attrs[attr].value)
            self._trace.trace(3, "")
        self._trace.trace(2, "==================================")

    def get_slot(self):
        return self._slot

    def get_type(self):
        return self._type

    def get_shunt(self):
        return self._shunt

    def has_power_switch(self):
        return self._pwr_switch

    def enable_power(self, enable):
        if self.has_power_switch() == True:
            if enable == True:
                #FIXME
                print("TODO enable power")
                self._trace.trace(1, "Power enabled.")
            else:
                #FIXME
                print("TODO disable power")
                self._trace.trace(1, "Power disabled.")
        else:
            self._trace.trace(1, "No power switch on this probe!")
            return False
        return True

    def set_oversampling_ratio(self, oversampling_ratio):
        try:
            self._iio_device.attrs["in_oversampling_ratio"].value = str(oversampling_ratio)
            self._trace.trace(1, "Oversampling ratio configured to %u." % oversampling_ratio)
            return True
        except:
            self._trace.trace(1, "Failed to configure oversampling ratio (%u)!" % oversampling_ratio)
            self._trace.trace(2, traceback.format_exc())
            return False

    def enable_asynchronous_reads(self, enable):
        try:
            if enable is True:
                self._iio_device.attrs["in_allow_async_readout"].value = "1"
                self._trace.trace(1, "Asynchronous reads enabled.")
            else:
                self._iio_device.attrs["in_allow_async_readout"].value = "0"
                self._trace.trace(1, "Asynchronous reads disabled.")
            return True
        except:
            self._trace.trace(1, "Failed to configure asynchronous reads!")
            self._trace.trace(2, traceback.format_exc())
            return False

    def get_sampling_frequency(self):
        try:
            freq = self._iio_device.attrs['in_sampling_frequency'].value
            self._trace.trace(1, "Sampling frequency: %sHz" % freq)
            return int(freq)
        except:
            self._trace.trace(1, "Failed to retrieve sampling frequency!")
            self._trace.trace(2, traceback.format_exc())
            return 0

    def enable_capture_channel(self, channel, enable):
        try:
            iio_ch = self._iio_device.find_channel(channel_dict[channel])
            if not (iio_ch):
                self._trace.trace(1, "Channel %s (%s) not found!" % (channel, channel_dict[channel]))
                return False
            self._trace.trace(2, "Channel %s (%s) found." % (channel, channel_dict[channel]))
            if enable is True:
                iio_ch.enabled = True
                self._trace.trace(1, "Channel %s (%s) capture enabled." % (channel, channel_dict[channel]))
            else:
                iio_ch.enabled = False
                self._trace.trace(1, "Channel %s (%s) capture disabled." % (channel, channel_dict[channel]))
        except:
            if enable is True:
                self._trace.trace(1, "Failed to enable capture on channel %s (%s)!")
            else:
                self._trace.trace(1, "Failed to disable capture on channel %s (%s)!")
            self._trace.trace(2, traceback.format_exc())
            return False
        return True

    def allocate_capture_buffer(self, samples_count, cyclic = False):
        self._iio_buffer = iio.Buffer(self._iio_device, samples_count, cyclic)
        if self._iio_buffer != None:
            self._trace.trace(1, "Buffer (count=%d, cyclic=%s) allocated." % (samples_count, cyclic))
            return True
        else:
            self._trace.trace(1, "Failed to allocate buffer! (count=%d, cyclic=%s)" % (samples_count, cyclic))
            return False

    def refill_capture_buffer(self):
        try:
            self._iio_buffer.refill()
        except:
            self._trace.trace(1, "Failed to refill buffer!")
            self._trace.trace(2, traceback.format_exc())
            return False
        self._trace.trace(1, "Buffer refilled.")
        return True

    def read_capture_buffer(self, channel):
        try:
            # Retrieve channel
            iio_ch = self._iio_device.find_channel(channel_dict[channel])
            # Retrieve samples (raw)
            ch_buf_raw = iio_ch.read(self._iio_buffer)
            # Unpack binary data to signed integer values
            unpack_str = 'h' * (len(ch_buf_raw) / struct.calcsize('h'))
            values = struct.unpack(unpack_str, ch_buf_raw)
            self._trace.trace(2, "%u samples read." % len(values))
            self._trace.trace(3, "Samples         : " + str(values))
            # Scale values
            scale = float(iio_ch.attrs['scale'].value)
            self._trace.trace(3, "Scale: %f" % scale)
            if scale != 1.0:
                scaled_values = np.asarray(values) * scale
            else:
                scaled_values = np.asarray(values)
            self._trace.trace(3, "Samples (scaled): " + str(scaled_values))
        except:
            self._trace.trace(1, "Failed to read channel %s buffer!" % channel)
            self._trace.trace(2, traceback.format_exc())
            return None
        return {"channel": channel, "unit": channel_units[channel], "samples": scaled_values}
