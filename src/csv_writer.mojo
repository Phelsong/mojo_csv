from std.collections import List
from std.pathlib import Path
from std.sys import num_logical_cores
from std.testing import assert_true
from max.algorithm import parallelize


@fieldwise_init
struct CsvWriter(Copyable, Writable):
    var elements: List[String]
    var delimiter: String
    var delimiter_byte: UInt8
    var QM: String
    var quote_byte: UInt8
    var newline_byte: UInt8
    var carriage_return_byte: UInt8
    var num_threads: Int
    var length: Int

    def __init__(
        out self,
        frame: List[String],
        delimiter: String = ",",
        quotation_mark: String = '"',
        num_threads: Int = 0,
    ) raises:
        self.elements = frame.copy()
        self.delimiter = delimiter
        self.QM = quotation_mark
        self.delimiter_byte = UInt8(ord(self.delimiter))
        self.quote_byte = UInt8(ord(self.QM))
        self.newline_byte = UInt8(ord("\n"))
        self.carriage_return_byte = UInt8(ord("\r"))
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
    def _encode_cell(imm self, cell: String) -> String:
        var n = cell.byte_length()
        if n >= 2 and cell.startswith(self.QM) and cell.endswith(self.QM):
            # Treat as already CSV-encoded
            return cell

        # Fast path: scan bytes first; most cells contain no special characters
        # and can be returned as-is without building a new string
        var quote_byte = self.quote_byte
        var delimiter_byte = self.delimiter_byte
        var newline_byte = self.newline_byte
        var carriage_byte = self.carriage_return_byte
        var bytes_view = cell.as_bytes()
        var needs_quotes = False
        for i in range(n):
            var b = bytes_view[i]
            if (
                b == quote_byte
                or b == delimiter_byte
                or b == newline_byte
                or b == carriage_byte
            ):
                needs_quotes = True
                break

        if not needs_quotes:
            return cell

        var out = String()
        var reserve = n + 16
        out.reserve_bytes(reserve)

        for ch in cell.codepoints():
            if Int(ch) == Int(quote_byte):
                # Escape quotes by doubling
                out += self.QM
                out += self.QM
            else:
                out += String(ch)
        var encoded = self.QM + out + self.QM
        return encoded^

    # Write the flat element list to CSV file, given the number of columns per row.
    # The first row is elements[0:col_count], the second row is elements[col_count:2*col_count], etc.
    def write(
        self,
        out_csv: Path,
        col_count: Int,
        include_trailing_newline: Bool = False,
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

        # Threaded: each thread encodes a contiguous block of rows into its
        # own output chunk (rows + newlines included); chunks are then joined
        var threads = self.num_threads
        if threads > row_count:
            threads = row_count

        var chunks: List[String] = List[String]()
        chunks.reserve(threads)
        for _ in range(threads):
            chunks.append(String(""))

        # Row boundaries per chunk (chunk t handles rows [row_starts[t], row_starts[t+1]))
        var row_starts: List[Int] = List[Int]()
        row_starts.reserve(threads + 1)
        for t in range(threads + 1):
            row_starts.append(t * row_count // threads)
        row_starts[threads] = row_count

        def process_chunk(
            chunk_idx: Int,
        ) {mut chunks, imm self, imm row_starts, imm col_count} -> None:
            var first_row = row_starts[chunk_idx]
            var end_row = row_starts[chunk_idx + 1]
            var chunk = String()
            var chunk_rows = end_row - first_row
            chunk.reserve_bytes(chunk_rows * 96)
            for r in range(first_row, end_row):
                var start = r * col_count
                for c in range(col_count):
                    if c > 0:
                        chunk += self.delimiter
                    chunk += self._encode_cell(self.elements[start + c])
                chunk += "\n"
            chunks[chunk_idx] = chunk^

        parallelize(process_chunk, threads, threads)

        # Join chunk strings (trailing newline per chunk covers row separation;
        # respect include_trailing_newline by trimming the final newline)
        var output = String()
        var total_len: Int = row_count
        for chunk in chunks:
            total_len += chunk.byte_length()
        output.reserve_bytes(total_len)
        for chunk in chunks:
            output += chunk
        if not include_trailing_newline and output.byte_length() > 0:
            var trimmed = output[byte = 0 : output.byte_length() - 1]
            out_csv.write_text(String(trimmed))
            return
        out_csv.write_text(output)

    def __repr__(imm self) -> String:
        return String("CsvWriter(len=" + String(self.length) + ")")

    def __str__(imm self) -> String:
        return String(self)

    def __len__(imm self) -> Int:
        return self.length

    def write_to[W: Writer](imm self, mut writer: W) -> None:
        writer.write(String("CsvWriter(" + String(self.length) + ")"))
