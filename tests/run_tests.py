#!/usr/bin/env python3
"""Lance les tests ComputerWeb avec LuaJIT (lupa) et un faux Garry's Mod.

Usage :  python3 tests/run_tests.py
Prérequis : pip install lupa
"""
import os
import sys

try:
    from lupa import luajit21 as L
except Exception:  # pragma: no cover
    from lupa import LuaRuntime as _LR

    class L:  # repli
        LuaRuntime = _LR

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def main() -> int:
    lua = L.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f'package.path = "{HERE}/?.lua;" .. package.path')
    lua.execute(f'MOCK_ROOT = "{ROOT}"')
    lua.execute('dofile("%s/mock_gmod.lua")' % HERE)
    lua.execute('MOCK.root = MOCK_ROOT')
    ok = lua.execute('return dofile("%s/test_suite.lua")' % HERE)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
