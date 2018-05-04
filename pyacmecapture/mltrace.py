#!/usr/bin/env python
""" Multi-Level Trace Python Class

Implement a smart trace with configurable header and debug trace levels.

"""


__app_name__ = "Smart Trace Library"
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


class MLTrace():
    """Print debug messages depending on selected verbose level.

    Attributes:
        verbose_level: integer value (> 0) representing the verbose level,
            usually retrieved from user arguments
    """

    def __init__(self, verbose_level, msg_header = None):
        """Init class attribute 'verbose_level'."""
        self._verbose_level = verbose_level
        self._msg_header = msg_header

    def trace(self, level, msg):
        """Print debug messages depending on selected debug level.

        If 'level' <= self.verbose_level, then 'msg' is printed, ignored otherwise.

        Args:
            level: selected debug level (e.g. 1, 2, 3, ...)
            msg: a custom message (e.g. 'this is my great custom message')
        """
        if (self._verbose_level >= level):
            if self._msg_header != None:
                print("[" + self._msg_header + "] " + msg)
            else:
                print(msg)