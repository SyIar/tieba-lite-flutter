"""Validate an unsigned iOS device package without claiming signature validity."""

import argparse
import plistlib
import struct
import zipfile
from pathlib import PurePosixPath


def require_arm64(executable):
    if len(executable) < 32:
        raise ValueError("Executable is truncated")
    magic = executable[:4]
    if magic == b"\xcf\xfa\xed\xfe":
        if struct.unpack_from("<I", executable, 4)[0] != 0x0100000C:
            raise ValueError("Device executable is not arm64")
        return
    formats = {
        b"\xca\xfe\xba\xbe": (">", 20, "II"),
        b"\xca\xfe\xba\xbf": (">", 32, "QQ"),
        b"\xbe\xba\xfe\xca": ("<", 20, "II"),
        b"\xbf\xba\xfe\xca": ("<", 32, "QQ"),
    }
    if magic not in formats:
        raise ValueError("Executable is not a supported Mach-O")
    endian, stride, sizes = formats[magic]
    count = struct.unpack_from(endian + "I", executable, 4)[0]
    if not 1 <= count <= 32 or 8 + count * stride > len(executable):
        raise ValueError("Invalid universal Mach-O header")
    for index in range(count):
        cursor = 8 + index * stride
        cpu = struct.unpack_from(endian + "I", executable, cursor)[0]
        offset, size = struct.unpack_from(endian + sizes, executable, cursor + 8)
        if offset < 8 + count * stride or size < 32 or offset + size > len(executable):
            raise ValueError("Invalid universal Mach-O slice")
        if cpu == 0x0100000C:
            require_arm64(executable[offset:offset + size])
            return
    raise ValueError("Universal device executable has no arm64 slice")


def verify(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("IPA contains a corrupt ZIP member")
        names = set(archive.namelist())
        if len(names) != len(archive.namelist()):
            raise ValueError("Duplicate IPA member path")
        for name in names:
            if name.startswith("/") or ".." in PurePosixPath(name).parts:
                raise ValueError("Unsafe IPA member path")
        prefix = "Payload/Runner.app/"
        required = ["Info.plist", "Runner", "Frameworks/App.framework/App", "Frameworks/Flutter.framework/Flutter"]
        for relative in required:
            if prefix + relative not in names:
                raise ValueError(f"Missing IPA member: {relative}")
        info = plistlib.loads(archive.read(prefix + "Info.plist"))
        if info.get("DTPlatformName") != "iphoneos":
            raise ValueError("IPA must contain an iOS device build")
        if info.get("CFBundleExecutable") != "Runner":
            raise ValueError("Unexpected executable")
        if not info.get("CFBundleIdentifier"):
            raise ValueError("Bundle identifier is missing")
        for relative in required[1:]:
            require_arm64(archive.read(prefix + relative))
        print(f"IPA structure valid: {info['CFBundleIdentifier']} ({info.get('CFBundleVersion')})")
        print("Unsigned package; local re-signing and iPhone acceptance are still required.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa")
    verify(parser.parse_args().ipa)
