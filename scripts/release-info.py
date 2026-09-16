#!/usr/bin/env python3
"""Validate a release tag and emit safe GitHub Actions output values."""
import re
import sys


def release_info(tag: str) -> dict[str, str]:
    number = r'(?:0|[1-9][0-9]*)'
    match = re.fullmatch(rf'v({number}\.{number}\.{number})(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?', tag)
    if not match:
        raise ValueError('Tag must be vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-prerelease (e.g. v0.1.0-beta.1)')
    suffix = match.group(2)
    if suffix and any(part.isdigit() and len(part) > 1 and part.startswith('0') for part in suffix.split('.')):
        raise ValueError('Numeric prerelease identifiers must not contain leading zeroes')
    return {'version': match.group(1), 'label': tag, 'prerelease': str(suffix is not None).lower()}


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('Usage: release-info.py vMAJOR.MINOR.PATCH[-prerelease]')
        for key, value in release_info(sys.argv[1]).items():
            print(f'{key}={value}')
    except ValueError as error:
        sys.exit(str(error))
