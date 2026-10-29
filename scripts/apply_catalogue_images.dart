// Backward-compatible command name for syncing the canonical catalogue.
// New products are written as complete rows; existing rows merge only the
// picture/category fields that the catalogue sync owns.
import 'sync_catalogue.dart' as sync;

Future<void> main() => sync.main();
