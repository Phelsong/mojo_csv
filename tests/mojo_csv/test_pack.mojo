from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true

from mojo_csv import CsvReader


fn test_pack() raises:
    var VALID = List[String](
        "item1",
        "item2",
        '"ite,em3"',
        '"p""ic"',
        " pi c",
        "pic",
        "r_i_1",
        '"r_i_2"""',
        "r_i_3",
    )
    try:
        var in_csv: Path = cwd().joinpath("tests/test.csv")
        var rd = CsvReader(in_csv)
        assert_true(rd.col_count == 3)
        for x in range(len(rd)):
            assert_true(
                rd.elements[x] == VALID[x],
                String("[{0}] != expected [{1}] at index {2}").format(
                    rd.elements[x], VALID[x], x
                ),
            )
        assert_true(rd.row_count == 3)
        assert_true(len(rd.elements) == 9)

    except AssertionError:
        raise AssertionError
    print("parse successful")
