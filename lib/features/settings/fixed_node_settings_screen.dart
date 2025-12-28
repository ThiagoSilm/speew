import 'package:flutter/material.dart';
import 'package:rede_p2p_refactored/core/cloud/fixed_node_client.dart';
import 'package:rede_p2p_refactored/core/routing/failover_controller.dart';
import 'package:rede_p2p_refactored/lib/ui/components/app_button.dart';
import 'package:rede_p2p_refactored/lib/ui/components/app_input.dart';

// Mock de injeção de dependência para simulação
final FailoverController failoverController = FailoverController(
  MultiPathEngine(), // Mock
  FixedNodeClient(CryptoManager(), ReputationCore()), // Mock
  FNDiscoveryService(ReputationCore(), DistributedLedgerService()), // Mock
);

class FixedNodeSettingsScreen extends StatefulWidget {
  const FixedNodeSettingsScreen({super.key});

  @override
  State<FixedNodeSettingsScreen> createState() => _FixedNodeSettingsScreenState();
}

class _FixedNodeSettingsScreenState extends State<FixedNodeSettingsScreen> {
  final TextEditingController _addressController = TextEditingController();
  ConnectionStatus _status = ConnectionStatus.standalone;
  bool _isFallbackEnabled = true;

  @override
  void initState() {
    super.initState();
    _status = failoverController.status;
    _isFallbackEnabled = failoverController.isFallbackEnabled;
    // Em um app real, haveria um listener para mudanças de status
  }

  void _toggleFallback(bool value) {
    setState(() {
      _isFallbackEnabled = value;
      failoverController.setFallbackEnabled(value);
    });
  }

  void _addManualNode() {
    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      // Lógica para adicionar o nó manualmente (ex: via FN Discovery Service)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tentando adicionar FN: $address')),
      );
      _addressController.clear();
    }
  }

  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.meshLocal:
        return 'Conectado: Mesh Local (Preferido)';
      case ConnectionStatus.fixedNodeFallback:
        return 'Conectado: Fixed Node Fallback';
      case ConnectionStatus.standalone:
        return 'Status: Standalone (Sem Conexão Global)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações de Nodos Fixos (FN)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // Status
          ListTile(
            title: const Text('Status de Conexão'),
            subtitle: Text(_getStatusText(_status)),
            leading: Icon(
              _status == ConnectionStatus.meshLocal ? Icons.wifi_tethering : Icons.cloud,
              color: _status == ConnectionStatus.meshLocal ? Colors.green : Colors.orange,
            ),
          ),
          const Divider(),

          // Toggle Manual: "Usar Fixed Nodes como Fallback"
          SwitchListTile(
            title: const Text('Usar Fixed Nodes como Fallback'),
            subtitle: const Text('Permite que a rede use servidores de nuvem de alta reputação quando a mesh local falhar.'),
            value: _isFallbackEnabled,
            onChanged: _toggleFallback,
          ),
          const Divider(),

          // Campo para inserir o endereço IP/DNS de um FN de confiança (Manual Add)
          const Text('Adicionar Fixed Node Manualmente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AppInput(
            controller: _addressController,
            hintText: 'Endereço IP/DNS do Fixed Node',
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'Adicionar Nó',
            onPressed: _addManualNode,
          ),
          const Divider(),

          // Status Econômico do FN
          const Text('Status Econômico do Fixed Node', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Custo de Uso (Estimado)'),
            subtitle: const Text('~0.001 token/MB (Incentivo ao uso da Mesh Local)'),
          ),
          ListTile(
            title: const Text('Recompensa (Se você fosse um FN)'),
            subtitle: const Text('Multiplicador de 2.0x nos Relay Rewards (Reflete custo de infraestrutura)'),
          ),
        ],
      ),
    );
  }
}

// Mocks adicionais necessários para compilação
class CryptoManager {
  Uint8List signData(Uint8List data) => Uint8List(0);
  Uint8List encryptData(Uint8List data, String peerId) => Uint8List(0);
}
class ReputationCore {
  double getReputationScore(String peerId) => 0.99;
  void recordTrustEvent(String peerId, dynamic event) {}
}
class DistributedLedgerService {
  Future<List<Map<String, dynamic>>> getRegisteredFixedNodes() async => [];
}
class MultiPathEngine {
  Future<bool> tryRoute(dynamic packet) async => false;
  bool canFindLocalRoute() => true;
}
class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  const AppInput({super.key, required this.controller, required this.hintText});
  @override
  Widget build(BuildContext context) {
    return TextField(controller: controller, decoration: InputDecoration(hintText: hintText));
  }
}
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const AppButton({super.key, required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, child: Text(text));
  }
}
