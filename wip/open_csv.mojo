from pathlib import Path
from testing import assert_true
from src.csv_reader import CsvReader


fn open_csv(in_csv: Path, delimiter: String = ",", quotation_mark: String = '"') -> CsvReader :
    try:
        assert_true(in_csv.exists())
        var fi_name:String = in_csv.split()[1]
        assert_true(fi_name.endswith(".csv", -4, -1))
        with open(file, "r") as fi:
            var reader = CsvReader(fi.read(), delimiter, quotation_mark)
            return reader
    except AssertionError:
        return None
