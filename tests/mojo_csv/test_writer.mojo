from pathlib import Path, cwd
from testing import assert_true

from mojo_csv import CsvWriter, CsvReader


fn test_csv_writer_basic() raises:
    # Prepare a small dataset: headers + 2 rows
    var elements = List[String](
        "Name",
        "Note",
        "val",
        "fawn",
        'He said "hi"',
        "10",
        '"already,quoted"',
        "plain",
        "word",
    )
    var col_count = 3

    # Expected CSV text (no trailing newline)
    var expected = String(
        "Name,Note,val\n" + 'fawn,"He said ""hi""",10\n' + '"already,quoted",plain,word'
    )

    # Write
    var out_path: Path = cwd().joinpath("tests/writer-test.csv")
    var writer = CsvWriter(elements)
    writer.write(out_path, col_count)

    # Check file contents
    var got = out_path.read_text()
    print("expected: ")
    print(expected)
    print("------------------")
    print("got:")
    print(got)
    print("------------------")
    assert_true(
        got == expected,
        String("CSV text mismatch.\nGot:\n{0}\nExpected:\n{1}").format(got, expected),
    )

    # Read back and ensure we're compatible
    var reader = CsvReader(out_path, num_threads=1)

    var expected_list = List[String](
        "Name",
        "Note",
        "val",
        "fawn",
        '"He said ""hi"""',
        "10",
        '"already,quoted"',
        "plain",
        "word",
    )

    print("col: ", reader.col_count, " vs ", col_count)
    assert_true(reader.col_count == col_count)
    print("len: ", len(reader), " vs ", len(expected_list))
    for el in reader.elements:
        print(el)
    assert_true(len(reader) == len(expected_list))
    for i in range(len(expected_list)):
        print(
            String("[{0}] != expected [{1}] at index {2}").format(
                reader[i], expected_list[i], i
            ),
        )
        assert_true(
            reader[i] == expected_list[i],
            String("[{0}] != expected [{1}] at index {2}").format(
                reader[i], expected_list[i], i
            ),
        )


fn main():
    try:
        test_csv_writer_basic()
        print("csv_writer test: success")
    except:
        print("csv_writer test: error")
