#!/usr/bin/env python
"""
Continuously display b2g-procrank.
"""

from __future__ import print_function

import sys
import time
import subprocess

def shell(cmd, cwd=None):
    proc = subprocess.Popen(cmd, shell=True, cwd=cwd,
                            stdout=sys.stdout, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()
    if proc.returncode:
        print("Command %s failed with error code %d" % (cmd, proc.returncode), file=sys.stderr)
        if err:
            print(err, file=sys.stderr)
        raise subprocess.CalledProcessError(proc.returncode, cmd, err)
    return out


def main():
    try:
        while True:
            print(chr(27) + "[0;0H") # move cursor to top left
            shell("adb shell b2g-procrank")
            print(chr(27) + "[J") # erase screen from current line down
            time.sleep(1)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
