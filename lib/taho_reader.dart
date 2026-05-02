import 'dart:io';
import 'package:flutter/services.dart';

class TahoReader {
  static const MethodChannel _channel = MethodChannel('com.example.taho_reader/taho_reader');
  bool _initialized = false;

  Future<bool> init() async {
    final bool available = await _channel.invokeMethod<bool>('initReader') ?? false;
    _initialized = available;
    return available;
  }

  Future<bool> isConnected() async {
    return await _channel.invokeMethod<bool>('isConnected') ?? false;
  }

  Future<bool> isCardPresent() async {
    return await _channel.invokeMethod<bool>('isCardPresent') ?? false;
  }

  Future<Map<String, dynamic>> getReaderInfo() async {
    final result = await _channel.invokeMethod('getReaderInfo');
    if (result is Map) {
      return result.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  Future<Uint8List> selectFile(Uint8List apdu) async {
    return _invokeBytes('transmit', apdu);
  }

  Future<Uint8List> transmit(Uint8List apdu) async {
    return _invokeBytes('transmit', apdu);
  }

  Future<Uint8List> readData(int length) async {
    return _invokeBytes('readData', {'length': length});
  }

  Future<List<String>> getLogs() async {
    final result = await _channel.invokeMethod('getLogs');
    if (result is List) {
      return result.map((item) => item.toString()).toList();
    }
    return [];
  }

  Future<Uint8List?> getATR() async {
    final result = await _channel.invokeMethod('getATR');
    if (result is Uint8List) return result;
    if (result is List<int>) return Uint8List.fromList(result);
    return null;
  }

  Future<String> getATRHex() async {
    final atr = await getATR();
    if (atr == null || atr.isEmpty) return "No ATR received";
    return atr.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  Future<void> dispose() async {
    await _channel.invokeMethod<void>('close');
    _initialized = false;
  }

  Future<Uint8List> _invokeBytes(String method, dynamic arguments) async {
    final dynamic result = await _channel.invokeMethod<dynamic>(method, arguments);
    if (result is Uint8List) return result;
    if (result is List<int>) return Uint8List.fromList(result);
    if (result is List<dynamic>) {
      return Uint8List.fromList(result.cast<int>());
    }
    throw PlatformException(
      code: 'INVALID_RESPONSE',
      message: 'Expected native byte array from $method',
    );
  }
}

class TahoFileReader {
  late Uint8List buffer;

  TahoFileReader() {
    buffer = Uint8List(65563 * 2);
  }

  void readFile(String filePath) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final length = bytes.length.clamp(0, buffer.length);
    buffer.setRange(0, length, bytes);
  }

  Uint8List? findFile(int b1, int b2, int b3) {
    for (var i = 0; i < buffer.length - 5; i++) {
      if (buffer[i] == b1 && buffer[i + 1] == b2 && buffer[i + 2] == b3) {
        return buffer.sublist(i + 5);
      }
    }
    return null;
  }
}
