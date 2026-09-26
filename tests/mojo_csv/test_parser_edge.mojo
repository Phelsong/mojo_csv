from std.pathlib import Path, cwd
from std.testing import assert_true

from mojo_csv import CsvReader, CsvWriter


def test_crlf() raises:
    """Windows line endings are normalized."""
    var path = cwd().joinpath("test_data_crlf.csv")
    var reader = CsvReader(path)
    assert_true(reader.row_count == 2, "crlf row count")
    assert_true(reader.col_count == 3, "crlf col count")
    assert_true(reader[0, 0] == "a", "crlf [0,0]")
    assert_true(reader[1, 2] == "f", "crlf [1,2]")


def test_quoted_cells() raises:
    """Embedded delimiters, doubled quotes, and leading spaces are preserved."""
    var rd = CsvReader(cwd().joinpath("tests/test.csv"))
    # fixture values exercise embedded commas, doubled quotes, and spaces
    assert_true(rd[1, 0] == '"p""ic"', "doubled quote cell preserved raw")
    assert_true(rd[1, 1] == " pi c", "leading space preserved")
    assert_true(rd[0, 2] == '"ite,em3"', "quoted header preserved raw")


def test_no_trailing_newline() raises:
    """A file whose last line has no newline still counts that row."""
    var path = cwd().joinpath("tests/writer-delim.csv")  # "a;b\nx;y"
    var reader = CsvReader(path, delimiter=";")
    assert_true(reader.row_count == 2, "row count without trailing newline")
    assert_true(reader[1, 1] == "y", "last cell without trailing newline")


def test_small_files_fall_back_to_single_thread() raises:
    """Files below the threading threshold parse identically."""
    var path = cwd().joinpath("tests/test.csv")  # 64 bytes
    var forced = CsvReader(path, num_threads=1)
    var default = CsvReader(path)
    assert_true(
        forced.elements == default.elements, "small file: default == forced single"
    )
    assert_true(forced.row_count == default.row_count, "small file row counts")


def test_custom_delimiter_read() raises:
    var path = cwd().joinpath("tests/writer-delim.csv")  # "a;b\nx;y"
    var reader = CsvReader(path, delimiter=";")
    assert_true(reader.col_count == 2, "custom delimiter col count")
    assert_true(reader[0, 1] == "b", "custom delimiter cell")


def test_quoted_field_with_delimiter_and_newline() raises:
    """A quoted field containing delimiters and embedded newlines roundtrips."""
    var elements = List[String]()
    elements.append("plain")
    elements.append("has,comma")
    elements.append('has"quote')
    elements.append("multi\nline")
    var writer = CsvWriter(elements, num_threads=1)
    var path = cwd().joinpath("tests/writer-edge.csv")
    writer.write(path, 2, include_trailing_newline=True)

    var back = CsvReader(path)
    # cells keep their CSV-encoded form, matching CsvReader behavior on
    # hand-written fixtures (see test_quoted_cells)
    assert_true(back[0, 1] == '"has,comma"', "embedded delimiter stays quoted")
    assert_true(back[1, 0] == '"has""quote"', "embedded quote stays escaped")
    assert_true(back[1, 1] == '"multi\nline"', "embedded newline stays quoted")
    assert_true(back.row_count == 2, "embedded newline does not split rows")


def main() raises:
    test_crlf()
    test_quoted_cells()
    test_no_trailing_newline()
    test_small_files_fall_back_to_single_thread()
    test_custom_delimiter_read()
    test_quoted_field_with_delimiter_and_newline()
    print("parser edge tests: success")
