from pathlib import Path, cwd
from sys import num_logical_cores

from mojo_csv import CsvReader


fn main():
    """Example usage of ThreadedCsvReader."""
    print("=== Threaded CSV Reader Example ===")
    print("Available CPU cores:", num_logical_cores())
    print()

    try:
        var csv_path = cwd().joinpath("tests/datablist/leads-100.csv")
        var reader = CsvReader(csv_path)

        # print("File:", csv_path)
        print("Rows:", reader.row_count)
        print("Columns:", reader.col_count)
        print("Total elements:", len(reader))
        print("Threads used:", reader.num_threads)
        print()

        # Print first few rows
        print("Headers:")
        for i in range(reader.col_count):
            print(" ", reader.headers[i])
        print()

        print("First 3 data rows:")
        for row in range(1, min(4, reader.row_count)):
            print("Row", row, ":")
            for col in range(reader.col_count):
                var element_idx = row * reader.col_count + col
                if element_idx < len(reader):
                    print("  ", reader.headers[col], ":", reader[element_idx])
            print()

        usage_tips()

    except Exception:
        print("Error reading CSV file")


# Performance tips and usage guidelines
fn usage_tips():
    """Print usage tips for CsvReader."""
    print()
    print("=== CsvReader Usage Tips ===")
    print()
    print("1. Constructor options:")
    print("   CsvReader(file_path, delimiter=',', quotation_mark='\"', num_threads=0)")
    print("   - num_threads=0: Use all available cores (default)")
    print("   - num_threads=1: Force single-threaded")
    print("   - num_threads=N: Use exactly N threads")
    print()
    print("2. Multi-threading benefits:")
    print("   - Best for files > 10KB")
    print("   - Automatically falls back to single-threaded for small files")
    print("   - Speedup typically 1.1-1.5x on modern multi-core systems")
    print()
