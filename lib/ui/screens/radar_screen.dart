import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/models/peer.dart';

/// Tela de Radar SPEEW ALPHA-1
/// Visualiza nós conectados na malha mesh em tempo real
/// 
/// CARACTERÍSTICAS:
/// - Lista de peers conectados com status E2EE
/// - Contador de nós na malha
/// - Botão para ativar/desativar radar
/// - Design dark theme conforme especificação ALPHA-1
class RadarScreen extends StatefulWidget {
  final String userId;
  final String displayName;

  const RadarScreen({
    Key? key,
    required this.userId,
    required this.displayName,
  }) : super(key: key);

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  bool _isRadarActive = false;

  @override
  Widget build(BuildContext context) {
    final p2p = context.watch<P2PService>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'SPEEW ALPHA-1',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 8),
            Text('🔐', style: TextStyle(fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          // Header com contador de nós
          _buildHeader(p2p),
          
          // Divisor
          Divider(
            color: Colors.grey[700],
            thickness: 1,
            height: 1,
          ),
          
          // Lista de peers conectados
          Expanded(
            child: _buildPeersList(p2p),
          ),
          
          // Botão de controle do radar
          _buildRadarControl(p2p),
        ],
      ),
    );
  }

  /// Header com informações da malha
  Widget _buildHeader(P2PService p2p) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.grey[900]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Indicador de status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isRadarActive ? Colors.greenAccent : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: _isRadarActive
                      ? [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isRadarActive ? 'RADAR ATIVO' : 'RADAR INATIVO',
                style: TextStyle(
                  color: _isRadarActive ? Colors.greenAccent : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Contador de nós
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_tethering,
                color: Colors.greenAccent,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nós na Malha',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${p2p.connectedPeers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Lista de peers conectados
  Widget _buildPeersList(P2PService p2p) {
    if (p2p.connectedPeers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum nó detectado',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRadarActive
                  ? 'Aguardando conexões...'
                  : 'Ative o radar para começar',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: p2p.connectedPeers.length,
      itemBuilder: (context, index) {
        final peer = p2p.connectedPeers[index];
        return _buildPeerTile(peer);
      },
    );
  }

  /// Tile individual de peer
  Widget _buildPeerTile(Peer peer) {
    final timeSinceLastSeen = DateTime.now().difference(peer.lastSeen);
    final isRecent = timeSinceLastSeen.inSeconds < 30;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecent ? Colors.greenAccent.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_tethering,
            color: Colors.greenAccent,
            size: 24,
          ),
        ),
        title: Text(
          peer.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.lock,
                  size: 12,
                  color: Colors.green[300],
                ),
                const SizedBox(width: 4),
                Text(
                  'Conexão E2EE Ativa',
                  style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'ID: ${peer.peerId.substring(0, 8)}...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimeSince(timeSinceLastSeen),
              style: TextStyle(
                color: isRecent ? Colors.greenAccent : Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(peer.reputationScore * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Botão de controle do radar
  Widget _buildRadarControl(P2PService p2p) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _toggleRadar(p2p),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRadarActive ? Colors.red[700] : Colors.greenAccent,
              foregroundColor: _isRadarActive ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              shadowColor: _isRadarActive
                  ? Colors.red.withOpacity(0.5)
                  : Colors.greenAccent.withOpacity(0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRadarActive ? Icons.stop : Icons.radar,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _isRadarActive ? 'DESATIVAR RADAR' : 'ATIVAR RADAR',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Alterna o estado do radar
  Future<void> _toggleRadar(P2PService p2p) async {
    setState(() {
      _isRadarActive = !_isRadarActive;
    });

    if (_isRadarActive) {
      // Ativar radar
      final nodeName = 'SpeewNode_${DateTime.now().millisecond}';
      await p2p.startServer(widget.userId, nodeName);
      await p2p.startDiscovery();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                SizedBox(width: 12),
                Text('Radar ativado - Procurando nós...'),
              ],
            ),
            backgroundColor: Colors.grey[850],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Desativar radar
      await p2p.stopDiscovery();
      await p2p.stopServer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 12),
                Text('Radar desativado'),
              ],
            ),
            backgroundColor: Colors.grey[850],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Formata o tempo desde a última visualização
  String _formatTimeSince(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h';
    }
  }
}
