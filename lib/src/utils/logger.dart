import 'package:flutter/foundation.dart';

void logError(String message, [String? code]) {
  if (code != null) {
    debugPrint('Error [$code]: $message');
  } else {
    debugPrint('Error: $message');
  }
}
