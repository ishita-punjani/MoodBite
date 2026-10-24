/// Small helpers for reading Supabase JSON rows, where numbers may arrive
/// as int or double.
double readDouble(Object? value) => (value as num).toDouble();

int readInt(Object? value) => (value as num).toInt();

int? readIntOrNull(Object? value) => value == null ? null : readInt(value);

List<String> readStringList(Object? value) =>
    value == null ? const [] : List<String>.from(value as List);
