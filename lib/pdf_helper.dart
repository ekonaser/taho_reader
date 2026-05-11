import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class SaveAndOpenDocument {
  static Future<File> savePdf({
    required String name,
    required pw.Document pdf,
  }) async {
    final root = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    
    // Ensure the directory exists
    if (root != null && !await root.exists()) {
      await root.create(recursive: true);
    }

    final file = File('${root!.path}/$name.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> openFile(File file) async {
    final path = file.path;
    await OpenFile.open(path);
  }
}
