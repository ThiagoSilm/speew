// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// '../utils/logger_service.dart'
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// '../config/app_config.dart'
class AppConfig {
  static bool stealthMode = true; 
}

// '../p2p/p2p_service.dart'
class P2PService {
  void randomizeNextRoute() {
    logger.debug('P2PService: Rota randomizada (não-ótima) selecionada.', tag: 'P2P');
  }

  Future<void> sendData({
    required String peerId,
    required String data,
    Map<String, dynamic>? metadata,
  }) async {
    if (metadata?['stealth'] == true) {
      // Simulação de tráfego decoy
    } else {
      await Future.delayed(Duration(milliseconds: 10));
    }
    logger.debug('P2PService: Dados enviados para $peerId.', tag: 'P2P');
  }
}

// ==================== TrafficObfuscator ====================

/// Serviço para o Modo Ultra Stealth.
/// Aplica técnicas de ofuscação e randomização para dificultar o rastreamento.
class TrafficObfuscator {
  final P2PService _p2pService;
  bool _extremeObfuscation = false; 
  Timer? _fakeKeepAliveTimer;

  void setExtremeObfuscation(bool enabled) {
    _extremeObfuscation = enabled;
    logger.info('Modo de Ofuscação Extrema ${enabled ? 'ativado' : 'desativado'}.', tag: 'Obfuscator');
    // Reinicia o timer para aplicar as novas configurações de Jitter/Decoy
    sendFakeKeepAlives();
  }

  final Random _random = Random();

  TrafficObfuscator(this._p2pService) {
    // Inicia o tráfego decoy se o modo estiver ativo ao inicializar
    if (AppConfig.stealthMode) {
      sendFakeKeepAlives();
    }
  }

  /// Processa o pacote de dados para o modo stealth (Ofuscação V2).
  String processObfuscatedPacket(String originalData) {
    final bool isActive = AppConfig.stealthMode || _extremeObfuscation;
    if (!isActive) {
      return originalData;
    }

    // 1. Packet Padding (Preenchimento) para tamanhos discretos
    final currentSize = originalData.length;
    
    const int smallSize = 512;
    const int mediumSize = 1024;
    const int largeSize = 1500;
    final List<int> discreteSizes = [smallSize, mediumSize, largeSize];
    
    int targetSize = discreteSizes.firstWhere(
      (size) => size >= currentSize,
      orElse: () => largeSize,
    );

    // Se o modo extremo estiver ativo, força o padding máximo (Anti-Análise de Volume)
    if (_extremeObfuscation) {
      targetSize = largeSize;
    }
    
    if (currentSize < targetSize) {
      final paddingSize = targetSize - currentSize;
      // Padding com bytes aleatórios (melhor do que padding fixo)
      final padding = List.generate(paddingSize, (_) => String.fromCharCode(_random.nextInt(256))).join();
      originalData += padding;
      logger.debug('Pacote padronizado com padding de $paddingSize bytes (Tamanho Final: $targetSize).', tag: 'Obfuscator');
    }

    // 2. Ofuscação leve no header (simulação)
    final obfuscatedHeader = 'STLTHV2${_random.nextInt(999)}';
    final obfuscatedData = '$obfuscatedHeader:$originalData';
    
    // 3. Randomização de rota (simulação de seleção de rota não-ótima)
    _p2pService.randomizeNextRoute();

    return obfuscatedData;
  }

  /// Aplica um jitter (tempo de envio aleatório) antes de enviar.
  Future<void> applyJitter() async {
    final bool isActive = AppConfig.stealthMode || _extremeObfuscation;
    if (!isActive) {
      return;
    }
    
    int maxJitter = 50;
    int minJitter = 5;

    // Jitter Alto em modo extremo (Anti-Análise de Tempo)
    if (_extremeObfuscation) {
      maxJitter = 250;
      minJitter = 50;
    }

    final jitterMs = _random.nextInt(maxJitter - minJitter) + minJitter;
    logger.debug('Aplicando jitter de $jitterMs ms (Faixa: $minJitter-$maxJitter).', tag: 'Obfuscator');
    await Future.delayed(Duration(milliseconds: jitterMs));
  }

  /// Envia keep-alives falsos em intervalos aleatórios.
  void sendFakeKeepAlives() {
    final bool isActive = AppConfig.stealthMode || _extremeObfuscation;
    
    _fakeKeepAliveTimer?.cancel(); 

    if (!isActive) {
      return;
    }
    
    // Simulação: Envia keep-alives falsos a cada 5-15 segundos
    _fakeKeepAliveTimer = Timer.periodic(Duration(seconds: _random.nextInt(10) + 5), (timer) {
      final bool currentActive = AppConfig.stealthMode || _extremeObfuscation;
      if (!currentActive) {
        timer.cancel();
        return;
      }
      final fakePeerId = 'FAKE_PEER_${_random.nextInt(9999)}';
      _p2pService.sendData(
        peerId: fakePeerId,
        data: 'FAKE_KEEPALIVE',
        metadata: {'stealth': true},
      );
      logger.debug('Enviando keep-alive falso para $fakePeerId (Decoy traffic)', tag: 'Obfuscator');
    });
  }

  void dispose() {
    _fakeKeepAliveTimer?.cancel();
  }
}
