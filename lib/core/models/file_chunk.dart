import 'dart:typed_data';

/// Modelo para representar um chunk de arquivo em trânsito P2P
class FileChunk {
  final String fileId;
  final int chunkIndex;
  final int totalChunks;
  final Uint8List data;
  final String checksum; // Para verificação de integridade

  FileChunk({
    required this.fileId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
    required this.checksum,
  });

  /// Converte o FileChunk para um Map (para serialização P2P)
  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
      'data': data, // Uint8List é serializável em JSON como lista de inteiros
      'checksum': checksum,
    };
  }

  /// Cria um FileChunk a partir de um Map
  factory FileChunk.fromMap(Map<String, dynamic> map) {
    return FileChunk(
      fileId: map['fileId'] as String,
      chunkIndex: map['chunkIndex'] as int,
      totalChunks: map['totalChunks'] as int,
      data: map['data'] as Uint8List,
      checksum: map['checksum'] as String,
    );
  }
}
