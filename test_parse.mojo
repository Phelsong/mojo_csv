from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true

from src.csv_reader import CsvReader


fn main() raises:
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
        t_methods(rd)

    except AssertionError:
        # print(AssertionError)
        raise AssertionError
    print("----------")
    print("parse successful")


fn t_methods(rd: CsvReader) raises:
    try:
        print(String("repr: {}").format(repr(rd)))
        print(String("len: {}").format(len(rd)))
        print(String("print: {}").format(rd))
        print(String("slice: {}").format(rd[0]))
        print(String("slice repr: {}").format(repr(rd[0])))
        print("iter: ...")
        print("----")
        for x in rd:
            print(x)
        print("----")
    except:
        print("error")
        raise
