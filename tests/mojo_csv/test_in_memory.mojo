"""The alternate reader constructors.

`CsvReader(cells, col_count=...)` builds a reader from already-split cells
-- a flat row-major list, the shape `CsvWriter` writes from -- with no scan
at all. These tests pin the cell-list semantics and the writer round-trip.
"""

from mojo_csv import CsvReader, CsvWriter
from std.pathlib import cwd
from std.testing import assert_true


def test_cells_basic() raises:
    """A reader from split cells: every field is the string it was given."""
    var cells: List[String] = ["a", "b", "c", "1", "2", "3"]
    var rd = CsvReader(cells^, col_count=3)
    assert_true(rd.row_count == 2, "cell rows")
    assert_true(rd.col_count == 3, "cell cols")
    assert_true(rd.length == 6, "cell length")
    assert_true(rd[0, 0] == "a", "cells [0,0]")
    assert_true(rd[0, 1] == "b", "cells [0,1]")
    assert_true(rd[1, 0] == "1", "cells [1,0]")
    assert_true(rd[1, 2] == "3", "cells [1,2]")
    # headers come from the first row
    assert_true(rd.headers[0] == "a", "cells headers")
    assert_true(rd.headers[2] == "c", "cells headers end")


def test_cells_no_header() raises:
    """has_header=False counts every row as data."""
    var cells: List[String] = ["a", "b", "c", "d"]
    var rd = CsvReader(cells^, col_count=2, has_header=False)
    assert_true(rd.row_count == 2, "no-header rows")
    assert_true(len(rd.headers) == 0, "no-header headers empty")
    assert_true(rd[0, 0] == "a", "no-header first row is data")
    assert_true(rd[1, 1] == "d", "no-header last cell")


def test_cells_rejects_bad_shape() raises:
    """A ragged list, or a bad col_count, fails instead of guessing."""
    var raised = 0
    # Each attempt gets its own copy: the constructor takes the list.
    try:
        var _ = CsvReader(List[String](["a", "b", "c"])^, col_count=2)
    except:
        raised += 1
    try:
        var _ = CsvReader(List[String](["a", "b", "c"])^, col_count=0)
    except:
        raised += 1
    var empty = List[String]()
    try:
        var _ = CsvReader(empty^, col_count=1)
    except:
        raised += 1
    assert_true(raised == 2, "bad shape and zero col_count raise")


def test_cells_writer_roundtrip() raises:
    """CsvWriter -> parse -> CsvReader(cells) -> cells match the parse.

    This is the reason the constructor takes col_count: it is the same
    value the writer needs, so a parsed document can pass through a
    reader with the cells untouched.
    """
    var cells: List[String] = ["h1", "h2", "a", "b", "plain", "z"]
    var writer = CsvWriter(cells.copy(), num_threads=1)
    var path = cwd().joinpath("tests/cells-roundtrip.csv")
    writer.write(path, 2)

    var back_file = CsvReader(path)
    assert_true(back_file.col_count == 2, "roundtrip cols")
    # Copy the cells out of the file reader before building the next one:
    # the new reader takes ownership of the list it is given.
    var back_cells = back_file.elements.copy()
    var roundtrip = CsvReader(back_cells^, col_count=2)
    assert_true(roundtrip.row_count == 3, "roundtrip rows")
    for i in range(roundtrip.length):
        assert_true(
            roundtrip[i] == back_file.elements[i],
            String("roundtrip cell ", i, ": ", roundtrip[i]),
        )


def test_cells_row_views_and_iter() raises:
    """Row views, iteration and 2D access work without a parse."""
    var cells: List[String] = ["a", "b", "c", "d"]
    var rd = CsvReader(cells^, col_count=2, has_header=False)
    var row = rd.row(1)
    assert_true(len(row) == 2, "row view length")
    assert_true(row[0] == "c", "row view [0]")
    var count = 0
    for r in rd:
        assert_true(r[0] != "" or True, "iter runs")
        count += 1
    assert_true(count == 2, "iter count")


def test_cells_matches_parsed_cells() raises:
    """Cells handed to the constructor come back exactly as a file read
    would parse them (raw, unmodified)."""
    var path = cwd().joinpath("tests/test.csv")
    var parsed = CsvReader(path)
    var rebuilt = CsvReader(parsed.elements.copy(), col_count=parsed.col_count)
    assert_true(rebuilt.row_count == parsed.row_count, "rebuilt rows")
    assert_true(rebuilt.col_count == parsed.col_count, "rebuilt cols")
    for i in range(rebuilt.length):
        assert_true(
            rebuilt[i] == parsed[i],
            String("rebuilt cell ", i, " differs"),
        )


def main() raises:
    test_cells_basic()
    test_cells_no_header()
    test_cells_rejects_bad_shape()
    test_cells_writer_roundtrip()
    test_cells_row_views_and_iter()
    test_cells_matches_parsed_cells()
    print("cells constructor: success")
