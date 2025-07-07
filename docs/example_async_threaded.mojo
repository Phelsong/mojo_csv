#!/usr/bin/env mojo

from src.threaded_csv_reader import ThreadedCsvReader
from pathlib import Path


async fn async_example():
    """Example of using the async ThreadedCsvReader"""
    print("=== Async ThreadedCsvReader Example ===")
    
    try:
        # Use async factory method for better performance on large files
        var csv_path = Path("tests/datablist/people-100000.csv")
        print("Loading CSV file asynchronously...")
        
        var reader = await ThreadedCsvReader.create_async(
            csv_path,
            delimiter=",",
            num_threads=4  # Use 4 threads for processing
        )
        
        print("CSV loaded successfully!")
        print("Rows:", reader.row_count)
        print("Columns:", reader.col_count)
        print("Total elements:", len(reader))
        
        # Print headers
        print("Headers:")
        for i in range(reader.col_count):
            print("  ", reader.headers[i])
        
        # Print first few rows
        print("\\nFirst 3 rows:")
        for row in range(min(3, reader.row_count)):
            var row_data = ""
            for col in range(reader.col_count):
                var index = row * reader.col_count + col
                if index < len(reader):
                    row_data += reader[index] + " | "
            print("Row", row + 1, ":", row_data)
            
    except Exception as e:
        print("Error:", str(e))


fn sync_example():
    """Example of using the synchronous ThreadedCsvReader"""
    print("\\n=== Sync ThreadedCsvReader Example ===")
    
    try:
        var csv_path = Path("tests/datablist/people-100000.csv")
        print("Loading CSV file synchronously...")
        
        var reader = ThreadedCsvReader(
            csv_path,
            delimiter=",",
            num_threads=4  # Use 4 threads for processing
        )
        
        print("CSV loaded successfully!")
        print("Rows:", reader.row_count)
        print("Columns:", reader.col_count)
        print("Total elements:", len(reader))
        
    except Exception as e:
        print("Error:", str(e))


async fn main():
    """Main function demonstrating both sync and async usage"""
    print("ThreadedCsvReader Async vs Sync Comparison\\n")
    
    # Run async example
    await async_example()
    
    # Run sync example for comparison
    sync_example()
    
    print("\\n=== Comparison Complete ===")
    print("Async version provides better resource utilization")
    print("and improved performance for large CSV files.")


if __name__ == "__main__":
    main()
