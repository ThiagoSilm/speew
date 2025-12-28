import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/p2p/p2p_service.dart';

/// Widget para exibir o status de sincronização Multi-Dispositivo
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p2pService = Provider.of<P2PService>(context);
    
    // Simulação de estado de sincronização
    final isSyncing = p2pService.isServerRunning && p2pService.connectedPeers.isNotEmpty;
    final connectedDevices = p2pService.connectedPeers.length;
    
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isSyncing) {
      statusText = 'Sincronizado com $connectedDevices dispositivo(s)';
      statusColor = Colors.green;
      statusIcon = Icons.sync;
    } else if (p2pService.isServerRunning) {
      statusText = 'Aguardando sincronização...';
      statusColor = Colors.orange;
      statusIcon = Icons.sync_problem;
    } else {
      statusText = 'Serviço P2P inativo';
      statusColor = Colors.red;
      statusIcon = Icons.sync_disabled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
