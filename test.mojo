from collections import Dict, List
from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true

from src.csv_reader import CsvReader

var VALID = List[String](
    "item1",
    "item2",
    '"ite,em3"',
    "pic",
    " pi c",
    "pic",
    "r_i_1",
    "r_i_2",
    "r_i_3",
)


fn main() raises:
    var in_csv: Path = Path(argv()[1])
    var rd = CsvReader(in_csv)
    print(in_csv)
    print("columns:", rd.col_count)
    print("----------")
    try:
        for x in range(len(rd.elements)):
            print(rd.elements[x])
            assert_true(
                rd.elements[x] == VALID[x],
                String("[{0}] != expected [{1}] at index {2}").format(
                    rd.elements[x], VALID[x], x
                ),
            )
        assert_true(len(rd.elements) == 9)
    except AssertionError:
        raise AssertionError
    print("----------")
    print("parse successful")


# columns: 3
# ----------
# item1
# item2
# "ite,em3"
# pic
#  pi c
# pic
# r_i_1
# r_i_2
# r_i_3
