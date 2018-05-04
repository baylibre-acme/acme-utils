#!/usr/bin/env python
""" Python ACME Power Capture Utility

This utility is designed to capture voltage, current and power samples with
Baylibre's ACME Power Measurement solution (www.baylibre.com/acme).

The following assumption(s) were made:
    - ACME Cape slots are populated with probes starting from slot 1,
      with no 'holes' in between (e.g. populating slots 1,2,3 is valid,
                                       populating slots 1,2 4 is not)

Inspired by work done on the "iio-capture" tool done by:
    - Paul Cercueil <paul.cercueil@analog.com>,
    - Marc Titinger <mtitinger@baylibre.com>,
    - Fabrice Dreux <fdreux@baylibre.com>,
and the work done on "pyacmegraph" tool done by:
    - Sebastien Jan <sjan@baylibre.com>.

Leveraged IIOAcmeCape and IIOAcmeProbe classes abstracting IIO/ACME details.

Todo:
    * Fix Segmentation fault at end of script
    * Find a way to remove hard-coded power unit (uW)
    * Save logs to file

"""


from __future__ import print_function
import sys
import argparse
import threading
import time
from colorama import init, Fore, Style
import traceback
import numpy as np
from mltrace import MLTrace
from iioacmecape import IIOAcmeCape


__app_name__ = "Python ACME Power Capture Utility"
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


def log(color, flag, msg):
    """ Format messages as follow: "['color'ed 'flag'] 'msg'"

    Args:
        color (str): the color of the flag (e.g. Fore.RED, Fore.GREEN, ...)
        flag (str): a custom flag (e.g. 'OK', 'FAILED', 'WARNING', ...)
        msg (str): a custom message (e.g. 'this is my great custom message')

    Returns:
        None

    """
    print("[" + color + flag + Style.RESET_ALL + "] " + msg)


def exit_with_error(err):
    """ Display completion message with error code before terminating execution.

    Args:
        err (int): an error code

    Returns:
        None

    """
    if err != 0:
        print("\nScript execution terminated with error code %d." % err)
    else:
        print("\nScript execution completed with success.")
    print("\n< There will be a 'Segmentation fault (core dumped)' error message after this one. >")
    print("< This is a kwown bug. Please ignore it. >\n")
    exit(err)


class iioDeviceCaptureThread(threading.Thread):
    """ IIO ACME Capture thread

    This class is used to abstract the capture of multiple channels of a single
    ACME probe / IIO device.

    """
    def __init__(self, threadid, cape, slot, channels, duration, verbose_level):
        """ Initialise iioDeviceCaptureThread class

        Args:
            threadid (int): an ID to identify the thread
            slot (int): ACME cape slot
            channels (list of strings): channels to capture
                        Supported channels: 'Vshunt', 'Vbat', 'Ishunt', 'Power'
            duration (int): capture duration (in seconds)
            verbose_level (int): how much verbose the debug trace shall be

        Returns:
            None

        """
        threading.Thread.__init__(self)
        # Init internal variables
        self._threadid = threadid
        self._cape = cape
        self._slot = slot
        self._channels = channels
        self._duration = duration
        self._verbose_level = verbose_level
        self._trace = MLTrace(verbose_level, "Thread #%u (slot #%u)" % (self._threadid, self._slot))
        self._trace.trace(2, "Thread params: slot=%u channels=%s duration=%us" % (slot, channels, duration))


    def configure_capture(self):
        """ Configure capture parameters (enable channel(s),
            configure internal settings, ...)

        Args:
            None

        Returns:
            bool: True if successful, False otherwise.

        """
        # Set oversampling for max perfs (4 otherwise)
        if self._cape.set_oversampling_ratio(self._slot, 1) is False:
            self._trace.trace(1, "Failed to set oversampling ratio!")
            return False
        self._trace.trace(1, "Oversampling ratio set to 1.")

        # Disable asynchronous reads
        if self._cape.enable_asynchronous_reads(self._slot, False) is False:
            self._trace.trace(1, "Failed to configure asynchronous reads!")
            return False
        self._trace.trace(1, "Asynchronous reads disabled.")

        # Enable selected channels
        for ch in self._channels:
            ret = self._cape.enable_capture_channel(self._slot, ch, True)
            if ret is False:
                self._trace.trace(1, "Failed to enable %s capture!" % ch)
                return False
            else:
                self._trace.trace(1, "%s capture enabled." % ch)

        # Allocate capture buffer
        freq = self._cape.get_sampling_frequency(self._slot)
        if freq == 0:
            self._trace.trace(1, "Failed to retrieve sampling frequency!")
            return False
        self._trace.trace(1, "Sampling frequency: %uHz" % freq)
        buffer_size = int(freq / 2) # buffer to store 1/2s of samples
        self._trace.trace(1, "Buffer size: %u" % buffer_size)
        if self._cape.allocate_capture_buffer(self._slot, buffer_size) is False:
            self._trace.trace(1, "Failed to allocate %s capture buffer!" % ch)
            return False
        else:
            self._trace.trace(1, "%s capture buffer allocated." % ch)
        return True


    def run(self):
        """ Start the capture until iioDeviceCaptureThread.stop() is called.

        Args:
            None

        Returns:
            None

        """
        self._alive = True
        self._failed = False
        self._samples = {}
        for ch in self._channels:
            self._samples[ch] = None
            self._samples["slot"] = self._slot
            self._samples["channels"] = self._channels
            self._samples["duration"] = self._duration
        while self._alive:
            # Capture samples
            ret = self._cape.refill_capture_buffer(self._slot)
            if ret != True:
                self._trace.trace(1, "Warning: error during buffer refill!")
                self._failed = True
            # Read captured samples
            for ch in self._channels:
                s = self._cape.read_capture_buffer(self._slot, ch)
                if s is None:
                    self._trace.trace(1, "Warning: error during %s buffer read!" % ch)
                    self._failed = True
                if self._samples[ch] is not None:
                    self._samples[ch]["samples"] = np.append(self._samples[ch]["samples"], s["samples"])
                else:
                    self._samples[ch] = {}
                    self._samples[ch]["failed"] = False
                    self._samples[ch]["unit"] = s["unit"]
                    self._samples[ch]["samples"] = s["samples"]
                self._trace.trace(3, "self._samples[%s] = %s" % (ch, str(self._samples[ch])))
        self._samples[ch]["failed"] = self._failed
        self._trace.trace(1, "Thread done.")


    def stop(self):
        """ Stop the capture and return collected samples.

        Args:
            None

        Returns:
            A dictionary (one per channel) containing following key/data:
                "slot" (int): ACME cape slot
                "channels" (list of strings): channels captured
                "duration" (int): capture duration (in seconds)
                For each captured channel:
                "capture channel name" (dict): a dictionary containing following key/data:
                    "failed" (bool): False if successful, True otherwise
                    "samples" (array): captured samples
                    "unit" (str): captured samples unit}}
            E.g:
                {'slot': 1, 'channels': ['Vbat', 'Ishunt'], 'duration': 3,
                 'Vbat': {'failed': False, 'samples': array([ 1, 2, 3 ]), 'unit': 'mV'},
                 'Ishunt': {'failed': False, 'samples': array([4, 5, 6 ]), 'unit': 'mA'}}

        """
        self._alive = False
        self.join()
        return self._samples

def main():
    err = -1

    # Print application header
    print(__app_name__ + " (version " + __version__ + ")\n")

    # Colorama: reset style to default after each call to print
    init(autoreset=True)

    # Parse user arguments
    parser = argparse.ArgumentParser(description='TODO',
                                     formatter_class=argparse.RawDescriptionHelpFormatter,
                                     epilog='''
    This tool captures min, max, and average values of selected power rails (voltage, current, power).
    These power measurements are performed using Baylibre's ACME cape and probes, over the network using IIO lib.
    Example usage:
        ''' + sys.argv[0] + ''' --ip baylibre-acme.local --duration 5 -c 2 -n VDD_1,VDD_2

    Note it is assumed that slots are populated from slot 1 and upwards, with no hole.''')
    parser.add_argument('--ip', metavar='HOSTNAME', default='baylibre-acme.local',# add default hostname here
                        help='ACME hostname (e.g. 192.168.1.2 or baylibre-acme.local)')
    parser.add_argument('--count', '-c', metavar='COUNT', type=int, default=8,
                        help='Number of power rails to capture (> 0))')
    parser.add_argument('--names', '-n', metavar='LABELS',
                        help='''List of names for the captured power rails
                        (comma separated list, one name per power rail,
                        always start from ACME Cape slot 1).
                        E.g. VDD_BAT,VDD_ARM,...''')
    parser.add_argument('--duration', '-d', metavar='SEC', type=int,
                        default=10, help='Capture duration in seconds (> 0)')
    parser.add_argument('--verbose', '-v', action='count',
                        help='print debug traces (various levels v, vv, vvv)')

    args = parser.parse_args()
    log(Fore.GREEN, "OK", "Parse user arguments")

    # Use MLTrace to log execution details
    trace = MLTrace(args.verbose)
    trace.trace(2, "User args: " + str(args)[10:-1])
    err = err - 1

    # Create an IIOAcmeCape instance
    iio_acme_cape = IIOAcmeCape(args.ip, args.verbose)
    max_rail_count = iio_acme_cape.get_slot_count()

    # Check arguments are valid
    try:
        assert (args.count <= max_rail_count)
        assert (args.count > 0)
    except:
        log(Fore.RED, "FAILED", "Check user argument ('count')")
        exit_with_error(err)

    try:
        if args.names is not None:
            args.names = args.names.split(',')
            trace.trace(2, "args.names: %s" % args.names)
            assert (args.count == len(args.names))
    except:
        log(Fore.RED, "FAILED", "Check user argument ('names')")
        exit_with_error(err)

    try:
        assert (args.duration > 0)
    except:
        log(Fore.RED, "FAILED", "Check user argument ('duration')")
        exit_with_error(err)
    err = err - 1
    log(Fore.GREEN, "OK", "Check user arguments")

    # Check ACME Cape is reachable
    if iio_acme_cape.is_up() != True:
        log(Fore.RED, "FAILED", "Ping ACME")
        exit_with_error(err)
    log(Fore.GREEN, "OK", "Ping ACME")
    err = err - 1

    # Init IIOAcmeCape instance
    if (iio_acme_cape.init() != True):
        log(Fore.RED, "FAILED", "Init ACME IIO Context")
        exit_with_error(err)
    log(Fore.GREEN, "OK", "Init ACME Cape instance")
    err = err - 1

    # Check all probes are attached
    failed = False
    for i in range(1, args.count + 1):
        attached = iio_acme_cape.probe_is_attached(i)
        if attached is not True:
            log(Fore.RED, "FAILED", "Detect probe in slot %u" % i)
            failed = True
        else:
            log(Fore.GREEN, "OK", "Detect probe in slot %u" % i)
    if failed is True:
        exit_with_error(err)
    err = err - 1

    # Create and configure capture threads
    threads = []
    failed = False
    for i in range(1, args.count + 1):
        try:
            thread = iioDeviceCaptureThread(i, iio_acme_cape,
                                            i, ["Vbat", "Ishunt"], args.duration, args.verbose)
            thread.configure_capture()
            threads.append(thread)
            log(Fore.GREEN, "OK", "Configure capture thread for probe in slot #%u" % i)
        except:
            log(Fore.RED, "FAILED", "Configure capture thread for probe in slot #%u" % i)
            trace.trace(2, traceback.format_exc())
            exit_with_error(err)
    err = err - 1

    # Start capture threads
    try:
        for thread in threads:
            thread.start()
    except:
        log(Fore.RED, "FAILED", "Start capture")
        trace.trace(2, traceback.format_exc())
        exit_with_error(err)
    log(Fore.GREEN, "OK", "Start capture")
    err = err - 1

    # Sleep
    time.sleep(args.duration)

    # Stop capture threads an retrieve captured data
    slot = 0
    captured_data = []
    for thread in threads:
        captured_data.append(thread.stop())
        trace.trace(3, "Slot %u captured data: %s" % (slot + 1, captured_data[slot]))
        slot = slot + 1
    log(Fore.GREEN, "OK", "Stop capture")

    # Process samples
    for i in range(1, args.count + 1):
        slot = captured_data[i - 1]["slot"]
        vbat_samples = captured_data[i - 1]["Vbat"]["samples"]
        ishunt_samples = captured_data[i - 1]["Ishunt"]["samples"]
        # Compute P (P = Vbat * Ishunt)
        captured_data[i - 1]["P"] = {}
        captured_data[i - 1]["P"]["unit"] = "uW" # FIXME
        captured_data[i - 1]["P"]["samples"] = np.multiply(vbat_samples, ishunt_samples)
        p_samples = captured_data[i - 1]["P"]["samples"]
        trace.trace(3, "Slot %u power samples: %s" % (slot, p_samples))

        # Compute min, max, avg values for Vbat, Ishunt and P
        vbat_min = captured_data[i - 1]["Vbat min"] = np.amin(vbat_samples)
        vbat_max = captured_data[i - 1]["Vbat max"] = np.amax(vbat_samples)
        vbat_avg = captured_data[i - 1]["Vbat avg"] = np.average(vbat_samples)
        ishunt_min = captured_data[i - 1]["Ishunt min"] = np.amin(ishunt_samples)
        ishunt_max = captured_data[i - 1]["Ishunt max"] = np.amax(ishunt_samples)
        ishunt_avg = captured_data[i - 1]["Ishunt avg"] = np.average(ishunt_samples)
        p_min = captured_data[i - 1]["P min"] = np.amin(p_samples)
        p_max = captured_data[i - 1]["P max"] = np.amax(p_samples)
        p_avg = captured_data[i - 1]["P avg"] = np.average(p_samples)
    log(Fore.GREEN, "OK", "Process samples")

    # Save data to file and display report
    print("\n------------------ Measurement results ------------------")
    print("Power Rails: %u" % args.count)
    print("Duration: %us" % args.duration)
    for i in range(1, args.count + 1):
        if args.names is not None:
            print("%s (slot %u)" % (args.names[i - 1], i))
        else:
            print("Slot %u" % i)
        vbat_min = captured_data[i - 1]["Vbat min"]
        vbat_max = captured_data[i - 1]["Vbat max"]
        vbat_avg = captured_data[i - 1]["Vbat avg"]
        unit = captured_data[i - 1]["Vbat"]["unit"]
        print("  Voltage (%s): min=%d max=%d avg=%d" % (unit, vbat_min, vbat_max, vbat_avg))
        ishunt_min = captured_data[i - 1]["Ishunt min"]
        ishunt_max = captured_data[i - 1]["Ishunt max"]
        ishunt_avg = captured_data[i - 1]["Ishunt avg"]
        unit = captured_data[i - 1]["Ishunt"]["unit"]
        print("  Current (%s): min=%d max=%d avg=%d" % (unit, ishunt_min, ishunt_max, ishunt_avg))
        p_min = captured_data[i - 1]["P min"]
        p_max = captured_data[i - 1]["P max"]
        p_avg = captured_data[i - 1]["P avg"]
        unit = captured_data[i - 1]["P"]["unit"]
        print("  Power   (%s): min=%d max=%d avg=%d" % (unit, p_min, p_max, p_avg))
        if i != args.count:
            print()
    print("---------------------------------------------------------")
    exit_with_error(0)

if __name__ == '__main__':
    main()