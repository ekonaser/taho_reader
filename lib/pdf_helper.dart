import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

class SaveAndOpenDocument {
  // "Share" logic - Opens the native Android share sheet
  static Future<void> sharePdf({
    required String name,
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }

  // "Save As" logic - Opens a dialog for the user to choose location
  static Future<File?> savePdfWithPicker({
    required String name,
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Select where to save your PDF',
      fileName: '$name.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );

    if (outputFile == null) return null;

    final file = File(outputFile);
    // writeAsBytes overwrites if file exists, but we ensure clean write
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // "Silent Save" logic - Always overwrites 'last_preview.pdf' to keep cache clean
  static Future<File> savePdfToCache({
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/last_preview.pdf');
    
    // Overwrite the existing file
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> openFile(File file) async {
    final path = file.path;
    await OpenFile.open(path);
  }
}
