from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true

from mojo_csv import CsvReader


fn test_methods() raises:
    try:
        var in_csv: Path = cwd().joinpath("tests/test.csv")
        var rd = CsvReader(in_csv)
        assert_true(String("repr: {}").format(repr(rd)))
        assert_true(String("len: {}").format(len(rd)))
        assert_true(String("print: {}").format(rd))
        assert_true(String("slice: {}").format(rd[0]))
        assert_true(String("slice repr: {}").format(repr(rd[0])))
        assert_true("iter:...")
        for x in rd:
            assert_true(x)
    except AssertionError:
        raise 
