import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/config/app_config.dart';
import '../../services/ui/survival_mode_service.dart';
import '../themes/app_theme.dart';
import '../components/p2p_components.dart';
import 'package:provider/provider.dart';

/// Tela de status da rede mesh
class MeshStatusScreen extends StatefulWidget {
  final User currentUser;

  const MeshStatusScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<MeshStatusScreen> createState() => _MeshStatusScreenState();
}

class _MeshStatusScreenState extends State<MeshStatusScreen> {
  final P2PService _p2pService = P2PService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _p2pService.isServerRunning;
    final peersCount = _p2pService.connectedPeers.length;
    final survivalService = Provider.of<SurvivalModeService>(context, listen: false);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('MESH ANALYTICS', style: TextStyle(fontFamily: 'Monospace')),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showAdvancedConfig(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (survivalService.isEngineeringConsoleVisible)
            _buildPacketSniffer(context),
          const SizedBox(height: 16),
        // Status geral
        AppCard(
          child: Column(
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error_outline,
                size: 64,
                color: isConnected ? AppTheme.success : AppTheme.error,
              ),
              SizedBox(height: 16),
              Text(
                isConnected ? 'Rede Ativa' : 'Rede Inativa',
                style: theme.textTheme.displaySmall,
              ),
              SizedBox(height: 8),
              Text(
                isConnected
                    ? '$peersCount ${peersCount == 1 ? 'peer conectado' : 'peers conectados'}'
                    : 'Nenhum peer conectado',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        
        // Métricas
        SizedBox(height: 16),
        Text(
          'Métricas da Rede',
          style: theme.textTheme.titleLarge,
        ),
        SizedBox(height: 12),
        
        _buildMetricCard(
          context,
          'Máximo de Hops',
          '${AppConfig.maxHops}',
          Icons.route,
          AppTheme.info,
        ),
        
        _buildMetricCard(
          context,
          'Perda Máxima',
          '${(AppConfig.maxPacketLoss * 100).toStringAsFixed(0)}%',
          Icons.signal_cellular_alt,
          AppTheme.warning,
        ),
        
        _buildMetricCard(
          context,
          'Conexões Máximas',
          '${AppConfig.maxConnections}',
          Icons.people,
          AppTheme.success,
        ),
        
        // Peers conectados
        if (peersCount > 0) ...[
          SizedBox(height: 24),
          Text(
            'Peers Conectados',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _p2pService.connectedPeers.map((peer) {
              return MeshNodeBubble(
                nodeId: peer.peerId,
                displayName: peer.displayName,
                isOnline: true,
                hops: 0,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  /// Simulação de Sniffer de Pacotes para Alto Intelecto
  Widget _buildPacketSniffer(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.green.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PACKET SNIFFER [LIVE]', style: TextStyle(color: Colors.green, fontFamily: 'Monospace', fontSize: 10)),
          const Divider(color: Colors.green, height: 8),
          Expanded(
            child: ListView(
              children: [
                _buildSnifferLine('IN: [AES-GCM] 128 bytes from node_a72b'),
                _buildSnifferLine('OUT: [DECOY] 512 bytes to broadcast'),
                _buildSnifferLine('PFS: Key rotation successful (ID: 0x9f)'),
                _buildSnifferLine('MESH: Route optimized via node_f12'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnifferLine(String text) {
    return Text('> $text', style: const TextStyle(color: Colors.green, fontFamily: 'Monospace', fontSize: 9));
  }

  /// Configuração Avançada para Alto Intelecto
  void _showAdvancedConfig(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ENGINEERING OVERRIDE', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOverrideSwitch('Forçar Stealth Extremo', true),
            _buildOverrideSwitch('Desativar Decoy Traffic', false),
            _buildOverrideSwitch('Modo de Depuração Bruta', true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('APLICAR PARÂMETROS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverrideSwitch(String label, bool value) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      value: value,
      onChanged: (v) {},
      activeColor: Colors.green,
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
