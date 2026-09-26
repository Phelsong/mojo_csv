from std.pathlib import Path
from std.memory import ArcPointer
from std.os import abort
from std.python import Python
from std.python import PythonObject
from std.python.bindings import PythonModuleBuilder

from mojo_csv import CsvReader, DictCsvReader, CsvWriter, CsvRowView


def _validated_path(path: PythonObject) raises -> Path:
    var p = Path(String(py=path))
    if not p.exists():
        raise Error("File not found: " + String(py=path))
    return p


def parse_file(path: PythonObject) raises -> PythonObject:
    """Parse a CSV file and return the flat element list."""
    var reader = CsvReader(_validated_path(path))
    var out = Python.list()
    for el in reader.elements:
        out.append(el)
    return out


def row_count(path: PythonObject) raises -> PythonObject:
    var reader = CsvReader(_validated_path(path))
    return PythonObject(reader.row_count)


def col_count(path: PythonObject) raises -> PythonObject:
    var reader = CsvReader(_validated_path(path))
    return PythonObject(reader.col_count)


def cell(
    path: PythonObject, row: PythonObject, col: PythonObject
) raises -> PythonObject:
    """2D cell access: reader[row, col]."""
    var reader = CsvReader(_validated_path(path))
    return PythonObject(reader[Int(py=row), Int(py=col)])


def headers(path: PythonObject) raises -> PythonObject:
    var reader = CsvReader(_validated_path(path))
    var out = Python.list()
    for h in reader.headers:
        out.append(h)
    return out


def dict_rows(path: PythonObject) raises -> PythonObject:
    """Read a CSV as a list of dicts keyed by header."""
    var dr = DictCsvReader(_validated_path(path))
    var out = Python.list()
    for row in dr:
        var d = Python.dict()
        for c in range(dr.col_count):
            d[PythonObject(dr.headers[c])] = PythonObject(row.get_at(c))
        out.append(d)
    return out


def write_csv(
    cells: PythonObject, col_count: PythonObject, out_path: PythonObject
) raises -> PythonObject:
    """Write a flat list of cells to CSV; returns the row count written."""
    var elements = List[String]()
    for cell_obj in cells:
        elements.append(String(py=cell_obj))
    var writer = CsvWriter(elements^)
    writer.write(Path(String(py=out_path)), Int(py=col_count))
    return PythonObject(len(elements) // Int(py=col_count))


struct BoundReader(Copyable, Movable, Writable):
    # Parses once at construction; row/cell access reuses the parsed grid
    var reader: CsvReader

    def __init__(out self, path: Path):
        self.reader = CsvReader(path)

    @staticmethod
    def py_init(out self: BoundReader, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) == 2:
            self = BoundReader(Path(String(py=args[0])), Int(py=args[1]))
        else:
            self = BoundReader(Path(String(py=args[0])))

    def __init__(out self, path: Path, num_threads: Int):
        self.reader = CsvReader(path, num_threads=num_threads)

    @staticmethod
    def rows(py_self: PythonObject) raises -> PythonObject:
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        return PythonObject(ptr[].reader.row_count)

    @staticmethod
    def cols(py_self: PythonObject) raises -> PythonObject:
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        return PythonObject(ptr[].reader.col_count)

    @staticmethod
    def cells(py_self: PythonObject) raises -> PythonObject:
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        return PythonObject(len(ptr[].reader.elements))

    @staticmethod
    def cell(
        py_self: PythonObject, row: PythonObject, col: PythonObject
    ) raises -> PythonObject:
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        return PythonObject(ptr[].reader[Int(py=row), Int(py=col)])

    @staticmethod
    def headers_list(py_self: PythonObject) raises -> PythonObject:
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        var out = Python.list()
        for h in ptr[].reader.headers:
            out.append(h)
        return out

    @staticmethod
    def get_row(py_self: PythonObject, row: PythonObject) raises -> PythonObject:
        """Return one row as a Python list of cells (mirrors csv.reader)."""
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        var r = Int(py=row)
        ref reader = ptr[].reader
        if r < 0 or r >= reader.row_count:
            raise Error("Row index out of range")
        var out = Python.list()
        var base = r * reader.col_count
        for c in range(reader.col_count):
            out.append(reader.elements[base + c])
        return out

    @staticmethod
    def all_cells(py_self: PythonObject) raises -> PythonObject:
        var ptr = py_self.downcast_value_ptr[BoundReader]()
        var out = Python.list()
        for el in ptr[].reader.elements:
            out.append(el)
        return out


@export
def PyInit_mojo_csv_bind() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("mojo_csv_bind")
        m.def_function[parse_file]("parse_csv")
        m.def_function[row_count]("row_count")
        m.def_function[col_count]("col_count")
        m.def_function[cell]("cell")
        m.def_function[headers]("headers")
        m.def_function[dict_rows]("dict_rows")
        m.def_function[write_csv]("write_csv")
        _ = (
            m.add_type[BoundReader]("Reader")
            .def_py_init[BoundReader.py_init]()
            .def_method[BoundReader.rows]("row_count")
            .def_method[BoundReader.cols]("col_count")
            .def_method[BoundReader.cells]("length")
            .def_method[BoundReader.cell]("cell")
            .def_method[BoundReader.get_row]("get_row")
            .def_method[BoundReader.headers_list]("headers")
            .def_method[BoundReader.all_cells]("all_cells")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))
