from std.pathlib import Path, cwd
from std.testing import assert_true, assert_raises

from mojo_csv import CsvReader, CsvRowView


def test_2d_tuple_indexing() raises:
    """reader[row, col] returns the cell at that position."""
    var rd = CsvReader(cwd().joinpath("tests/test.csv"))

    # Fixture (tests/test.csv), row-major:
    #   item1, item2, "ite,em3"
    #   "p""ic", " pi c", pic
    #   r_i_1, "r_i_2""", r_i_3
    assert_true(rd[0, 0] == "item1", "rd[0,0]")
    assert_true(rd[0, 2] == '"ite,em3"', "rd[0,2]")
    assert_true(rd[1, 0] == '"p""ic"', "rd[1,0]")
    assert_true(rd[2, 1] == '"r_i_2"""', "rd[2,1]")
    assert_true(rd[2, 2] == "r_i_3", "rd[2,2]")

    # 2D must agree with flat indexing
    var flat = 0
    for row in range(rd.row_count):
        for col in range(rd.col_count):
            assert_true(rd[row, col] == rd.elements[flat], "2d == flat at {0},{1}")
            flat += 1


def test_row_view() raises:
    var rd = CsvReader(cwd().joinpath("tests/test.csv"))

    var row = rd.row(1)
    assert_true(len(row) == 3, "row view length")
    assert_true(row[0] == '"p""ic"', "row[0]")
    assert_true(row[2] == "pic", "row[2]")
    assert_true(row.col_count() == rd.col_count, "row col_count")

    # repr is readable
    var text = String("row: {}").format(repr(row))
    assert_true(text == "row: ['\"p\"\"ic\"', ' pi c', 'pic']", "row repr")

    # every row view agrees with tuple indexing
    for r in range(rd.row_count):
        var view = rd.row(r)
        for c in range(rd.col_count):
            assert_true(view[c] == rd[r, c], "view vs tuple at {0},{1}")


def test_out_of_bounds() raises:
    var rd = CsvReader(cwd().joinpath("tests/test.csv"))

    try:
        var _ = rd[3, 0]
        assert_true(False, "row OOB must raise")
    except e:
        assert_true(String(e) == "Row index out of range", "row OOB message")

    try:
        var _ = rd[0, 3]
        assert_true(False, "col OOB must raise")
    except e:
        assert_true(String(e) == "Column index out of range", "col OOB message")

    try:
        var view = rd.row(7)
        var _ = view[0]
        assert_true(False, "row() OOB must raise")
    except e:
        assert_true(String(e) == "Row index out of range", "row() OOB message")

    try:
        var _ = rd.row(1)[9]
        assert_true(False, "view col OOB must raise")
    except e:
        assert_true(String(e) == "Column index out of range", "view col OOB message")


def test_iterate_rows() raises:
    var rd = CsvReader(cwd().joinpath("tests/test.csv"))

    var row_num: Int = 0
    for row in rd:
        assert_true(len(row) == rd.col_count, "iterated row length")
        for c in range(rd.col_count):
            assert_true(row[c] == rd[row_num, c], "iterated cell value")
        row_num += 1
    assert_true(row_num == rd.row_count, "iteration count == row_count")

    # row views are truthy while the reader has columns
    assert_true(rd.row(0), "row view truthiness")


def test_threaded_matches_single_2d() raises:
    var path = cwd().joinpath("tests/datablist/organizations-1000.csv")
    var single = CsvReader(path, num_threads=1)
    var threaded = CsvReader(path)

    assert_true(single.row_count == threaded.row_count, "row counts match")
    assert_true(single.col_count == threaded.col_count, "col counts match")

    # Spot-check the 2D grid across thread-chunk boundaries
    var rows_to_check = min(50, single.row_count)
    for r in range(rows_to_check):
        for c in range(single.col_count):
            assert_true(
                single[r, c] == threaded[r, c],
                String("2d mismatch at {0},{1}").format(r, c),
            )


def main() raises:
    test_2d_tuple_indexing()
    test_row_view()
    test_out_of_bounds()
    test_iterate_rows()
    test_threaded_matches_single_2d()
    print("2d tests: success")
