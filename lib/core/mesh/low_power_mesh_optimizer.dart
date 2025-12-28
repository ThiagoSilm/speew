// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
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
  static int maxMultiPaths = 3; 
  static int minSizeForCompression = 512; 
  static Duration marketplaceBroadcastInterval = Duration(seconds: 30); 
  static Duration keepAliveInterval = Duration(seconds: 10); 
}

// 'multipath_engine.dart'
class MultiPathEngine {
  void setPathCount(int count) {
    logger.debug('MultiPathEngine: Configurando contagem de caminhos para $count', tag: 'MultiPath');
  }
}

// 'priority_queue_mesh_dispatcher.dart'
enum MeshPriority {
  high,
  normal,
  low
}

class PriorityQueueMeshDispatcher {
  final Set<MeshPriority> _pausedPriorities = {};

  void pausePriority(MeshPriority priority) {
    _pausedPriorities.add(priority);
    logger.warn('Dispatcher: Prioridade $priority PAUSADA.', tag: 'Dispatcher');
  }

  void resumePriority(MeshPriority priority) {
    _pausedPriorities.remove(priority);
    logger.info('Dispatcher: Prioridade $priority RETOMADA.', tag: 'Dispatcher');
  }
}

// ==================== LowPowerMeshOptimizer ====================

/// Otimizador de Mesh para Modo Low-Power.
/// Ajusta as configurações da Mesh quando a bateria está baixa.
class LowPowerMeshOptimizer {
  final MultiPathEngine _multiPathEngine;
  final PriorityQueueMeshDispatcher _dispatcher;

  LowPowerMeshOptimizer(this._multiPathEngine, this._dispatcher);

  /// Aplica otimizações de baixo consumo.
  void applyLowPowerMode() {
    logger.warn('Modo Low-Power ativado (Bateria < 20%). Otimizações aplicadas.', tag: 'LowPower');
    
    
    // 1. Reduzir multi-path para 1 para evitar overhead de roteamento
    AppConfig.maxMultiPaths = 1;
    _multiPathEngine.setPathCount(1);
    logger.debug('Multi-Path reduzido para ${AppConfig.maxMultiPaths}.', tag: 'LowPower');

    // 2. Reduzir prioridade de arquivos (MeshPriority.low)
    _dispatcher.pausePriority(MeshPriority.low);
    logger.debug('Prioridade de arquivos (MeshPriority.low) pausada.', tag: 'LowPower');

    // 3. Compressão mais agressiva: Comprime pacotes menores para economizar largura de banda
    AppConfig.minSizeForCompression = 256; 
    logger.debug('Compressão mínima reduzida para ${AppConfig.minSizeForCompression} bytes.', tag: 'LowPower');

    // 4. Pausar marketplace broadcast: Reduz a frequência de sinalização de descoberta
    AppConfig.marketplaceBroadcastInterval = Duration(minutes: 5);
    logger.debug('Broadcast do Marketplace reduzido para ${AppConfig.marketplaceBroadcastInterval.inMinutes} minutos.', tag: 'LowPower');

    // 5. Reduzir keep-alives: Aumenta o tempo de espera entre pings de conexão
    AppConfig.keepAliveInterval = Duration(minutes: 1);
    logger.debug('Intervalo de Keep-Alive aumentado para ${AppConfig.keepAliveInterval.inMinutes} minuto.', tag: 'LowPower');
  }

  /// Restaura as configurações normais.
  void restoreNormalMode() {
    logger.info('Modo Low-Power desativado. Configurações restauradas.', tag: 'LowPower');
    
    AppConfig.maxMultiPaths = 3;
    _multiPathEngine.setPathCount(3);

    AppConfig.minSizeForCompression = 512;
    
    AppConfig.marketplaceBroadcastInterval = Duration(seconds: 30);
    
    AppConfig.keepAliveInterval = Duration(seconds: 10);
    
    _dispatcher.resumePriority(MeshPriority.low);
  }
}
