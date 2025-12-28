import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_theme.dart';
import '../../core/hardware/hardware_monitor_service.dart';
import '../../core/mesh/message_queue_processor.dart';
import '../../core/identity/device_identity_service.dart';
import '../../core/security/emergency_wipe_service.dart';

/// Tela de Controle de Missão (Terminal Militar/Médico)
/// 
/// Exibe o status crítico do sistema em tempo real.
class MissionControlScreen extends StatelessWidget {
  const MissionControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = DeviceIdentityService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPEEW ALPHA-1: MISSION CONTROL'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: AppTheme.primaryColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MessageScreen()),
              );
            },
            tooltip: 'Comms Terminal',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.infoColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsTerminalScreen()),
              );
            },
            tooltip: 'Settings Terminal',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: AppTheme.accentColor),
            onPressed: () => _showWipeDialog(context),
            tooltip: 'Emergency Wipe',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemInfo(theme, identity),
            const SizedBox(height: 24),
            _buildHardwareStatus(theme),
            const SizedBox(height: 24),
            _buildQueueStatus(theme),
            const SizedBox(height: 24),
            _buildLogWindow(theme),
          ],
        ),
      ),
    );
  }

  // ==================== WIDGETS DE INFORMAÇÃO ====================

  Widget _buildSystemInfo(ThemeData theme, DeviceIdentityService identity) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SISTEMA: ONLINE',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            _buildInfoRow(theme, 'PEER ID', identity.peerId),
            _buildInfoRow(theme, 'DEVICE NAME', identity.deviceName),
            _buildInfoRow(theme, 'CREATED AT', identity.createdAt.toIso8601String().substring(0, 19)),
            _buildInfoRow(theme, 'VERSION', 'ALPHA-1 (MISSION-CRITICAL)'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.infoColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.foregroundColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATUS DO HARDWARE ====================

  Widget _buildHardwareStatus(ThemeData theme) {
    final hardwareMonitor = HardwareMonitorService();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STATUS DO HARDWARE (ROBUSTEZ)',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            
            // Bluetooth Status
            StreamBuilder<BluetoothState>(
              stream: hardwareMonitor.bluetoothStateStream,
              initialData: hardwareMonitor.bluetoothState,
              builder: (context, snapshot) {
                final state = snapshot.data ?? BluetoothState.unknown;
                return _buildHardwareRow(
                  theme,
                  'BLUETOOTH',
                  state.toString().split('.').last.toUpperCase(),
                  _getHardwareColor(state),
                );
              },
            ),

            // GPS Status
            StreamBuilder<LocationState>(
              stream: hardwareMonitor.locationStateStream,
              initialData: hardwareMonitor.locationState,
              builder: (context, snapshot) {
                final state = snapshot.data ?? LocationState.unknown;
                return _buildHardwareRow(
                  theme,
                  'GPS/LOCATION',
                  state.toString().split('.').last.toUpperCase(),
                  _getHardwareColor(state),
                );
              },
            ),
            
            // Overall Status
            _buildHardwareOverall(theme, hardwareMonitor),
          ],
        ),
      ),
    );
  }

  Color _getHardwareColor(dynamic state) {
    if (state == BluetoothState.on || state == LocationState.on) {
      return AppTheme.primaryColor;
    } else if (state == BluetoothState.off || state == LocationState.off) {
      return AppTheme.warningColor;
    } else if (state == BluetoothState.permissionDenied || state == LocationState.permissionDenied) {
      return AppTheme.accentColor;
    }
    return AppTheme.infoColor;
  }

  Widget _buildHardwareRow(ThemeData theme, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.infoColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareOverall(ThemeData theme, HardwareMonitorService hardwareMonitor) {
    final isReady = hardwareMonitor.isHardwareReady;
    final color = isReady ? AppTheme.primaryColor : AppTheme.accentColor;
    final statusText = isReady ? 'OPERACIONAL' : 'CRÍTICO';

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'OVERALL:',
              style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.infoColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              statusText,
              style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATUS DA FILA ====================

  Widget _buildQueueStatus(ThemeData theme) {
    final queueProcessor = MessageQueueProcessor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BUFFER DE MENSAGENS (QUEUE)',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            
            // Queue Stats
            StreamBuilder<int>(
              stream: queueProcessor.onQueueSizeChanged?.stream,
              initialData: queueProcessor.getTotalQueueSize(),
              builder: (context, snapshot) {
                final totalSize = snapshot.data ?? queueProcessor.getTotalQueueSize();
                final stats = queueProcessor.getStats();
                final processing = stats['processing'];
                final queues = stats['queues'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQueueRow(theme, 'TOTAL ENFILEIRADO', totalSize.toString(), totalSize > 50 ? AppTheme.accentColor : AppTheme.primaryColor),
                    _buildQueueRow(theme, 'CRITICAL', queues['critical'].toString(), queues['critical'] > 0 ? AppTheme.accentColor : AppTheme.primaryColor),
                    _buildQueueRow(theme, 'HIGH', queues['high'].toString(), AppTheme.warningColor),
                    _buildQueueRow(theme, 'NORMAL', queues['normal'].toString(), AppTheme.infoColor),
                    _buildQueueRow(theme, 'PROCESSED', processing['processed'].toString(), AppTheme.primaryColor),
                    _buildQueueRow(theme, 'ERRORS', processing['errors'].toString(), processing['errors'] > 0 ? AppTheme.accentColor : AppTheme.primaryColor),
                    _buildQueueRow(theme, 'STATUS', processing['isPaused'] ? 'PAUSED' : 'ACTIVE', processing['isPaused'] ? AppTheme.warningColor : AppTheme.primaryColor),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueRow(ThemeData theme, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.infoColor),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LOG WINDOW (Simulação) ====================

  Widget _buildLogWindow(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SYSTEM LOG (PERSISTÊNCIA)',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                color: AppTheme.backgroundColor,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _getMockLog(),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.foregroundColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMockLog() {
    return '''
[2025-12-23 18:30:01] [INFO] [Identity] PeerId carregado: 8a7b6c5d-4e3f-4a2b-8c1d-9e0f1a2b3c4d
[2025-12-23 18:30:02] [INFO] [Crypto] Chaves Ed25519/X25519 carregadas do SecureStorage
[2025-12-23 18:30:03] [INFO] [Storage] SQLite criptografado inicializado
[2025-12-23 18:30:04] [INFO] [Queue] Processador de fila iniciado
[2025-12-23 18:30:05] [INFO] [Hardware] Monitoramento de hardware iniciado
[2025-12-23 18:30:06] [INFO] [Background] WakeLock ativado: CPU não entrará em deep sleep
[2025-12-23 18:30:07] [INFO] [Relay] NearbyRelayService inicializado
[2025-12-23 18:30:10] [WARN] [Hardware] GPS mudou de estado: unknown -> ON
[2025-12-23 18:30:15] [INFO] [Queue] Mensagem enfileirada: msg_1671745815_a1b2c3d4 (prioridade: critical)
[2025-12-23 18:30:16] [DEBUG] [Queue] Processando mensagem: msg_1671745815_a1b2c3d4
[2025-12-23 18:30:17] [INFO] [Relay] Mensagem 1671745815 retransmitida para 2 peers (TTL: 2)
[2025-12-23 18:30:20] [WARN] [Hardware] Bluetooth mudou de estado: ON -> OFF
[2025-12-23 18:30:20] [ERROR] [Hardware] ⚠️ BLUETOOTH DESLIGADO! Malha mesh comprometida
[2025-12-23 18:30:21] [WARN] [Queue] Processamento pausado
[2025-12-23 18:30:30] [INFO] [Background] Heartbeat enviado
[2025-12-23 18:30:40] [INFO] [Hardware] ✅ Bluetooth religado! Reconectando à malha...
[2025-12-23 18:30:43] [INFO] [Queue] Processamento retomado
[2025-12-23 18:30:45] [INFO] [Queue] Mensagem enfileirada: msg_1671745845_e5f6g7h8 (prioridade: normal)
[2025-12-23 18:30:46] [DEBUG] [Queue] Processando mensagem: msg_1671745845_e5f6g7h8
[2025-12-23 18:30:47] [INFO] [Storage] Auto-cleanup: 12 mensagens antigas removidas
''';
  }

  // ==================== WIPE DIALOG ====================

  void _showWipeDialog(BuildContext context) async {
    final wipe = EmergencyWipeService();
    final preview = await wipe.getWipePreview();
    final theme = Theme.of(context);

    // Gerar código de confirmação (simulado)
    const confirmationCode = 'WIPE_ALL';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          '⚠️ EMERGENCY WIPE PROTOCOL',
          style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.accentColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATENÇÃO: Esta ação é IRREVERSÍVEL! Todos os rastros de comunicação serão apagados.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.warningColor),
            ),
            const SizedBox(height: 16),
            Text(
              'DADOS A SEREM APAGADOS:',
              style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.infoColor),
            ),
            _buildInfoRow(theme, 'MESSAGES', preview['messages'].toString()),
            _buildInfoRow(theme, 'PEERS', preview['peers'].toString()),
            _buildInfoRow(theme, 'QUEUED', preview['queuedMessages'].toString()),
            _buildInfoRow(theme, 'IDENTITY', preview['identityExists'] ? 'YES' : 'NO'),
            _buildInfoRow(theme, 'CRYPTO KEYS', preview['cryptoKeysExist'] ? 'YES' : 'NO'),
            const SizedBox(height: 16),
            Text(
              'CONFIRME DIGITANDO: $confirmationCode',
              style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.accentColor),
            ),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Digite o código de confirmação',
                hintStyle: TextStyle(color: AppTheme.infoColor),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentColor),
                ),
              ),
              style: TextStyle(color: AppTheme.foregroundColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.primaryColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.backgroundColor,
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              // Simulação de execução
              _showProgressDialog(context, wipe);
              
              final result = await wipe.executeFullWipe(
                confirmationCode: confirmationCode,
              );
              
              Navigator.pop(context);
              
              if (result.success) {
                // Em um app real, isso forçaria o reinício
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('WIPE SUCESSO! Reinicie o aplicativo.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('WIPE FALHOU: ${result.message}')),
                );
              }
            },
            child: Text('EXECUTE WIPE'),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context, EmergencyWipeService wipe) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          'EXECUTANDO WIPE...',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.accentColor),
        ),
        content: StreamBuilder<WipeProgress>(
          stream: wipe.progressStream,
          builder: (context, snapshot) {
            final progress = snapshot.data;
            if (progress == null) {
              return const CircularProgressIndicator(color: AppTheme.primaryColor);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress.percentage / 100,
                  color: AppTheme.primaryColor,
                  backgroundColor: AppTheme.backgroundColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '${progress.percentage}% - ${progress.message}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.foregroundColor),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
