import 'package:uuid/uuid.dart';
import 'dart:math';

import 'package:rede_p2p_offline/models/file_block.dart';
import 'package:rede_p2p_offline/models/file_model.dart';
import 'package:rede_p2p_offline/services/network/p2p_service.dart';
import 'package:rede_p2p_offline/models/message.dart';

const int FILE_BLOCK_SIZE = 1024;

/// Cria um arquivo simulado com blocos
FileModel createSimulatedFile(String senderId, int blockCount) {
  final fileId = const Uuid().v4();
  final blocks = List.generate(blockCount, (index) {
    return FileBlock(
      blockId: const Uuid().v4(),
      fileId: fileId,
      index: index,
      data: List<int>.generate(FILE_BLOCK_SIZE, (i) => Random().nextInt(256)),
      checksum: 'mock_checksum_$index',
      signature: 'mock_signature_$index',
      senderId: senderId,
    );
  });

  return FileModel(
    fileId: fileId,
    fileName: 'simulated_file_$fileId.dat',
    senderId: senderId,
    totalBlocks: blockCount,
    blocks: blocks,
  );
}

/// Cria uma mensagem P2P para um bloco de arquivo
P2PMessage createFileBlockMessage(FileBlock block, String receiverId) {
  return P2PMessage(
    messageId: const Uuid().v4(),
    senderId: block.senderId,
    receiverId: receiverId,
    type: 'file_block',
    payload: block.toMap(),
  );
}

/// Cria uma mensagem P2P de texto
P2PMessage createTextMessage(String senderId, String receiverId, String content) {
  return P2PMessage(
    messageId: const Uuid().v4(),
    senderId: senderId,
    receiverId: receiverId,
    type: 'text',
    payload: {'content': content},
  );
}
