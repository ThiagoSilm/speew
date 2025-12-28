// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'package:flutter/foundation.dart';
import 'dart:async';

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

// ==================== NotificationService ====================

/// Serviço de Notificações Locais (MVP).
/// Simula a funcionalidade de um plugin de notificações (ex: flutter_local_notifications).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  /// Inicializa o serviço de notificações.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Simulação de inicialização nativa
    logger.info('Inicializando serviço de notificações locais...', tag: 'NotificationService');
    
    // Em produção, aqui seria a chamada para o plugin nativo.
    await Future.delayed(const Duration(milliseconds: 50)); // Simula I/O
    
    _isInitialized = true;
    logger.info('Serviço de notificações inicializado.', tag: 'NotificationService');
  }

  /// Exibe uma notificação local.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      logger.warn('Serviço de notificações não inicializado. Chamando initialize()', tag: 'NotificationService');
      await initialize();
    }

    // Simulação de exibição de notificação no console
    final displayPayload = payload != null ? ' (Payload: $payload)' : '';
    logger.info('>>> NOTIFICAÇÃO EXIBIDA: "$title" - "$body"$displayPayload', tag: 'NotificationService');

    // Em produção, aqui seria a chamada para o método show() do plugin nativo.
  }

  /// Simula a lógica de background para exibir notificação de nova mensagem.
  Future<void> handleNewMessage({
    required String senderId,
    required String senderName,
    required String messageContent,
  }) async {
    // Esta lógica seria chamada pelo background processing nativo (Android/iOS)
    // quando uma nova mensagem P2P é recebida.
    
    final title = 'Nova Mensagem de $senderName';
    final body = messageContent.length > 50 
        ? '${messageContent.substring(0, 50)}...' 
        : messageContent;
    
    await showNotification(
      title: title,
      body: body,
      payload: senderId,
    );
    
    logger.info('Notificação de nova mensagem processada para $senderName', tag: 'NotificationService');
  }
}
