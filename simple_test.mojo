from mojo_csv import CsvReader
from std.pathlib import Path


async def main() raises:
    var in_csv: Path = Path("tests/test.csv")
    var reader = await CsvReader(in_csv)
    print("Successfully created CsvReader")
    print("Length: ", len(reader))
    print("First element: ", reader[0])
