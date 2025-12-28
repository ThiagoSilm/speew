// test/background_mode_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:rede_p2p_refactored/core/power/energy_manager.dart';
import 'package:rede_p2p_refactored/core/background/background_service.dart';
import 'package:rede_p2p_refactored/core/storage/mesh/mesh_state_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Configuração inicial para simular o SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('EnergyManager Tests', () {
    test('Initial profile is Balanced Mode', () async {
      final manager = EnergyManager();
      expect(await manager.currentProfile.first, EnergyProfile.balancedMode);
      manager.dispose();
    });

    test('Low Battery triggers Low Battery Mode', () async {
      final manager = EnergyManager();
      // Simular bateria baixa (<15%)
      manager.batteryLevel = 10; 
      manager.simulateStateChange();
      
      expect(await manager.currentProfile.first, EnergyProfile.lowBatteryMode);
      expect(await manager.batteryState.first, BatteryState.low);
      manager.dispose();
    });

    test('Background Mode triggers Deep Background Relay Mode', () async {
      final manager = EnergyManager();
      manager.setBackgroundMode(true);
      
      expect(await manager.currentProfile.first, EnergyProfile.deepBackgroundRelayMode);
      manager.dispose();
    });

    test('Profile switches from Low Battery to Balanced when battery recovers', () async {
      final manager = EnergyManager();
      // 1. Entra em Low Battery
      manager.batteryLevel = 10; 
      manager.simulateStateChange();
      expect(await manager.currentProfile.first, EnergyProfile.lowBatteryMode);

      // 2. Bateria recupera (>15%)
      manager.batteryLevel = 25; 
      manager.simulateStateChange();
      expect(await manager.currentProfile.first, EnergyProfile.balancedMode);
      manager.dispose();
    });
  });

  group('BackgroundService Tests', () {
    test('Starting background mode sets EnergyManager to Deep Background Relay', () async {
      final manager = EnergyManager();
      final service = BackgroundService(manager);
      
      service.startBackgroundMode();
      expect(await manager.currentProfile.first, EnergyProfile.deepBackgroundRelayMode);
      expect(await service.isBackgroundActive.first, true);
      
      service.dispose();
      manager.dispose();
    });

    test('Stopping background mode reverts EnergyManager profile', () async {
      final manager = EnergyManager();
      final service = BackgroundService(manager);
      
      service.startBackgroundMode();
      expect(await manager.currentProfile.first, EnergyProfile.deepBackgroundRelayMode);
      
      service.stopBackgroundMode();
      // Deve voltar para o modo Balanced (estado padrão)
      expect(await manager.currentProfile.first, EnergyProfile.balancedMode); 
      expect(await service.isBackgroundActive.first, false);
      
      service.dispose();
      manager.dispose();
    });
  });

  group('MeshStateStorage Tests', () {
    test('Save and Load MeshState works correctly', () async {
      final storage = MeshStateStorage();
      final now = DateTime.now();
      final stateToSave = MeshState(
        knownPeers: ['peer1', 'peer2'],
        lastCalculatedRoute: 'route_a',
        lastSyncTime: now,
        pendingRetransmissionQueue: ['msg1', 'msg2'],
      );

      await storage.saveState(stateToSave);
      final loadedState = await storage.loadState();

      expect(loadedState.knownPeers, stateToSave.knownPeers);
      expect(loadedState.lastCalculatedRoute, stateToSave.lastCalculatedRoute);
      // Compara a string ISO para evitar problemas de precisão de DateTime
      expect(loadedState.lastSyncTime.toIso8601String(), stateToSave.lastSyncTime.toIso8601String()); 
      expect(loadedState.pendingRetransmissionQueue, stateToSave.pendingRetransmissionQueue);
    });

    test('Load MeshState returns empty state if no data is saved', () async {
      // Limpa o armazenamento simulado para garantir que não há dados
      SharedPreferences.setMockInitialValues({});
      final storage = MeshStateStorage();
      final loadedState = await storage.loadState();

      expect(loadedState.knownPeers, isEmpty);
      expect(loadedState.lastCalculatedRoute, '');
      expect(loadedState.pendingRetransmissionQueue, isEmpty);
    });
  });
}

// Extensão para permitir a simulação de mudança de estado no EnergyManager
extension EnergyManagerTestExtension on EnergyManager {
  set batteryLevel(int level) => _batteryLevel = level;
  void simulateStateChange() => _suggestAndApplyProfile();
}
