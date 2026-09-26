from std.pathlib import Path, cwd
from std.testing import assert_true

from mojo_csv import CsvWriter, CsvReader, DictCsvReader


def test_csv_writer_basic() raises:
    """Exact encoding of quoting rules + roundtrip through the reader."""
    # Prepare a small dataset: headers + 2 rows
    var elements = List[String]()
    elements.append("Name")
    elements.append("Note")
    elements.append("val")
    elements.append("fawn")
    elements.append('He said "hi"')
    elements.append("10")
    elements.append('"already,quoted"')
    elements.append("plain")
    elements.append("word")
    var col_count = 3

    # Expected CSV text (no trailing newline)
    var expected = String(
        "Name,Note,val\n" + 'fawn,"He said ""hi""",10\n' + '"already,quoted",plain,word'
    )

    # Write
    var out_path: Path = cwd().joinpath("tests/writer-test.csv")
    var writer = CsvWriter(elements, num_threads=1)
    writer.write(out_path, col_count)

    # Check file contents
    var got = out_path.read_text()
    assert_true(
        got == expected,
        String("CSV text mismatch.\nGot:\n{0}\nExpected:\n{1}").format(got, expected),
    )

    # Read back and ensure we're compatible
    var reader = CsvReader(out_path, num_threads=1)

    var expected_list = List[String]()
    expected_list.append("Name")
    expected_list.append("Note")
    expected_list.append("val")
    expected_list.append("fawn")
    expected_list.append('"He said ""hi"""')
    expected_list.append("10")
    expected_list.append('"already,quoted"')
    expected_list.append("plain")
    expected_list.append("word")

    assert_true(reader.col_count == col_count)
    assert_true(len(reader) == len(expected_list))
    for i in range(len(expected_list)):
        assert_true(
            reader[i] == expected_list[i],
            String("[{0}] != expected [{1}] @idx {2}").format(
                reader[i], expected_list[i], i
            ),
        )


def test_trailing_newline_modes() raises:
    var elements = List[String]()
    for i in range(6):
        elements.append("c" + String(i))
    var writer = CsvWriter(elements, num_threads=1)
    var out = cwd().joinpath("tests/writer-nl.csv")

    writer.write(out, 2, include_trailing_newline=False)
    var no_nl = out.read_text()
    assert_true(no_nl == "c0,c1\nc2,c3\nc4,c5", "no trailing newline content")
    assert_true(not no_nl.endswith("\n"), "no trailing newline flag honored")

    writer.write(out, 2, include_trailing_newline=True)
    var with_nl = out.read_text()
    assert_true(with_nl == no_nl + "\n", "trailing newline is exactly one byte")


def test_threaded_matches_single() raises:
    """Threaded write must be byte-identical to the single-threaded write."""
    var rd = CsvReader(cwd().joinpath("tests/datablist/organizations-1000.csv"))
    var out_single = cwd().joinpath("tests/writer-match-single.csv")
    var out_threaded = cwd().joinpath("tests/writer-match-threaded.csv")

    var w1 = CsvWriter(rd.elements, num_threads=1)
    w1.write(out_single, rd.col_count)
    var w30 = CsvWriter(rd.elements, num_threads=30)
    w30.write(out_threaded, rd.col_count)

    assert_true(
        out_single.read_text() == out_threaded.read_text(),
        "threaded output differs from single-threaded",
    )

    # Same with trailing newline
    w1.write(out_single, rd.col_count, include_trailing_newline=True)
    w30.write(out_threaded, rd.col_count, include_trailing_newline=True)
    assert_true(
        out_single.read_text() == out_threaded.read_text(),
        "threaded output (trailing newline) differs",
    )


def test_custom_delimiter() raises:
    var elements = List[String]()
    elements.append("a")
    elements.append("b")
    elements.append("x")
    elements.append("y")
    var writer = CsvWriter(elements, delimiter=";", num_threads=1)
    var out = cwd().joinpath("tests/writer-delim.csv")
    writer.write(out, 2)
    assert_true(out.read_text() == "a;b\nx;y", "semicolon delimiter")

    # read back with the same delimiter
    var back = CsvReader(out, delimiter=";")
    assert_true(back[0, 0] == "a" and back[1, 1] == "y", "read back custom delimiter")


def test_roundtrip_via_dict() raises:
    """Write, then read back through DictCsvReader and verify keyed access."""
    var headers = List[String]()
    headers.append("name")
    headers.append("score")
    var body = List[String]()
    body.append("alice")
    body.append("95")
    body.append("bob")
    body.append("87")

    var out = cwd().joinpath("tests/writer-roundtrip.csv")
    var frame: List[String] = []
    for h in headers:
        frame.append(h)
    for c in body:
        frame.append(c)
    var writer = CsvWriter(frame, num_threads=30)
    writer.write(out, 2, include_trailing_newline=True)

    var dr = DictCsvReader(out)
    assert_true(len(dr) == 2, "roundtrip row count")
    assert_true(dr.headers[0] == "name" and dr.headers[1] == "score", "headers")
    var idx = 1
    for row in dr:
        assert_true(
            row.get("name") == body[(idx - 1) * 2]
            and row.get("score") == body[idx * 2 - 1],
            "roundtrip keyed access",
        )
        idx += 1


def main() raises:
    test_csv_writer_basic()
    test_trailing_newline_modes()
    test_threaded_matches_single()
    test_custom_delimiter()
    test_roundtrip_via_dict()
    print("csv_writer tests: success")
