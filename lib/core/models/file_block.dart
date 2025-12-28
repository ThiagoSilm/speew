/// Modelo de dados para blocos de arquivo fragmentado
/// Cada arquivo é dividido em blocos de 32-128 KB para transmissão P2P
class FileBlock {
  /// Identificador único do bloco
  final String blockId;
  
  /// ID do arquivo ao qual este bloco pertence
  final String fileId;
  
  /// Índice do bloco na sequência (0-based)
  final int blockIndex;
  
  /// Número total de blocos do arquivo
  final int totalBlocks;
  
  /// Dados do bloco criptografados com XChaCha20-Poly1305
  /// Cada bloco possui sua própria chave e nonce
  final String dataEncrypted;
  
  /// Checksum SHA-256 do bloco para verificação de integridade
  final String checksum;

  FileBlock({
    required this.blockId,
    required this.fileId,
    required this.blockIndex,
    required this.totalBlocks,
    required this.dataEncrypted,
    required this.checksum,
  });

  /// Converte o objeto FileBlock para Map
  Map<String, dynamic> toMap() {
    return {
      'block_id': blockId,
      'file_id': fileId,
      'block_index': blockIndex,
      'total_blocks': totalBlocks,
      'data_encrypted': dataEncrypted,
      'checksum': checksum,
    };
  }

  /// Cria um objeto FileBlock a partir de um Map
  factory FileBlock.fromMap(Map<String, dynamic> map) {
    return FileBlock(
      blockId: map['block_id'] as String,
      fileId: map['file_id'] as String,
      blockIndex: map['block_index'] as int,
      totalBlocks: map['total_blocks'] as int,
      dataEncrypted: map['data_encrypted'] as String,
      checksum: map['checksum'] as String,
    );
  }

  /// Cria uma cópia do bloco com campos atualizados
  FileBlock copyWith({
    String? blockId,
    String? fileId,
    int? blockIndex,
    int? totalBlocks,
    String? dataEncrypted,
    String? checksum,
  }) {
    return FileBlock(
      blockId: blockId ?? this.blockId,
      fileId: fileId ?? this.fileId,
      blockIndex: blockIndex ?? this.blockIndex,
      totalBlocks: totalBlocks ?? this.totalBlocks,
      dataEncrypted: dataEncrypted ?? this.dataEncrypted,
      checksum: checksum ?? this.checksum,
    );
  }
}
