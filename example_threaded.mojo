from pathlib import Path, cwd
from src.threaded_csv_reader import ThreadedCsvReader
from sys import num_physical_cores


fn main():
    """Example usage of ThreadedCsvReader"""
    print("=== Threaded CSV Reader Example ===")
    print("Available CPU cores:", num_physical_cores())
    print()
    
    try:
        # Example 1: Use all available cores (default)
        var csv_path = cwd().joinpath("tests/datablist/organizations-1000.csv")
        var reader = ThreadedCsvReader(csv_path)
        
        print("File:", csv_path)
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
        
        # Example 2: Specify number of threads
        print("=== Custom Thread Count ===")
        var reader_2threads = ThreadedCsvReader(csv_path, num_threads=2)
        print("Using 2 threads - Rows:", reader_2threads.row_count, "Elements:", len(reader_2threads))
        
        # Example 3: Force single-threaded (for comparison)
        var reader_single = ThreadedCsvReader(csv_path, num_threads=1)
        print("Single-threaded - Rows:", reader_single.row_count, "Elements:", len(reader_single))
        
    except Exception:
        print("Error reading CSV file")


# Performance tips and usage guidelines
fn usage_tips():
    """Print usage tips for ThreadedCsvReader"""
    print()
    print("=== ThreadedCsvReader Usage Tips ===")
    print()
    print("1. Multi-threading benefits:")
    print("   - Best for files > 10KB")
    print("   - Automatically falls back to single-threaded for small files")
    print("   - Speedup typically 1.1-1.5x on modern multi-core systems")
    print()
    print("2. Constructor options:")
    print("   ThreadedCsvReader(file_path, delimiter=',', quotation_mark='\"', num_threads=0)")
    print("   - num_threads=0: Use all available cores (default)")
    print("   - num_threads=1: Force single-threaded")
    print("   - num_threads=N: Use exactly N threads")
    print()
    print("3. Same interface as CsvReader:")
    print("   - reader[index] to access elements")
    print("   - reader.headers for column names")
    print("   - reader.row_count, reader.col_count for dimensions")
    print("   - Supports iteration: for element in reader")
    print()
    print("4. Thread safety:")
    print("   - Safe to read from multiple threads after construction")
    print("   - Do not modify the reader from multiple threads")
    print()
