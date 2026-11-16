import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a report photo from its stored path. On phones that is a file in
/// the app's folder; in the browser preview it is a blob URL.
Widget photoImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  String? semanticLabel,
  required ImageErrorWidgetBuilder errorBuilder,
}) =>
    kIsWeb
        ? Image.network(path, fit: fit, semanticLabel: semanticLabel, errorBuilder: errorBuilder)
        : Image.file(File(path), fit: fit, semanticLabel: semanticLabel, errorBuilder: errorBuilder);
