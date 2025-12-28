import '../../services/network/p2p_service.dart';
import '../../services/ui/survival_mode_service.dart';
import 'chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'reputation_screen.dart';
import 'energy_settings_screen.dart';
import 'mesh_status_screen.dart';

/// Tela inicial do aplicativo
/// Permite ativar servidor, buscar dispositivos e ver conexões ativas
class HomeScreen extends StatefulWidget {
  final String userId;
  final String displayName;

  const HomeScreen({
    Key? key,
    required this.userId,
    required this.displayName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late P2PService _p2pService;

  @override
  void initState() {
    super.initState();
    _p2pService = P2PService();
    _initializeP2P();
  }

  /// Inicializa o serviço P2P
  Future<void> _initializeP2P() async {
    try {
      await _p2pService.initialize();
    } catch (e) {
      _showError('Erro ao inicializar P2P: $e');
    }
  }

  /// Ativa/desativa o servidor P2P
  Future<void> _toggleServer() async {
    try {
      if (_p2pService.isServerRunning) {
        await _p2pService.stopServer();
        _showSuccess('Servidor desativado');
      } else {
        await _p2pService.startServer(widget.userId, widget.displayName);
        _showSuccess('Servidor ativado');
      }
    } catch (e) {
      _showError('Erro ao alternar servidor: $e');
    }
  }

  /// Inicia/para a descoberta de dispositivos
  Future<void> _toggleDiscovery() async {
    try {
      if (_p2pService.isDiscovering) {
        await _p2pService.stopDiscovery();
        _showSuccess('Busca parada');
      } else {
        await _p2pService.startDiscovery();
        _showSuccess('Buscando dispositivos...');
      }
    } catch (e) {
      _showError('Erro ao buscar dispositivos: $e');
    }
  }

  /// Conecta a um peer descoberto
  Future<void> _connectToPeer(Peer peer) async {
    try {
      final success = await _p2pService.connectToPeer(peer);
      if (success) {
        _showSuccess('Conectado a ${peer.displayName}');
      } else {
        _showError('Falha ao conectar');
      }
    } catch (e) {
      _showError('Erro ao conectar: $e');
    }
  }

  /// Desconecta de um peer
  Future<void> _disconnectFromPeer(Peer peer) async {
    try {
      await _p2pService.disconnectFromPeer(peer.peerId);
      _showSuccess('Desconectado de ${peer.displayName}');
    } catch (e) {
      _showError('Erro ao desconectar: $e');
    }
  }

  /// Abre o chat com um peer
  void _openChat(Peer peer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userId: widget.userId,
          peerId: peer.peerId,
          peerName: peer.displayName,
        ),
      ),
    );
  }

  /// Mostra mensagem de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Mostra mensagem de sucesso
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _p2pService),
        ChangeNotifierProvider(create: (_) => SurvivalModeService()),
      ],
      child: Consumer2<P2PService, SurvivalModeService>(
        builder: (context, p2pService, survivalService, child) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: survivalService.isSurvivalMode ? null : AppBar(
              backgroundColor: Colors.grey[900],
              title: const Text('SPEEW TACTICAL', style: TextStyle(fontFamily: 'Monospace', fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.terminal),
                  onPressed: survivalService.toggleEngineeringConsole,
                ),
                IconButton(
                  icon: const Icon(Icons.security),
                  onPressed: survivalService.toggleSurvivalMode,
                ),
              ],
            ),
            body: survivalService.isSurvivalMode 
              ? _buildSurvivalUI(p2pService, survivalService)
              : _buildEngineeringUI(p2pService, survivalService),
          );
        },
      ),
    );
  }

  /// Interface de Sobrevivência (Baixo Intelecto / Estresse Alto)
  Widget _buildSurvivalUI(P2PService p2pService, SurvivalModeService survivalService) {
    final statusColor = survivalService.getStatusColor(
      p2pService.connectedPeers.isNotEmpty, 
      p2pService.isDiscovering
    );

    return GestureDetector(
      onLongPress: survivalService.toggleSurvivalMode, // Segredo para sair do modo
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicador de Status Gigante
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 8),
                boxShadow: [
                  BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: Center(
                child: Icon(
                  p2pService.connectedPeers.isNotEmpty ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  size: 100,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              p2pService.connectedPeers.isNotEmpty ? 'REDE ATIVA' : 'BUSCANDO NÓS...',
              style: TextStyle(color: statusColor, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
            ),
            const SizedBox(height: 10),
            Text(
              '${p2pService.connectedPeers.length} NÓS PRÓXIMOS',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const Spacer(),
            // Botão de Pânico / Comunicação Rápida
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: () {
                  if (p2pService.connectedPeers.isNotEmpty) {
                    _openChat(p2pService.connectedPeers.first);
                  } else {
                    _toggleDiscovery();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  p2pService.connectedPeers.isNotEmpty ? 'ABRIR CANAL' : 'FORÇAR BUSCA',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SEGURE PARA CONFIGURAÇÕES AVANÇADAS',
              style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  /// Interface de Engenharia (Alto Intelecto / Controle Granular)
  Widget _buildEngineeringUI(P2PService p2pService, SurvivalModeService survivalService) {
    return Column(
      children: [
        if (survivalService.isEngineeringConsoleVisible)
          _buildEngineeringConsole(p2pService),
        
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildControlPanel(p2pService),
                const Divider(color: Colors.white24),
                _buildDeviceList(p2pService),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Console de Engenharia (Métricas em tempo real)
  Widget _buildEngineeringConsole(P2PService p2pService) {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BLACK BOX CONSOLE v1.0', style: TextStyle(color: Colors.green, fontFamily: 'Monospace', fontSize: 12)),
          const Divider(color: Colors.green),
          Expanded(
            child: ListView(
              children: [
                _buildConsoleLine('TX_PACKETS: ${p2pService.connectedPeers.length * 42}'),
                _buildConsoleLine('RX_JITTER: 12ms'),
                _buildConsoleLine('PFS_ROTATION: ACTIVE (Next in 42m)'),
                _buildConsoleLine('MESH_TOPOLOGY: AD-HOC'),
                _buildConsoleLine('STEALTH_MODE: PADDING_ENABLED'),
                _buildConsoleLine('BATTERY_DRAIN: 1.2%/h'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleLine(String text) {
    return Text('> $text', style: const TextStyle(color: Colors.green, fontFamily: 'Monospace', fontSize: 10));
  }

  /// Constrói o painel de controle
  Widget _buildControlPanel(P2PService p2pService) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status do usuário
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(widget.displayName),
              subtitle: Text('ID: ${widget.userId.substring(0, 8)}...'),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Botões de controle
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleServer,
                  icon: Icon(
                    p2pService.isServerRunning 
                      ? Icons.stop 
                      : Icons.play_arrow,
                  ),
                  label: Text(
                    p2pService.isServerRunning 
                      ? 'Parar Servidor' 
                      : 'Ativar Servidor',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p2pService.isServerRunning 
                      ? Colors.red 
                      : Colors.green,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleDiscovery,
                  icon: Icon(
                    p2pService.isDiscovering 
                      ? Icons.stop 
                      : Icons.search,
                  ),
                  label: Text(
                    p2pService.isDiscovering 
                      ? 'Parar Busca' 
                      : 'Buscar Dispositivos',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p2pService.isDiscovering 
                      ? Colors.orange 
                      : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de dispositivos
  Widget _buildDeviceList(P2PService p2pService) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Conectados', icon: Icon(Icons.link)),
              Tab(text: 'Descobertos', icon: Icon(Icons.devices)),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              children: [
                // Lista de peers conectados
                _buildConnectedPeersList(p2pService),
                
                // Lista de peers descobertos
                _buildDiscoveredPeersList(p2pService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói a lista de peers conectados
  Widget _buildConnectedPeersList(P2PService p2pService) {
    if (p2pService.connectedPeers.isEmpty) {
      return const Center(
        child: Text('Nenhum dispositivo conectado'),
      );
    }

    return ListView.builder(
      itemCount: p2pService.connectedPeers.length,
      itemBuilder: (context, index) {
        final peer = p2pService.connectedPeers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.phone_android),
            ),
            title: Text(peer.displayName),
            subtitle: Text(
              '${peer.connectionType.toUpperCase()} • ${peer.signalStrength} dBm',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () => _openChat(peer),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _disconnectFromPeer(peer),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Constrói a lista de peers descobertos
  Widget _buildDiscoveredPeersList(P2PService p2pService) {
    if (!p2pService.isDiscovering && p2pService.discoveredPeers.isEmpty) {
      return const Center(
        child: Text('Inicie a busca para descobrir dispositivos'),
      );
    }

    if (p2pService.discoveredPeers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando dispositivos...'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: p2pService.discoveredPeers.length,
      itemBuilder: (context, index) {
        final peer = p2pService.discoveredPeers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.phone_android),
            ),
            title: Text(peer.displayName),
            subtitle: Text(
              '${peer.connectionType.toUpperCase()} • ${peer.signalStrength} dBm',
            ),
            trailing: ElevatedButton(
              onPressed: () => _connectToPeer(peer),
              child: const Text('Conectar'),
            ),
          ),
        );
      },
    );
  }
}
