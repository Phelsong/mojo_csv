from pathlib import Path, cwd
from sys import exit
from testing import assert_true
from time import time_function, perf_counter
from src.csv_reader import CsvReader
from src.threaded_csv_reader import ThreadedCsvReader


fn bench_single_threaded_medium() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/people-100000.csv")
        var _ = CsvReader(in_csv)
    except:
        print("error in single threaded medium")
        exit()


fn bench_multi_threaded_medium() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/datablist/people-100000.csv")
        var _ = ThreadedCsvReader(in_csv)
    except:
        print("error in multi threaded medium")
        exit()


fn bench_single_threaded_small() capturing:
    try:
        var in_csv: Path = cwd().joinpath(
            "tests/datablist/organizations-1000.csv"
        )
        var _ = CsvReader(in_csv)
    except:
        print("error in single threaded small")
        exit()


fn bench_multi_threaded_small() capturing:
    try:
        var in_csv: Path = cwd().joinpath(
            "tests/datablist/organizations-1000.csv"
        )
        var _ = ThreadedCsvReader(in_csv)
    except:
        print("error in multi threaded small")
        exit()


fn main():
    print("=== CSV Reader Performance Comparison ===")
    print()

    # Test small file (1k rows)
    print("Small file benchmark (1,000 rows):")
    print("Single-threaded:")
    var time_single_small: Float64 = 0
    for _ in range(100):
        var elapsed = time_function[bench_single_threaded_small]()
        time_single_small += elapsed / 1000000
    var avg_single_small = time_single_small / 100
    print("Average time:", round(avg_single_small, 6), "ms")

    print("Multi-threaded:")
    var time_multi_small: Float64 = 0
    for _ in range(100):
        var elapsed = time_function[bench_multi_threaded_small]()
        time_multi_small += elapsed / 1000000
    var avg_multi_small = time_multi_small / 100
    print("Average time:", round(avg_multi_small, 6), "ms")

    var speedup_small = avg_single_small / avg_multi_small
    print("Speedup:", round(speedup_small, 2), "x")
    print("-------------------------")

    # Test medium file (100k rows)
    print("Medium file benchmark (100,000 rows):")
    print("Single-threaded:")
    var time_single_medium: Float64 = 0
    for _ in range(100):
        var elapsed = time_function[bench_single_threaded_medium]()
        time_single_medium += elapsed / 1000000
    var avg_single_medium = time_single_medium / 100
    print("Average time:", round(avg_single_medium, 6), "ms")

    print("Multi-threaded:")
    var time_multi_medium: Float64 = 0
    for _ in range(100):
        var elapsed = time_function[bench_multi_threaded_medium]()
        time_multi_medium += elapsed / 1000000
    var avg_multi_medium = time_multi_medium / 100
    print("Average time:", round(avg_multi_medium, 6), "ms")

    var speedup_medium = avg_single_medium / avg_multi_medium
    print("Speedup:", round(speedup_medium, 2), "x")
    print("-------------------------")

    print("Summary:")
    print("Small file speedup:", round(speedup_small, 2), "x")
    print("Medium file speedup:", round(speedup_medium, 2), "x")
