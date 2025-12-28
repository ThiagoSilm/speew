import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../utils/logger_service.dart';

class PacketCompressor {
  /// Comprime um JSON string para Uint8List usando GZip
  /// Reduz o tamanho em até 60-80% para payloads repetitivos (como blocos de Ledger)
  static Uint8List compress(Map<String, dynamic> json) {
    try {
      final stringData = jsonEncode(json);
      final bytes = utf8.encode(stringData);
      
      // Só comprime se valer a pena (> 128 bytes)
      if (bytes.length < 128) {
        final result = Uint8List(bytes.length + 1);
        result[0] = 0; // Flag: Não comprimido
        result.setRange(1, result.length, bytes);
        return result;
      }

      final compressed = GZipEncoder().encode(bytes);
      if (compressed == null) throw Exception('Falha na compressão GZip');

      final result = Uint8List(compressed.length + 1);
      result[0] = 1; // Flag: Comprimido
      result.setRange(1, result.length, compressed);
      
      final ratio = (1 - (result.length / bytes.length)) * 100;
      logger.debug('Pacote comprimido: ${bytes.length}b -> ${result.length}b (${ratio.toStringAsFixed(1)}% redução)', tag: 'Compressor');
      
      return result;
    } catch (e) {
      logger.error('Erro ao comprimir pacote', tag: 'Compressor', error: e);
      return Uint8List(0);
    }
  }

  /// Descomprime um Uint8List para Map
  static Map<String, dynamic>? decompress(Uint8List data) {
    if (data.isEmpty) return null;

    try {
      final isCompressed = data[0] == 1;
      final payload = data.sublist(1);

      List<int> decompressed;
      if (isCompressed) {
        decompressed = GZipDecoder().decodeBytes(payload);
      } else {
        decompressed = payload;
      }

      final stringData = utf8.decode(decompressed);
      return jsonDecode(stringData) as Map<String, dynamic>;
    } catch (e) {
      logger.error('Erro ao descomprimir pacote', tag: 'Compressor', error: e);
      return null;
    }
  }
}
