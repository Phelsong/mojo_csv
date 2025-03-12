# Mojo Csv

Csv parsing library written in pure Mojo

### usage

Add the Modular community channel (https://repo.prefix.dev/modular-community) to your mojoproject.toml file or pixi.toml file in the channels section.

##### Basic Usage

```mojo
from mojo_csv import CsvReader
from pathlib import Path

fn main():
    var csv_path = Path("path/to/csv/file.csv")
    var reader = CsvReader(csv_path)
    for i in range(len(reader.elements)):
        print(reader.elements[i])
```

##### Optional Usage

```mojo
from mojo_csv import CsvReader
from pathlib import Path

fn main():
    var csv_path = Path("path/to/csv/file.csv")
    var reader = CsvReader(csv_path, delimiter="|", quotation_mark='*')
    for i in range(len(reader.elements)):
        print(reader.elements[i])
```

### Attributes

```mojo
reader.raw
reader.headers
reader.row_count
reader.column_count
reader.length
```
