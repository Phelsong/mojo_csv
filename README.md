# Mojo Csv

My reference implementation for csv tools in mojo

### usage

```mojo
from mojo_csv import CsvReader
from pathlib import Path

var csv_path = Path("path/to/csv/file.csv")
var reader = CsvReader(csv_path)
```
