import 'package:flutter/material.dart';
import 'package:rede_p2p_refactored/core/crypto/key_rotation_service.dart';
import 'package:rede_p2p_refactored/core/mesh/traffic_obfuscator.dart';
import 'package:rede_p2p_refactored/lib/ui/components/app_button.dart';

// Mocks de injeção de dependência para simulação
final TrafficObfuscator trafficObfuscator = TrafficObfuscator(P2PService()); // Mock
final KeyRotationService keyRotationService = KeyRotationService('mock_session_id', () async {
  // Simulação de rotação de chave
  await Future.delayed(const Duration(milliseconds: 100));
});

class AdvancedSecuritySettingsScreen extends StatefulWidget {
  const AdvancedSecuritySettingsScreen({super.key});

  @override
  State<AdvancedSecuritySettingsScreen> createState() => _AdvancedSecuritySettingsScreenState();
}

class _AdvancedSecuritySettingsScreenState extends State<AdvancedSecuritySettingsScreen> {
  bool _isExtremeObfuscationEnabled = false;
  Map<String, dynamic> _rotationStatus = {};

  @override
  void initState() {
    super.initState();
    _isExtremeObfuscationEnabled = trafficObfuscator._extremeObfuscation;
    _rotationStatus = keyRotationService.getStatus();
  }

  void _toggleExtremeObfuscation(bool value) {
    setState(() {
      _isExtremeObfuscationEnabled = value;
      trafficObfuscator.setExtremeObfuscation(value);
    });
  }

  void _forceKeyRotation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forçando Rotação de Chave...')),
    );
    await keyRotationService.forceRotation(RotationTrigger.event);
    setState(() {
      _rotationStatus = keyRotationService.getStatus();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rotação de Chave Concluída.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações de Segurança Avançada'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // Status de Criptografia
          ListTile(
            title: const Text('Criptografia Híbrida (PQC)'),
            subtitle: const Text('Status: Ativa. Garante Resistência Quântica e PFS.'),
            leading: const Icon(Icons.lock_outline, color: Colors.green),
          ),
          const Divider(),

          // Toggle Manual: "Modo de Ofuscação Extrema"
          SwitchListTile(
            title: const Text('Modo de Ofuscação Extrema (V2)'),
            subtitle: const Text('Ativa Padding Máximo e Jitter Alto. Aumenta a privacidade, mas pode adicionar latência.'),
            value: _isExtremeObfuscationEnabled,
            onChanged: _toggleExtremeObfuscation,
          ),
          const Divider(),

          // Status da Última Rotação de Chave
          const Text('Rotação Dinâmica de Chaves (DKR)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ListTile(
            title: const Text('Pacotes Enviados desde a Última Rotação'),
            subtitle: Text('${_rotationStatus['packetsSent']} / ${_rotationStatus['volumeTrigger']}'),
          ),
          ListTile(
            title: const Text('Próxima Rotação (Tempo)'),
            subtitle: Text('A cada ${_rotationStatus['timeTrigger']} minutos (Simulado)'),
          ),
          
          // Opção para Forçar Rotação de Chave de Sessão
          const SizedBox(height: 16),
          AppButton(
            text: 'Forçar Rotação de Chave de Sessão',
            onPressed: _forceKeyRotation,
          ),
        ],
      ),
    );
  }
}

// Mocks adicionais necessários para compilação
class P2PService {
  void randomizeNextRoute() {}
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
