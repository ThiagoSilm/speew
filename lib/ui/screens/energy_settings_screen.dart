// lib/ui/screens/energy_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/power/energy_manager.dart';
import '../../core/background/background_service.dart';

class EnergySettingsScreen extends StatelessWidget {
  const EnergySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final energyManager = Provider.of<EnergyManager>(context);
    final backgroundService = Provider.of<BackgroundService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações de Energia e Background'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Perfil Atual
          StreamBuilder<EnergyProfile>(
            stream: energyManager.currentProfile,
            builder: (context, snapshot) {
              final profile = snapshot.data ?? EnergyProfile.balancedMode;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bolt, color: Colors.amber),
                  title: const Text('Perfil de Energia Atual'),
                  subtitle: Text(_getProfileDescription(profile)),
                  trailing: const Icon(Icons.info_outline),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 2. Nível de Bateria e Modo Ativo
          StreamBuilder<BatteryState>(
            stream: energyManager.batteryState,
            builder: (context, snapshot) {
              final batteryState = snapshot.data ?? BatteryState.discharging;
              return ListTile(
                leading: const Icon(Icons.battery_full),
                title: Text('Nível de Bateria: ${energyManager.batteryLevel}%'),
                subtitle: Text('Estado: ${_getBatteryStateText(batteryState)}'),
              );
            },
          ),

          // 3. Modo Background
          StreamBuilder<bool>(
            stream: backgroundService.isBackgroundActive,
            builder: (context, snapshot) {
              final isActive = snapshot.data ?? false;
              return SwitchListTile(
                title: const Text('Modo Background (Relay)'),
                subtitle: const Text('Permite retransmissão de pacotes com a tela desligada.'),
                value: isActive,
                onChanged: (bool value) {
                  if (value) {
                    backgroundService.startBackgroundMode();
                  } else {
                    backgroundService.stopBackgroundMode();
                  }
                },
              );
            },
          ),

          const Divider(height: 32),

          // 4. Uso da Mesh (Simulado)
          ListTile(
            leading: const Icon(Icons.network_check),
            title: const Text('Uso da Mesh (últimos 5 min)'),
            subtitle: const Text('Simulação: 12MB retransmitidos, 45% de atividade.'),
          ),

          // 5. Economia Prevista (Simulado)
          ListTile(
            leading: const Icon(Icons.eco),
            title: const Text('Economia Prevista'),
            subtitle: const Text('Otimização energética deve economizar ~20% de bateria em modo inativo.'),
          ),
        ],
      ),
    );
  }

  String _getProfileDescription(EnergyProfile profile) {
    switch (profile) {
      case EnergyProfile.highPerformanceMesh:
        return 'Alto Desempenho: Prioriza velocidade e multi-path. (Bateria > 80%)';
      case EnergyProfile.balancedMode:
        return 'Modo Balanceado: Otimização padrão entre velocidade e consumo.';
      case EnergyProfile.lowBatteryMode:
        return 'Bateria Baixa: Redução de atividade, desativa multi-path. (Bateria < 15%)';
      case EnergyProfile.deepBackgroundRelayMode:
        return 'Relay em Background: Consumo mínimo, apenas retransmissão crítica.';
    }
  }

  String _getBatteryStateText(BatteryState state) {
    switch (state) {
      case BatteryState.full:
        return 'Completa';
      case BatteryState.charging:
        return 'Carregando';
      case BatteryState.discharging:
        return 'Descarregando';
      case BatteryState.low:
        return 'Baixa (Modo de Emergência Ativado)';
      case BatteryState.critical:
        return 'Crítica (Desligamento Iminente)';
    }
  }
}
