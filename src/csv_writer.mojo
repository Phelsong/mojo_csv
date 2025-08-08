from collections import List
from pathlib import Path
from sys import num_logical_cores
from testing import assert_true
from algorithm import parallelize


@fieldwise_init
struct CsvWriter(Copyable, Representable, Stringable, Writable):
    var elements: List[String]
    var delimiter: String
    var delimiter_byte: Int
    var QM: String
    var quote_byte: Int
    var newline_byte: Int
    var num_threads: Int
    var length: Int

    fn __init__(
        out self,
        frame: List[String],
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        self.elements = frame
        self.delimiter = delimiter
        self.QM = quotation_mark
        self.delimiter_byte = ord(self.delimiter)
        self.quote_byte = ord(self.QM)
        self.newline_byte = ord("\n")
        self.length = len(frame)

        if num_threads == 0:
            var cores = num_logical_cores()
            if cores > 2:
                self.num_threads = cores - 2
            else:
                self.num_threads = 1
        else:
            self.num_threads = max(1, num_threads)

    # Encode a single cell with CSV rules:
    # - If already quoted (starts/ends with quotation_mark), assume it's pre-encoded and return as-is
    # - Otherwise, double embedded quotation marks and quote if it contains delimiter, quote, or newline
    fn _encode_cell(self, cell: String) -> String:
        var n = len(cell)
        if n >= 2 and cell[0] == self.QM and cell[n - 1] == self.QM:
            # Treat as already CSV-encoded
            return cell

        var needs_quotes = False
        var out = String("")

        for i in range(n):
            var ch = cell[i]
            if ch == self.QM:
                # Escape quotes by doubling
                out += self.QM
                out += self.QM
                needs_quotes = True
            else:
                if ch == self.delimiter or ch == "\n" or ch == "\r":
                    needs_quotes = True
                out += ch
        if needs_quotes:
            return self.QM + out + self.QM
        else:
            return out

    # Write the flat element list to CSV file, given the number of columns per row.
    # The first row is elements[0:col_count], the second row is elements[col_count:2*col_count], etc.
    fn write(
        self, out_csv: Path, col_count: Int, include_trailing_newline: Bool = False
    ) raises:
        assert_true(col_count > 0, "col_count must be > 0")
        assert_true(
            (self.length % col_count) == 0,
            "elements length must be divisible by col_count",
        )
        var row_count: Int = 0
        if col_count > 0:
            row_count = self.length // col_count

        # Handle empty frame: create or truncate file to empty
        if row_count == 0:
            out_csv.write_text("")
            return

        # For small outputs or single thread, do it inline
        if row_count < 1000 or self.num_threads == 1:
            var output = String("")
            var idx = 0
            for r in range(row_count):
                for c in range(col_count):
                    if c > 0:
                        output += self.delimiter
                    output += self._encode_cell(self.elements[idx])
                    idx += 1
                if r < row_count - 1 or include_trailing_newline:
                    output += "\n"
            out_csv.write_text(output)
            return

        # Threaded: build each row independently, then join
        var rows = List[String]()
        for _ in range(row_count):
            rows.append(String(""))

        @parameter
        fn process_row(row_idx: Int) -> None:
            var start = row_idx * col_count
            var end = start + col_count
            var row = String("")
            for i in range(start, end):
                var c = i - start
                if c > 0:
                    row += self.delimiter
                row += self._encode_cell(self.elements[i])
            rows[row_idx] = row

        parallelize[process_row](row_count, self.num_threads)

        var output = String("")
        for r in range(row_count):
            output += rows[r]
            if r < row_count - 1 or include_trailing_newline:
                output += "\n"
        out_csv.write_text(output)

    fn __repr__(self) -> String:
        return String("CsvWriter(len=" + String(self.length) + ")")

    fn __str__(self) -> String:
        return String.write(self)

    fn __len__(self) -> Int:
        return self.length

    fn write_to[W: Writer](self, mut writer: W) -> None:
        writer.write(String("CsvWriter(" + String(self.length) + ")"))
