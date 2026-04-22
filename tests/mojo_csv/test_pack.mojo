from std.pathlib import Path, cwd
from std.testing import assert_true

from mojo_csv import CsvReader


fn test_basic() raises:
    var VALID = List[String]()
    VALID.append("item1")
    VALID.append("item2")
    VALID.append('"ite,em3"')
    VALID.append('"p""ic"')
    VALID.append(" pi c")
    VALID.append("pic")
    VALID.append("r_i_1")
    VALID.append('"r_i_2"""')
    VALID.append("r_i_3")

    var in_csv: Path = cwd().joinpath("test_data.csv")
    # Write test data to a temp file
    in_csv.write_text(
        'item1,item2,"ite,em3"\n'
        '"p""ic", pi c,pic,\n'
        'r_i_1,"r_i_2""",r_i_3,\n'
    )
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
    print("parse successful")


fn main():
    try:
        test_basic()
    except:
        print("error")