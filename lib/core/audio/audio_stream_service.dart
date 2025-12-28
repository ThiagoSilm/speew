import 'dart:async';
import 'dart:typed_data';
import '../p2p/p2p_service.dart';
import '../utils/logger_service.dart';
import 'audio_service.dart';

/// Serviço que gerencia o streaming de áudio em tempo real através da rede P2P.
class AudioStreamService {
  final AudioService _audioService = AudioService();
  final P2PService _p2pService = P2PService();
  StreamSubscription<Uint8List>? _audioSubscription;
  String? _currentDestinationId;

  /// Inicia o streaming de áudio para um peer específico.
  void startStreaming(String destinationId) {
    if (_audioService.isRecording) {
      logger.warn('Gravação já está ativa. Parando antes de iniciar novo stream.', tag: 'AudioStream');
      stopStreaming();
    }

    _currentDestinationId = destinationId;
    _audioService.startRecording();

    // Assina o stream de áudio e envia cada chunk pela rede P2P
    _audioSubscription = _audioService.audioStream.listen((chunk) {
      _sendAudioChunk(destinationId, chunk);
    });

    logger.info('Streaming de áudio iniciado para $destinationId', tag: 'AudioStream');
  }

  /// Para o streaming de áudio.
  void stopStreaming() {
    _audioService.stopRecording();
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _currentDestinationId = null;
    logger.info('Streaming de áudio parado.', tag: 'AudioStream');
  }

  /// Envia um chunk de áudio pela rede P2P.
  void _sendAudioChunk(String destinationId, Uint8List chunk) {
    // Converte o chunk de áudio para uma string Base64 para ser enviado no payload
    final base64Chunk = chunk.toString(); // Simplificação: em produção, usar Base64 ou array de bytes
    
    final message = P2PMessage(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'local_user_id', // Deve ser substituído pelo ID real do usuário
      receiverId: destinationId,
      type: 'audio_chunk',
      payload: {'chunk': base64Chunk},
    );

    // Usa o método de envio do P2PService
    _p2pService.sendMessage(destinationId, message).catchError((e) {
      logger.error('Falha ao enviar chunk de áudio para $destinationId: $e', tag: 'AudioStream');
      // Lógica de reconexão ou retransmissão pode ser adicionada aqui
    });
  }

  /// Processa um chunk de áudio recebido.
  void handleReceivedAudioChunk(P2PMessage message) {
    if (message.type != 'audio_chunk') return;

    final base64Chunk = message.payload['chunk'] as String;
    // final chunk = base64.decode(base64Chunk); // Em produção, decodificar Base64
    
    // Implementação V1.2: Adicionar lógica de reprodução de áudio (MVP)
    // Em produção, a decodificação e reprodução seriam feitas aqui.
    // final chunk = base64.decode(base64Chunk); // Exemplo de decodificação
    // _audioService.playChunk(chunk); // Exemplo de reprodução
    
    logger.debug('Chunk de áudio recebido de ${message.senderId}. Tamanho: ${base64Chunk.length} (Simulado). Pronto para reprodução.', tag: 'AudioStream');
  }

  /// Limpa recursos.
  void dispose() {
    stopStreaming();
  }
}
