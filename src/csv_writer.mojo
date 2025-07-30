from collections import List
from pathlib import Path
from sys import exit, num_logical_cores
from testing import assert_true
from algorithm import parallelize


struct CsvWriter:
    fn __init__(
        out self,
        frame: List[String],
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        pass
