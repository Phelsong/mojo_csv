from mojo_csv import CsvReader
from pathlib import Path


fn main():
    var in_csv: Path = Path("tests/test.csv")
    var reader = CsvReader(in_csv)
    print("Successfully created CsvReader")
    print("Length: ", len(reader))
    print("First element: ", reader[0])
