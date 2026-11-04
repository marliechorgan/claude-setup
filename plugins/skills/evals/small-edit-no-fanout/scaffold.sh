#!/bin/sh
set -e
printf 'def total(xs):\n    tot = 0\n    for x in xs:\n        tot += x\n    return tot\n' > utils.py
