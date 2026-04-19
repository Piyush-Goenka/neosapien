class ByteCountFormatter {
  const ByteCountFormatter._();

  static String format(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final units = <String>['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    final precision = value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}
