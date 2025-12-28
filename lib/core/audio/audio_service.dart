import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../utils/logger_service.dart';

/// Serviço para gravação e streaming de áudio em tempo real.
/// Simula a funcionalidade de um plugin de áudio (ex: record_mp3, flutter_sound).
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool _isRecording = false;
  Timer? _recordingTimer;
  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  bool get isRecording => _isRecording;

  /// Inicia a gravação e o streaming de áudio.
  Future<void> startRecording() async {
    if (_isRecording) return;

    _isRecording = true;
    logger.info('Iniciando gravação de áudio...', tag: 'AudioService');

    // Simulação de streaming de áudio a cada 50ms (baixa latência)
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Simula a captura de um pequeno chunk de áudio (ex: 1024 bytes)
      final chunk = _generateMockAudioChunk(1024);
      _audioStreamController.add(chunk);
      
      if (kDebugMode) {
        // print('AudioService: Chunk de áudio enviado (${chunk.length} bytes)');
      }
    });
  }

  /// Para a gravação e o streaming de áudio.
  void stopRecording() {
    if (!_isRecording) return;

    _isRecording = false;
    _recordingTimer?.cancel();
    logger.info('Gravação de áudio parada.', tag: 'AudioService');
  }

  /// Gera um chunk de áudio simulado.
  Uint8List _generateMockAudioChunk(int size) {
    final buffer = Uint8List(size);
    for (int i = 0; i < size; i++) {
      // Simula dados de áudio aleatórios
      buffer[i] = (i % 256).toUnsigned(8);
    }
    return buffer;
  }

  /// Simula a reprodução de um chunk de áudio.
  /// Em produção, este método enviaria o chunk para o buffer de reprodução do plugin nativo.
  void playChunk(Uint8List chunk) {
    // Simulação de reprodução: Apenas registra o chunk no buffer de reprodução simulado.
    // O player real será implementado no ChatScreen.
    logger.debug('Chunk de áudio recebido e pronto para reprodução (${chunk.length} bytes)', tag: 'AudioService');
  }
  
  // ==================== REPRODUÇÃO DE MENSAGENS DE VOZ ====================
  
  // ==================== REPRODUÇÃO DE MENSAGENS DE VOZ (Simulação just_audio) ====================

  // Simulação de Player de Áudio (AudioPlayer do just_audio)
  // Em produção, seria a instância real do AudioPlayer
  bool _isAudioPlaying = false;
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = const Duration(seconds: 2); // Duração padrão simulada

  /// Stream de estado de reprodução (simulação)
  final StreamController<bool> _playingStateController = StreamController<bool>.broadcast();
  Stream<bool> get playingStateStream => _playingStateController.stream;

  /// Stream de posição de reprodução (simulação)
  final StreamController<Duration> _positionStreamController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionStreamController.stream;

  /// Simula a reprodução de uma mensagem de voz completa (arquivo).
  Future<void> playAudioMessage(String audioFilePath) async {
    logger.info('Iniciando reprodução (just_audio simulação): $audioFilePath', tag: 'AudioService');
    
    // Simulação: Carregar arquivo e obter duração
    _totalDuration = const Duration(seconds: 2); // Duração simulada
    _currentDuration = Duration.zero;
    _isAudioPlaying = true;
    _playingStateController.add(true);

    // Simula o avanço da reprodução
    _simulatePlaybackAdvance();
  }

  /// Simula o avanço da reprodução
  void _simulatePlaybackAdvance() async {
    while (_isAudioPlaying && _currentDuration < _totalDuration) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isAudioPlaying) return;

      _currentDuration += const Duration(milliseconds: 100);
      if (_currentDuration > _totalDuration) {
        _currentDuration = _totalDuration;
      }
      _positionStreamController.add(_currentDuration);
    }

    if (_currentDuration == _totalDuration) {
      stopAudioMessage();
    }
  }

  /// Simula a pausa da reprodução.
  void pauseAudioMessage() {
    logger.info('Reprodução pausada.', tag: 'AudioService');
    _isAudioPlaying = false;
    _playingStateController.add(false);
  }

  /// Simula a parada da reprodução.
  void stopAudioMessage() {
    logger.info('Reprodução parada.', tag: 'AudioService');
    _isAudioPlaying = false;
    _currentDuration = Duration.zero;
    _playingStateController.add(false);
    _positionStreamController.add(Duration.zero);
  }

  /// Simula a busca na reprodução.
  void seekAudioMessage(Duration position) {
    logger.info('Buscando posição: ${position.inSeconds}s', tag: 'AudioService');
    _currentDuration = position;
    _positionStreamController.add(_currentDuration);
    
    if (_isAudioPlaying) {
      _simulatePlaybackAdvance(); // Reinicia o avanço
    }
  }

  /// Obtém a duração total do áudio (simulação)
  Future<Duration> getAudioDuration(String audioFilePath) async {
    // Em produção, usaria o player.setFilePath(audioFilePath) e leria a duração
    return _totalDuration;
  }

  /// Obtém a posição atual (simulação)
  Duration get currentPosition => _currentDuration;

  /// Obtém a duração total (simulação)
  Duration get totalDuration => _totalDuration;

  /// Limpa recursos.
  void dispose() {
    _recordingTimer?.cancel();
    _audioStreamController.close();
    _playingStateController.close();
    _positionStreamController.close();
  }
}
