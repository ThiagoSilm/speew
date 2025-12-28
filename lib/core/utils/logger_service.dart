import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger_service.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

/// Níveis de log disponíveis
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// Serviço centralizado de logging
/// 
/// Substitui todos os print() por chamadas estruturadas com níveis de log
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  /// Lista de logs armazenados em memória (para debug)
  final List<LogEntry> _logs = [];

  /// Máximo de logs em memória
  static const int _maxLogsInMemory = 1000;

  /// Log de debug (apenas em desenvolvimento)
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableDebugLogs && AppConfig.isDevelopment) {
      _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de informação
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableInfoLogs) {
      _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de aviso
  void warn(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableWarningLogs) {
      _log(LogLevel.warn, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de erro
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (AppConfig.enableErrorLogs) {
      _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Método interno de log
  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now();
    final entry = LogEntry(
      level: level,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      timestamp: timestamp,
    );

    // Adiciona à lista em memória
    _logs.add(entry);
    if (_logs.length > _maxLogsInMemory) {
      _logs.removeAt(0);
    }

    // Imprime no console
    final prefix = _getLevelPrefix(level);
    final tagStr = tag != null ? '[$tag] ' : '';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';

    if (kDebugMode) {
      logger.debug('$timeStr $prefix $tagStr$message');
      if (error != null) {
        logger.debug('  Error: $error');
      }
      if (stackTrace != null) {
        logger.debug('  StackTrace: $stackTrace');
      }
    }
  }

  /// Retorna o prefixo visual do nível de log
  String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍 [DEBUG]';
      case LogLevel.info:
        return 'ℹ️  [INFO]';
      case LogLevel.warn:
        return '⚠️  [WARN]';
      case LogLevel.error:
        return '❌ [ERROR]';
    }
  }

  /// Retorna todos os logs em memória
  List<LogEntry> getLogs({LogLevel? level}) {
    if (level == null) {
      return List.unmodifiable(_logs);
    }
    return _logs.where((log) => log.level == level).toList();
  }

  /// Limpa todos os logs em memória
  void clearLogs() {
    _logs.clear();
  }

  /// Exporta logs como string
  String exportLogs() {
    final buffer = StringBuffer();
    for (final log in _logs) {
      buffer.writeln(log.toString());
    }
    return buffer.toString();
  }

  /// Log crítico persistido em arquivo (caixa-preta)
  Future<void> logCritical(String error, StackTrace stack) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/blackbox_log.txt');
      final timestamp = DateTime.now().toIso8601String();

      await file.writeAsString(
        '[$timestamp] ERROR: $error\nSTACK: $stack\n---\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // swallow to avoid cascading failures
    }
  }

  /// Retorna o arquivo da caixa-preta para exportação
  Future<File> exportBlackBox() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/blackbox_log.txt');
  }

  /// Limpa logs antigos para evitar consumo excessivo de armazenamento
  /// Mantém apenas os últimos 5MB de logs da Black Box
  Future<void> cleanupBlackBox() async {
    try {
      final file = await exportBlackBox();
      if (await file.exists()) {
        final size = await file.length();
        const maxSizeBytes = 5 * 1024 * 1024; // 5MB

        if (size > maxSizeBytes) {
          logger.info('Limpando Black Box (Tamanho atual: ${size ~/ 1024}KB)', tag: 'Logger');
          final content = await file.readAsLines();
          // Mantém apenas a metade final das linhas
          final half = content.length ~/ 2;
          await file.writeAsString(content.sublist(half).join('\n'));
        }
      }
    } catch (e) {
      logger.error('Erro ao limpar Black Box', tag: 'Logger', error: e);
    }
  }
}

/// Entrada de log individual
class LogEntry {
  final LogLevel level;
  final String message;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });

  @override
  String toString() {
    final tagStr = tag != null ? '[$tag] ' : '';
    final errorStr = error != null ? '\n  Error: $error' : '';
    final stackStr = stackTrace != null ? '\n  Stack: $stackTrace' : '';
    return '${timestamp.toIso8601String()} [${level.name.toUpperCase()}] $tagStr$message$errorStr$stackStr';
  }
}

/// Instância global do logger para acesso rápido
final logger = LoggerService();
