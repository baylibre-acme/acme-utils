#!/usr/bin/env python
"""
    TBD
"""


from platform import system as system_name # Returns the system/OS name
from os import system as system_call       # Execute a shell command

__app_name__ = ""
__license__ = ""
__copyright__ = ""
__date__ = ""
__author__ = ""
__email__ =  ""
__contact__ = ""
__maintainer__ = ""
__status__ = ""
__version__ = "0.0.1"
__deprecated__ = False


def ping(host):
    """Return True if host (str) responds to a ping request.

    Send a ping request to 'host' and return True if a response is received,
    False otherwise.
    Remember that some hosts may not respond to a ping request even if the host
    name is valid.
    Source: https://stackoverflow.com/questions/2953462/pinging-servers-in-python

    Args:
        host: hostname (e.g. 192.168.1.2 or myhost.mydomain)

    Returns:
        True if host (str) responds to a ping request, False otherwise.
    """

    # Ping parameters as function of OS
    parameters = "-n 1" if system_name().lower() == "windows" else "-c 1"

    # Pinging
    return system_call("ping " + parameters + " " + host + " > /dev/null") == 0
