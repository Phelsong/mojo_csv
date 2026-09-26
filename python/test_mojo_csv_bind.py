"""Tests for the mojo_csv Python bindings (python/mojo_csv_bind.mojo).

Run with: pixi run python python/test_mojo_csv_bind.py
Requires python/mojo_csv_bind.so (built via: pixi run build-python-bindings).
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

import mojo_csv_bind as m  # noqa: E402

FIXTURE = os.path.join("tests", "test.csv")


def test_parse_csv():
    cells = m.parse_csv(FIXTURE)
    assert cells == [
        "item1",
        "item2",
        '"ite,em3"',
        '"p""ic"',
        " pi c",
        "pic",
        "r_i_1",
        '"r_i_2"""',
        "r_i_3",
    ], f"unexpected cells: {cells}"


def test_dimensions():
    assert m.row_count(FIXTURE) == 3
    assert m.col_count(FIXTURE) == 3


def test_cell():
    assert m.cell(FIXTURE, 0, 0) == "item1"
    assert m.cell(FIXTURE, 2, 1) == '"r_i_2"""'
    assert m.cell(FIXTURE, 1, 2) == "pic"


def test_headers():
    assert m.headers(FIXTURE) == ["item1", "item2", '"ite,em3"']


def test_dict_rows():
    rows = m.dict_rows(FIXTURE)
    assert rows == [
        {"item1": '"p""ic"', "item2": " pi c", '"ite,em3"': "pic"},
        {"item1": "r_i_1", "item2": '"r_i_2"""', '"ite,em3"': "r_i_3"},
    ]
    # keyed access on the real structure
    assert rows[0]["item2"] == " pi c"
    assert rows[1]["item1"] == "r_i_1"


def test_write_csv_roundtrip():
    out_path = os.path.join("python", "py-roundtrip.csv")
    rows = m.write_csv(["name", "score", "alice", "95", "bob", "87"], 2, out_path)
    assert rows == 3  # 6 cells / 2 columns = 3 rows

    # read it back through the Mojo bindings
    assert m.parse_csv(out_path) == ["name", "score", "alice", "95", "bob", "87"]
    assert m.dict_rows(out_path) == [
        {"name": "alice", "score": "95"},
        {"name": "bob", "score": "87"},
    ]
    os.remove(out_path)


def test_reader_class():
    """The Reader type parses once; row/cell access reuses the grid."""
    reader = m.Reader(FIXTURE)
    assert reader.row_count() == 3
    assert reader.col_count() == 3
    assert reader.length() == 9
    assert reader.cell(1, 2) == "pic"
    assert reader.headers() == ["item1", "item2", '"ite,em3"']

    # per-row access mirrors csv.reader output
    row0 = reader.get_row(0)
    assert row0 == ["item1", "item2", '"ite,em3"']
    row2 = reader.get_row(2)
    assert row2 == ["r_i_1", '"r_i_2"""', "r_i_3"]

    # threaded construction
    rt = m.Reader(FIXTURE, 4)
    assert rt.row_count() == 3

    # bulk view
    assert len(reader.all_cells()) == 9

    try:
        reader.get_row(99)
        raise AssertionError("expected row OOB")
    except Exception as e:
        assert "Row index out of range" in str(e)


def test_error_propagation():
    # Missing files raise a Mojo error surfaced as a Python exception
    try:
        m.parse_csv("does/not/exist.csv")
        raise AssertionError("expected an exception for a missing file")
    except Exception as e:
        assert "File not found" in str(e)


def main():
    test_parse_csv()
    test_dimensions()
    test_cell()
    test_headers()
    test_dict_rows()
    test_write_csv_roundtrip()
    test_reader_class()
    test_error_propagation()
    print("python binding tests: success")


if __name__ == "__main__":
    main()
