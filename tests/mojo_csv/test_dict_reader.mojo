from std.pathlib import Path, cwd
from std.testing import assert_true

from mojo_csv import CsvReader, DictCsvReader


def test_dict_reader_basic() raises:
    """Headers, dimensions, and cell alignment against the flat reader."""
    var in_csv: Path = cwd().joinpath("tests/test.csv")
    var rd = CsvReader(in_csv)
    var dr = DictCsvReader(in_csv)

    # Headers
    assert_true(len(rd.headers) == len(dr.headers))
    for i in range(len(rd.headers)):
        assert_true(rd.headers[i] == dr.headers[i])

    # Dimensions
    assert_true(dr.col_count == rd.col_count)
    assert_true(dr.row_count == rd.row_count)
    assert_true(len(dr) == max(0, rd.row_count - 1))

    # First data row by dict access
    if dr.row_count > 1:
        var row1 = dr[1]
        for c in range(dr.col_count):
            var key = dr.headers[c]
            var val = row1.get(key)
            # Compare with underlying reader element
            var idx = 1 * dr.col_count + c
            assert_true(val == rd[idx])

    # Iterate all rows and verify cell alignment
    var row_num: Int = 1
    for row in dr:
        for c in range(dr.col_count):
            var key = dr.headers[c]
            var val = row.get(key)
            var idx = row_num * dr.col_count + c
            assert_true(val == rd[idx])
        row_num += 1


def test_row_accessors() raises:
    var dr = DictCsvReader(cwd().joinpath("tests/test.csv"))

    var row = dr[1]
    # get / get_at
    assert_true(row.get("item1") == '"p""ic"', "get by header name")
    assert_true(row.get_at(2) == "pic", "get_at positional")
    try:
        var _ = row.get("missing-key")
        assert_true(False, "get with unknown key must raise")
    except e:
        assert_true(String(e) == "Key not found: missing-key", "unknown key message")
    try:
        var _ = row.get_at(42)
        assert_true(False, "get_at OOB must raise")
    except e:
        assert_true(String(e) == "Index out of range", "get_at OOB message")

    # keys / vals return owned copies
    var keys = row.keys()
    var vals = row.vals()
    assert_true(len(keys) == 3 and len(vals) == 3, "keys/vals lengths")
    assert_true(keys[0] == "item1", "keys[0]")
    assert_true(vals[1] == " pi c", "vals[1]")

    # row repr is a dict-style string
    var text = String("row: {}").format(repr(row))
    assert_true(
        text == "row: {'item1': '\"p\"\"ic\"', 'item2': ' pi c', '\"ite,em3\"': 'pic'}",
        "row repr",
    )


def test_header_sharing() raises:
    """All rows share one refcounted header list (cheap copies)."""
    var dr = DictCsvReader(cwd().joinpath("tests/datablist/organizations-1000.csv"))

    var seen = 0
    var first_repr = repr(dr[1])
    for row in dr:
        # every row reports the same headers
        var keys = row.keys()
        for c in range(len(keys)):
            assert_true(keys[c] == dr.headers[c], "shared header mismatch")
        seen += 1
    assert_true(seen == len(dr), "iterated all data rows")
    assert_true(repr(dr[1]) == first_repr, "row views are stable")


def test_iter_matches_getitem() raises:
    var dr = DictCsvReader(cwd().joinpath("tests/test.csv"))
    var idx: Int = 1
    for row in dr:
        var via_getitem = dr[idx]
        for c in range(dr.col_count):
            var key = dr.headers[c]
            assert_true(row.get(key) == via_getitem.get(key), "iter vs getitem")
        idx += 1


def main() raises:
    test_dict_reader_basic()
    test_row_accessors()
    test_header_sharing()
    test_iter_matches_getitem()
    print("dict reader tests: success")
