from pathlib import Path, cwd
from testing import assert_true

from mojo_csv import CsvReader, DictCsvReader


fn test_dict_reader_basic() raises:
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


def main():
    try:
        test_dict_reader_basic()
        print("success")
    except:
        print("error")
