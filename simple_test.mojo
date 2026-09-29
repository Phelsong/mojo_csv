from mojo_csv import CsvReader
from std.pathlib import Path


async def main() raises:
    var in_csv: Path = Path("tests/test.csv")
    try:
        var reader = CsvReader(in_csv)
    except:
        print("error building reader")
    print("Successfully created CsvReader")
    print("Length: ", len(reader))
    print("First element: ", reader[0])
