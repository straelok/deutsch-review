import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> applicationDatabasePath() async {
  final directory = await getApplicationSupportDirectory();
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  return '${directory.path}${Platform.pathSeparator}deutsch_review.sqlite';
}
