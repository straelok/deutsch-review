import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/app_database_path.dart';
import 'data/repositories/sqlite_learning_item_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = AppDatabase.open(await applicationDatabasePath());
    runApp(
      DeutschReviewApp(
        repository: SqliteLearningItemRepository(database),
        onDispose: database.close,
      ),
    );
  } catch (error) {
    runApp(DatabaseErrorApp(message: error.toString()));
  }
}
