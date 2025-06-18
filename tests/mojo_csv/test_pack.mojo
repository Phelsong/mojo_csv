from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true

from mojo_csv import CsvReader

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


fn test_pack() raises:
    var in_csv: Path = cwd().joinpath("tests/test.csv")
    var rd = CsvReader(in_csv)
    # print(rd)
    print("parsing:", in_csv)
    print("----------")
    try:
        assert_true(rd.col_count == 3)
        for x in range(len(rd)):
            print(rd.elements[x])
            assert_true(
                rd.elements[x] == VALID[x],
                String("[{0}] != expected [{1}] at index {2}").format(
                    rd.elements[x], VALID[x], x
                ),
            )
        print("----------")
        print("columns:", rd.col_count, "of 3")
        print("rows:", rd.row_count, "of 3")
        assert_true(rd.row_count == 3)
        print("elements:", rd.__len__(), "of 9")
        assert_true(len(rd.elements) == 9)

        # for x in rd:
        # print(x)
    except AssertionError:
        print(AssertionError)
        raise AssertionError
    print("----------")
    print("parse successful")
