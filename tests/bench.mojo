from pathlib import Path, cwd
from sys import argv, exit
from testing import assert_true
from time import time_function, perf_counter
from utils import IndexList

from src.csv_reader import CsvReader


fn bench_parse() capturing:
    try:
        var in_csv: Path = cwd().joinpath("tests/test.csv")
        _ = CsvReader(in_csv)
    except:
        pass


fn main():
    var times: Float64 = 0
    # var start = perf_counter()
    for _ in range(10000):
        var elapsed = time_function[bench_parse]()
        times += elapsed / 1000000
    # var end = perf_counter()
    var avg = times / 10000
    print("average time in ms:")
    print(round(avg, 6))
