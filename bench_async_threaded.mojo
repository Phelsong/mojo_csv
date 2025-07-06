#!/usr/bin/env mojo

from src.threaded_csv_reader import ThreadedCsvReader
from pathlib import Path
from time import now


async fn benchmark_async(file_path: Path, iterations: Int = 3) -> Float64:
    """Benchmark async ThreadedCsvReader performance"""
    print(f"Benchmarking async ThreadedCsvReader ({iterations} iterations)...")
    
    var total_time: Float64 = 0.0
    
    for i in range(iterations):
        var start_time = now()
        
        var reader = await ThreadedCsvReader.create_async(
            file_path,
            num_threads=0  # Use all available cores
        )
        
        var end_time = now()
        var iteration_time = Float64(end_time - start_time) / 1_000_000.0  # Convert to milliseconds
        total_time += iteration_time
        
        print(f"  Iteration {i + 1}: {iteration_time:.2f}ms ({reader.row_count} rows, {reader.col_count} cols)")
    
    var avg_time = total_time / Float64(iterations)
    print(f"Async average: {avg_time:.2f}ms")
    return avg_time


fn benchmark_sync(file_path: Path, iterations: Int = 3) -> Float64:
    """Benchmark synchronous ThreadedCsvReader performance"""
    print(f"\\nBenchmarking sync ThreadedCsvReader ({iterations} iterations)...")
    
    var total_time: Float64 = 0.0
    
    for i in range(iterations):
        var start_time = now()
        
        try:
            var reader = ThreadedCsvReader(
                file_path,
                num_threads=0  # Use all available cores
            )
            
            var end_time = now()
            var iteration_time = Float64(end_time - start_time) / 1_000_000.0  # Convert to milliseconds
            total_time += iteration_time
            
            print(f"  Iteration {i + 1}: {iteration_time:.2f}ms ({reader.row_count} rows, {reader.col_count} cols)")
        except Exception as e:
            print(f"  Iteration {i + 1}: Error - {str(e)}")
    
    var avg_time = total_time / Float64(iterations)
    print(f"Sync average: {avg_time:.2f}ms")
    return avg_time


async fn run_benchmark(file_path: Path):
    """Run complete benchmark comparing async vs sync"""
    print(f"=== ThreadedCsvReader Performance Benchmark ===")
    print(f"File: {file_path}")
    
    if not file_path.exists():
        print(f"Error: File {file_path} does not exist!")
        return
    
    # Benchmark async version
    var async_time = await benchmark_async(file_path)
    
    # Benchmark sync version  
    var sync_time = benchmark_sync(file_path)
    
    # Calculate performance comparison
    print(f"\\n=== Results ===")
    print(f"Async time: {async_time:.2f}ms")
    print(f"Sync time:  {sync_time:.2f}ms")
    
    if async_time < sync_time:
        var speedup = sync_time / async_time
        print(f"Async is {speedup:.2f}x faster")
    else:
        var slowdown = async_time / sync_time
        print(f"Sync is {slowdown:.2f}x faster")


async fn main():
    """Main benchmark function"""
    # Test with different file sizes
    var test_files = [
        "tests/datablist/organizations-1000.csv",
        "tests/datablist/people-100000.csv"
    ]
    
    for file_name in test_files:
        var file_path = Path(file_name)
        await run_benchmark(file_path)
        print("\\n" + "="*50 + "\\n")


if __name__ == "__main__":
    main()
