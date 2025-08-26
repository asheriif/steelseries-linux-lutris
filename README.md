# Unofficial SteelSeries Engine on Linux

Inspired by and slightly modified from:
- https://gist.github.com/ToadKing/26c28809b8174ad0e06bfba309cf3ff3
- https://github.com/MiddleMan5/steelseries-linux

This has less prerequisites and works even on **immutable distros like Bazzite**.

Note that is is all unofficial and not supported by SteelSeries. Not everything will work and you should only use the engine to control your devices. Things like Moments etc will NOT work.

## Prerequisites

* **Lutris** - Lutris is needed to actually install the Steelseries app after the setup here is done. **See below**.
* **Python 3** - you most probably already have this.


## Setup (automatic)

Clone this repo, then simply run `./install.sh`.

## Setup (manual)

### udev rules
To configure the firmware on SteelSeries devices, you will need to send it HID reports through the **hidraw** kernel driver. However by default the device files the driver creates are only readable and writable by the root user for security purposes. Rather than just give read and write permission to everything, we are going to make a udev rule to only allow read and write access to the devices we need.

Start by creating this udev rule file in `/etc/udev/rules.d/98-steelseries.rules`:

    ACTION=="add", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038" RUN+="/etc/udev/rules.d/steelseries-perms.py '%E{DEVNAME}'"

This sets up a rule for any hidraw device that is added with the SteelSeries USB Vendor ID. Rather than set the permissions here, we instead forward it the device file path to a python script.

The python script at `/etc/udev/rules.d/steelseries-perms.py` should be this:

    #!/usr/bin/env python3

    import ctypes
    import fcntl
    import os
    import struct
    import sys

    # from linux headers hidraw.h, hid.h, and ioctl.h
    _IOC_NRBITS = 8
    _IOC_TYPEBITS = 8
    _IOC_SIZEBITS = 14

    _IOC_NRSHIFT = 0
    _IOC_TYPESHIFT = _IOC_NRSHIFT + _IOC_NRBITS
    _IOC_SIZESHIFT = _IOC_TYPESHIFT + _IOC_TYPEBITS
    _IOC_DIRSHIFT = _IOC_SIZESHIFT + _IOC_SIZEBITS

    _IOC_READ = 2

    def _IOC(dir, type, nr, size):
        return (dir << _IOC_DIRSHIFT) | \
            (ord(type) << _IOC_TYPESHIFT) | \
            (nr << _IOC_NRSHIFT) | \
            (size << _IOC_SIZESHIFT)

    def _IOR(type, nr, size):
        return _IOC(_IOC_READ, type, nr, size)

    HID_MAX_DESCRIPTOR_SIZE = 4096

    class hidraw_report_descriptor(ctypes.Structure):
        _fields_ = [
            ('size', ctypes.c_uint),
            ('value', ctypes.c_uint8 * HID_MAX_DESCRIPTOR_SIZE),
        ]

    HIDIOCGRDESCSIZE = _IOR('H', 0x01, ctypes.sizeof(ctypes.c_int))
    HIDIOCGRDESC = _IOR('H', 0x02, ctypes.sizeof(hidraw_report_descriptor))

    hidraw = sys.argv[1]

    with open(hidraw, 'wb') as fd:
        size = ctypes.c_uint()
        fcntl.ioctl(fd, HIDIOCGRDESCSIZE, size, True)
        descriptor = hidraw_report_descriptor()
        descriptor.size = size
        fcntl.ioctl(fd, HIDIOCGRDESC, descriptor, True)

    descriptor = bytes(descriptor.value)[0:int.from_bytes(size, byteorder=sys.byteorder)]

    # walk through the descriptor until we find the usage page
    usagePage = 0
    i = 0
    while i < len(descriptor):
        b0 = descriptor[i]
        bTag = (b0 >> 4) & 0x0F
        bType = (b0 >> 2) & 0x03
        bSize = b0 & 0x03

        if bSize != 0:
            bSize = 2 ** (bSize - 1)

        if b0 == 0b11111110:
            # long types shouldn't be the usage page, skip them
            i += 3 + descriptor[i+1]
            continue

        if bType == 1 and bTag == 0:
            # usage page, grab it
            format = ''
            if bSize == 1:
                format = 'B'
            elif bSize == 2:
                format = 'H'
            elif bSize == 4:
                format = 'I'
            else:
                raise Exception('usage page is length {}???'.format(bSize))
            usagePage = struct.unpack_from(format, descriptor, i + 1)[0]
            break

        i += 1 + bSize

    # set read/write permissions for vendor and consumer usage pages
    # some devices don't use the vendor page, allow the interfaces they do use
    if usagePage == 0x000C or usagePage >= 0xFF00:
        os.chmod(hidraw, 0o666)

This python script does the following actions:

1. Reads the HID Descriptor of the device.
2. Does a simple parsing of the HID Descriptor to get the [usage page](https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf) of the descriptor.
3. We check to see if the device has a vendor-defined usage page or a consumer usage page. These two usage pages are what most SteelSeries USB devices use for configuring the device.
4. If the usage page matches one of those, set read and write permissions for the file.

Once you create this file, make sure the execute bit on the file is set so the udev rule can execute it properly. Once that's done you can either reset your udev rules and replug your SteelSeries devices or simply reboot your computer. Once you do you should see that some hidraw device files have read and write permissions for everybody:

    $ ls -l /dev/hidraw*
    crw-rw-rw- 1 root root 237,  0 Jul 13 17:58 /dev/hidraw0
    crw------- 1 root root 237,  1 Jul 13 17:58 /dev/hidraw1
    crw-rw-rw- 1 root root 237, 10 Jul 13 17:58 /dev/hidraw10
    crw-rw-rw- 1 root root 237, 11 Jul 13 17:58 /dev/hidraw11
    crw-rw-rw- 1 root root 237, 12 Jul 13 17:58 /dev/hidraw12
    crw-rw-rw- 1 root root 237, 13 Jul 13 17:58 /dev/hidraw13
    crw-rw-rw- 1 root root 237,  2 Jul 13 17:58 /dev/hidraw2
    crw------- 1 root root 237,  3 Jul 13 17:58 /dev/hidraw3
    crw------- 1 root root 237,  4 Jul 13 17:58 /dev/hidraw4
    crw-rw-rw- 1 root root 237,  5 Jul 13 17:58 /dev/hidraw5
    crw------- 1 root root 237,  6 Jul 13 17:58 /dev/hidraw6
    crw-rw-rw- 1 root root 237,  7 Jul 13 17:58 /dev/hidraw7
    crw-rw-rw- 1 root root 237,  8 Jul 13 17:58 /dev/hidraw8
    crw------- 1 root root 237,  9 Jul 13 17:58 /dev/hidraw9

(Notice that some filea have "crw-rw-rw-" permissions. That means they have read and write support for everyone.)

### Installing SteelSeries Engine

- After you run the installation script (and reboot), you can install Steelseries Engine in Lutris.
- Open Lutris -> click on **+** icon
- Choose `Search the Lutris website for installers`
- Search for `Steelseries GG` (**important** make sure you don't choose `Steelseries Engine` this installation is outdated and won't work) (https://lutris.net/games/steelseries-gg/)
- Click install and follow the instructions

## What Works

* Changing settings for most of your Steelseries devices (eg. mouse DPI)
* Prism to control light effects on your Steelseries devices

## What Doesn't

* Device hotplugging does not work. If you unplug a device you will need to restart Engine for it to show up again.
* You should generally only use Engine as pointed above and assume everything else will not work.