from pathlib import Path, cwd
from mojo_csv import CsvReader, ThreadedCsvReader
from testing import assert_true
from logger import Logger


fn test_correctness():
    """Test that threaded reader produces same results as single-threaded."""
    try:
        var in_csv = cwd().joinpath("tests/datablist/organizations-1000.csv")

        # Single-threaded
        var single_reader = CsvReader(in_csv)

        # Multi-threaded
        var threaded_reader = ThreadedCsvReader(in_csv)

        print("=== Correctness Test ===")
        print("Single-threaded length:", single_reader.length)
        print("Multi-threaded length:", threaded_reader.length)
        assert_true(
            len(single_reader) == len(threaded_reader),
            "!! lengths don't match ",
        )

        print("Single-threaded row count:", single_reader.row_count)
        print("Multi-threaded row count:", threaded_reader.row_count)
        assert_true(
            single_reader.row_count == threaded_reader.row_count,
            "!! row counts don't match",
        )

        print("Single-threaded col count:", single_reader.col_count)
        print("Multi-threaded col count:", threaded_reader.col_count)
        assert_true(
            single_reader.col_count == threaded_reader.col_count,
            "!! column counts don't match",
        )

        # Check first few elements
        var elements_match = True
        var check_count = min(100, len(single_reader))

        for i in range(check_count):
            if single_reader[i] != threaded_reader[i]:
                print("Element mismatch at index", i)
                print("Single:", single_reader[i])
                print("Threaded:", threaded_reader[i])
                elements_match = False
                break

        assert_true(elements_match)
        print("First", check_count, "elements match:", elements_match)

        # Check headers
        var headers_match = True
        if len(single_reader.headers) == len(threaded_reader.headers):
            for i in range(len(single_reader.headers)):
                if single_reader.headers[i] != threaded_reader.headers[i]:
                    headers_match = False
                    break
        else:
            headers_match = False

        assert_true(headers_match)
        print("Headers match:", headers_match)

        if elements_match and headers_match:
            print("✅ All correctness tests PASSED")
        else:
            print("❌ Some correctness tests FAILED")

    except:
        print("Error in test")


fn main():
    test_correctness()
