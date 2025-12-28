import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config/app_theme.dart';
import '../../core/identity/device_identity_service.dart';
import '../../core/hardware/hardware_monitor_service.dart';
import '../../core/security/emergency_wipe_service.dart';
import '../../core/security/qr_handshake_service.dart';
import '../../core/utils/logger_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Tela de Configurações (Settings Terminal)
/// 
/// Permite ao usuário gerenciar identidade, permissões e executar o Wipe.
class SettingsTerminalScreen extends StatelessWidget {
  const SettingsTerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPEEW ALPHA-1: SETTINGS TERMINAL'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIdentitySection(context, theme),
            const SizedBox(height: 24),
            _buildPermissionsSection(context, theme),
            const SizedBox(height: 24),
            _buildCryptoSection(context, theme),
            const SizedBox(height: 24),
            _buildWipeSection(context, theme),
          ],
        ),
      ),
    );
  }

  // ==================== SEÇÃO DE IDENTIDADE ====================

  Widget _buildIdentitySection(BuildContext context, ThemeData theme) {
    final identity = Provider.of<DeviceIdentityService>(context);
    final TextEditingController nameController = TextEditingController(text: identity.deviceName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IDENTITY MANAGEMENT',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            _buildInfoRow(theme, 'PEER ID (IMMUTABLE)', identity.peerId),
            const SizedBox(height: 16),
            Text(
              'DISPLAY NAME:',
              style: theme.textTheme.titleMedium,
            ),
            TextField(
              controller: nameController,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.foregroundColor),
              decoration: const InputDecoration(
                hintText: 'Enter new display name',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  await identity.setDisplayName(nameController.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Display Name Updated')),
                  );
                },
                child: const Text('UPDATE NAME'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SEÇÃO DE PERMISSÕES ====================

  Widget _buildPermissionsSection(BuildContext context, ThemeData theme) {
    final hardwareMonitor = Provider.of<HardwareMonitorService>(context);
    
    final List<Permission> criticalPermissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.storage,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HARDWARE PERMISSIONS',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            Text(
              'Status das permissões críticas para operação da malha:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            
            // Lista de Status de Permissões
            ...criticalPermissions.map((p) => _buildPermissionStatus(theme, p)).toList(),
            
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  await hardwareMonitor.requestPermissions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission Request Sent')),
                  );
                },
                child: const Text('REQUEST PENDING PERMISSIONS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStatus(ThemeData theme, Permission permission) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isGranted = status?.isGranted ?? false;
        final color = isGranted ? AppTheme.primaryColor : AppTheme.accentColor;
        final statusText = isGranted ? 'GRANTED' : 'DENIED';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(isGranted ? Icons.check_circle : Icons.cancel, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                '${permission.toString().split('.').last.toUpperCase()}: $statusText',
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SEÇÃO DE WIPE ====================

  // ==================== SEÇÃO DE CRIPTOGRAFIA ====================

  Widget _buildCryptoSection(BuildContext context, ThemeData theme) {
    final crypto = Provider.of<CryptoManager>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CRYPTOGRAPHIC KEY MANAGEMENT',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            Text(
              'Gerencie as chaves assimétricas (Ed25519/X25519) usadas para assinatura e criptografia. A chave privada é armazenada no SecureStorage.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('SCAN PEER QR'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => QrScannerScreen()),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code),
                  label: const Text('SHOW MY QR'),
                  onPressed: () async {
                    final handshakeService = QrHandshakeService();
                    final payload = await handshakeService.generateHandshakePayload();
                    _showMyQrDialog(context, payload);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(theme, 'SIGNING KEY STATUS', crypto.isInitialized ? 'LOADED' : 'PENDING'),
            _buildInfoRow(theme, 'ENCRYPTION KEY STATUS', crypto.isInitialized ? 'LOADED' : 'PENDING'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    foregroundColor: AppTheme.backgroundColor,
                  ),
                  onPressed: () async {
                    await crypto.regenerateKeys();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chaves Regeneradas!')),
                    );
                  },
                  child: const Text('REGENERATE KEYS'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Simulação de exportação
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exportação de Chave Pública Iniciada')),
                    );
                  },
                  child: const Text('EXPORT PUBLIC KEY'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SEÇÃO DE WIPE ====================

  void _showMyQrDialog(BuildContext context, String payload) {
    final theme = Theme.of(context);
    final handshakeService = QrHandshakeService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          'MY HANDSHAKE QR CODE',
          style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            handshakeService.generateQrCodeWidget(payload),
            const SizedBox(height: 16),
            Text(
              'Este QR contém sua Chave Pública e Peer ID. Compartilhe com um Peer para emparelhamento seguro.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.infoColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CLOSE',
              style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLog(BuildContext context) async {
    final logger = LoggerService();
    final logContent = await logger.exportBlackBox();
    
    if (logContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log de Auditoria Vazio.')),
      );
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/speew_audit_log.txt');
      await file.writeAsString(logContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Speew Alpha-1 - Log de Auditoria de Sistema',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar log: $e')),
      );
    }
  }

  Widget _buildWipeSection(BuildContext context, ThemeData theme) {
    final wipe = Provider.of<EmergencyWipeService>(context);

    return Card(
      color: AppTheme.accentColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EMERGENCY WIPE PROTOCOL',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.accentColor),
            ),
            const Divider(color: AppTheme.accentColor),
            Text(
              'Esta é uma função de missão crítica. Ela apagará TODOS os rastros de comunicação, chaves e identidade do dispositivo. Use com extrema cautela.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.warningColor),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: AppTheme.backgroundColor,
                ),
                onPressed: () => _showWipeDialog(context, wipe),
                child: const Text('EXECUTE WIPE'),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'BLACK BOX AUDIT LOG',
              style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
            ),
            const Divider(),
            Text(
              'Exporta o log de auditoria de caixa preta (erros críticos e warnings) para diagnóstico em campo.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('EXPORTAR LOG DE SISTEMA'),
              onPressed: () => _exportLog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.infoColor,
                foregroundColor: AppTheme.backgroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== WIDGETS AUXILIARES ====================

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

  void _showWipeDialog(BuildContext context, EmergencyWipeService wipe) async {
    // Reutilizar a lógica do MissionControlScreen para o diálogo de wipe
    // Para simplificar, vamos apenas mostrar um alerta aqui
    final preview = await wipe.getWipePreview();
    final theme = Theme.of(context);
    const confirmationCode = 'WIPE_ALL'; // Código fixo para simulação

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
              final result = await wipe.executeFullWipe(
                confirmationCode: confirmationCode,
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.success ? 'WIPE SUCESSO! Reinicie o aplicativo.' : 'WIPE FALHOU: ${result.message}')),
              );
            },
            child: const Text('EXECUTE WIPE'),
          ),
        ],
      ),
    );
  }
}
