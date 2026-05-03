import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'taho_models.dart';

class TahoExporter {
  Future<void> saveToDdd({
    TahoGen1Card? gen1Card,
    TahoGen2Card? gen2Card,
    required String fileName,
  }) async {
    final builder = BytesBuilder();

    if (gen1Card != null) {
      _addSection(builder, 0x05, 0x20, 0x00, gen1Card.idData);
      _addSection(builder, 0x05, 0x0E, 0x00, gen1Card.cardDownload);
      _addSection(builder, 0x05, 0x05, 0x00, gen1Card.vehiclesDATAptr);
      _addSection(builder, 0x05, 0x04, 0x00, gen1Card.activitiesDATAptr);
      _addSection(builder, 0x05, 0x21, 0x00, gen1Card.driverLicenseDATAptr);
      _addSection(builder, 0x05, 0x01, 0x00, gen1Card.appIdentification);
      _addSection(builder, 0x05, 0x02, 0x00, gen1Card.eventsData);
      _addSection(builder, 0x05, 0x03, 0x00, gen1Card.faultsData);
      _addSection(builder, 0x05, 0x06, 0x00, gen1Card.places);
      _addSection(builder, 0x05, 0x07, 0x00, gen1Card.currentUsage);
      _addSection(builder, 0x05, 0x08, 0x00, gen1Card.controlActivityData);
      _addSection(builder, 0x05, 0x22, 0x00, gen1Card.specificConditions);
      _addSection(builder, 0xC1, 0x00, 0x00, gen1Card.cardCertDATAptr);
      _addSection(builder, 0xC1, 0x08, 0x00, gen1Card.CACertDATAptr);
    } else if (gen2Card != null) {
      _addSection(builder, 0x05, 0x20, 0x02, gen2Card.idData);
      _addSection(builder, 0x05, 0x24, 0x02, gen2Card.GNSS);
      _addSection(builder, 0x05, 0x04, 0x02, gen2Card.activitiesDATAptr);
      _addSection(builder, 0x05, 0x0E, 0x02, gen2Card.cardDownload);
      _addSection(builder, 0x05, 0x21, 0x02, gen2Card.driverLicenseDATAptr);
      _addSection(builder, 0x05, 0x01, 0x02, gen2Card.appIdentification);
      _addSection(builder, 0x05, 0x02, 0x02, gen2Card.eventsData);
      _addSection(builder, 0x05, 0x03, 0x02, gen2Card.faultsData);
      _addSection(builder, 0x05, 0x05, 0x02, gen2Card.vehicleUnitsUsed);
      _addSection(builder, 0x05, 0x06, 0x02, gen2Card.places);
      _addSection(builder, 0x05, 0x07, 0x02, gen2Card.currentUsage);
      _addSection(builder, 0x05, 0x08, 0x02, gen2Card.controlActivityData);
      _addSection(builder, 0x05, 0x22, 0x02, gen2Card.specificConditions);
      _addSection(builder, 0xC1, 0x00, 0x02, gen2Card.cardCertDATAptr);
      _addSection(builder, 0xC1, 0x01, 0x02, gen2Card.cardSignCertificate);
      _addSection(builder, 0xC1, 0x08, 0x02, gen2Card.CACertDATAptr);
      _addSection(builder, 0xC1, 0x09, 0x02, gen2Card.linkCertificate);
    }

    final bytes = builder.toBytes();
    if (bytes.isEmpty) return;

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Tacho Card Data',
      fileName: '$fileName.ddd',
      bytes: bytes,
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(bytes);
    }
  }

  void _addSection(BytesBuilder builder, int b1, int b2, int gen, Uint8List data) {
    if (data.isEmpty) return;
    
    final header = Uint8List(5);
    header[0] = b1;
    header[1] = b2;
    header[2] = gen;
    header[3] = (data.length >> 8) & 0xFF;
    header[4] = data.length & 0xFF;
    
    builder.add(header);
    builder.add(data);
  }
}
