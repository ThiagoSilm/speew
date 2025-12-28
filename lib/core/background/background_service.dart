// lib/core/background/background_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../power/energy_manager.dart';

// Classe para gerenciar a execução em segundo plano
class BackgroundService {
  final EnergyManager _energyManager;
  Timer? _backgroundTimer;
  final _isBackgroundActive = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isBackgroundActive => _isBackgroundActive.stream;

  BackgroundService(this._energyManager) {
    // Observa o perfil de energia para ajustar o comportamento em segundo plano
    _energyManager.currentProfile.listen(_handleEnergyProfileChange);
  }

  void _handleEnergyProfileChange(EnergyProfile profile) {
    if (kDebugMode) {
      print('BackgroundService: Perfil de Energia alterado para ${profile.name}');
    }
    // Ajusta a frequência do timer com base no perfil
    switch (profile) {
      case EnergyProfile.deepBackgroundRelayMode:
        _startBackgroundRelay(const Duration(seconds: 60)); // Wake pattern de 60s
        break;
      case EnergyProfile.lowBatteryMode:
        _startBackgroundRelay(const Duration(seconds: 30)); // Wake pattern de 30s
        break;
      case EnergyProfile.balancedMode:
      case EnergyProfile.highPerformanceMesh:
        // Se estiver em foreground ou com bateria alta, o timer pode ser mais frequente ou desnecessário
        if (_isBackgroundActive.value) {
          _startBackgroundRelay(const Duration(seconds: 15)); // Wake pattern de 15s
        }
        break;
    }
  }

  // Inicia o modo de execução em segundo plano (simulado)
  void startBackgroundMode() {
    if (_isBackgroundActive.value) return;

    _isBackgroundActive.add(true);
    _energyManager.setBackgroundMode(true);
    if (kDebugMode) {
      print('BackgroundService: Modo Background Iniciado.');
    }
    // O timer será iniciado/ajustado por _handleEnergyProfileChange
  }

  // Para o modo de execução em segundo plano
  void stopBackgroundMode() {
    if (!_isBackgroundActive.value) return;

    _isBackgroundActive.add(false);
    _energyManager.setBackgroundMode(false);
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    if (kDebugMode) {
      print('BackgroundService: Modo Background Parado.');
    }
  }

  // Inicia o timer de retransmissão em segundo plano (Wake Patterns Inteligentes)
  void _startBackgroundRelay(Duration interval) {
    _backgroundTimer?.cancel(); // Cancela o timer anterior

    // Simula o Wake Pattern Inteligente
    _backgroundTimer = Timer.periodic(interval, (timer) {
      if (kDebugMode) {
        print('BackgroundService: Wake Pattern ativado (${interval.inSeconds}s). Executando rotinas leves...');
      }
      // 1. Retransmitir pacotes em segundo plano
      _relayPendingPackets();
      // 2. Sincronizar ledger e contratos periodicamente (rotinas leves de manutenção)
      _performPeriodicSync();
      // 3. Manter mesh ativa (keep-alive mínimo)
      _sendKeepAlive();
    });
  }

  // Simula a retransmissão de pacotes
  void _relayPendingPackets() {
    // Lógica para retransmitir pacotes críticos (contratos, pagamentos, sinais mesh)
    if (kDebugMode) {
      print('BackgroundService: Retransmitindo pacotes pendentes...');
    }
  }

  // Simula a sincronização periódica
  void _performPeriodicSync() {
    // Lógica para sincronizar ledger e contratos
    if (kDebugMode) {
      print('BackgroundService: Executando sincronização periódica leve...');
    }
  }

  // Simula o envio de keep-alive
  void _sendKeepAlive() {
    // Lógica para manter a conexão mesh mínima
    if (kDebugMode) {
      print('BackgroundService: Enviando keep-alive mínimo...');
    }
  }

  // Método chamado quando o app retorna para o foreground
  void onAppForegrounded() {
    stopBackgroundMode(); // Para o modo background e retorna ao modo normal
    // Lógica para reconectar mesh ao retornar para foreground
    if (kDebugMode) {
      print('BackgroundService: App em Foreground. Reconectando mesh...');
    }
  }

  // Método chamado quando o app vai para o background
  void onAppBackgrounded() {
    startBackgroundMode();
  }

  void dispose() {
    _backgroundTimer?.cancel();
    _isBackgroundActive.close();
  }
}
