import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config/app_theme.dart';
import '../../core/identity/device_identity_service.dart';
import '../../core/hardware/hardware_monitor_service.dart';
import '../../core/crypto/crypto_manager.dart';
import '../../core/storage/encrypted_message_store.dart';
import '../dashboard/mission_control_screen.dart';

/// Tela de Configuração Inicial (Setup Wizard)
/// 
/// Guia o usuário na criação da identidade e concessão de permissões.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  final TextEditingController _nameController = TextEditingController();
  bool _permissionsGranted = false;
  
  final List<Permission> _requiredPermissions = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
    Permission.storage, // Para o SecureStorage e DB
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = DeviceIdentityService().deviceName;
  }

  void _nextStep() {
    setState(() {
      if (_currentStep < 2) {
        _currentStep++;
      } else {
        _finishSetup();
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  Future<void> _requestPermissions() async {
    final hardwareMonitor = Provider.of<HardwareMonitorService>(context, listen: false);
    final granted = await hardwareMonitor.requestPermissions();
    
    setState(() {
      _permissionsGranted = granted;
    });
    
    if (granted) {
      _nextStep();
    }
  }

  Future<void> _finishSetup() async {
    final identity = Provider.of<DeviceIdentityService>(context, listen: false);
    final crypto = Provider.of<CryptoManager>(context, listen: false);
    final store = Provider.of<EncryptedMessageStore>(context, listen: false);
    
    // 1. Salvar nome de exibição
    await identity.setDisplayName(_nameController.text.trim());
    
    // 2. Inicialização Atômica (Garantir que tudo foi criado)
    try {
      // A identidade já foi criada no main.dart, mas garantimos o nome
      
      // Gerar chaves criptográficas se ainda não existirem
      if (!crypto.isInitialized) {
        await crypto.initialize();
      }
      
      // Inicializar o storage criptografado
      if (!store.isInitialized) {
        await store.initialize();
      }
      
      // Marcar setup como completo (simulação de persistência atômica)
      await identity.markSetupComplete();

      // 3. Navegar para a tela principal
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MissionControlScreen()),
        );
      }
    } catch (e) {
      // Se qualquer passo falhar, o setup não é marcado como completo
      // e o usuário permanece no wizard.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERRO CRÍTICO NO SETUP: $e. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPEEW ALPHA-1: SETUP WIZARD'),
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _currentStep == 1 && !_permissionsGranted ? _requestPermissions : _nextStep,
        onStepCancel: _previousStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                if (_currentStep < 2)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 1 && !_permissionsGranted ? 'REQUEST PERMISSIONS' : 'CONTINUE'),
                  ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text('BACK', style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.infoColor)),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text('IDENTITY', style: theme.textTheme.bodyMedium),
            content: _buildIdentityStep(theme),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text('PERMISSIONS', style: theme.textTheme.bodyMedium),
            content: _buildPermissionsStep(theme),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text('READY', style: theme.textTheme.bodyMedium),
            content: _buildReadyStep(theme),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityStep(ThemeData theme) {
    final identity = Provider.of<DeviceIdentityService>(context, listen: false);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSO 1: CONFIGURAÇÃO DE IDENTIDADE',
          style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          'Seu Peer ID (Identidade na Malha) é gerado automaticamente e é imutável. Ele é a impressão digital do seu nó.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(theme, 'PEER ID', identity.peerId),
        const SizedBox(height: 16),
        Text(
          'Nome de Exibição (Display Name):',
          style: theme.textTheme.titleMedium,
        ),
        TextField(
          controller: _nameController,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.foregroundColor),
          decoration: const InputDecoration(
            hintText: 'Ex: Alpha-1-Node-001',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSO 2: PERMISSÕES CRÍTICAS DE HARDWARE',
          style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          'O Speew requer acesso total aos rádios de comunicação (Bluetooth e Localização) para operar a malha mesh. Sem estas permissões, o sistema não pode garantir a conectividade.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ..._requiredPermissions.map((p) => _buildPermissionStatus(theme, p)).toList(),
        const SizedBox(height: 16),
        if (!_permissionsGranted)
          Text(
            'STATUS: PENDENTE. Clique em "REQUEST PERMISSIONS" para continuar.',
            style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.accentColor),
          ),
        if (_permissionsGranted)
          Text(
            'STATUS: CONCEDIDO. Clique em "CONTINUE" para finalizar.',
            style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor),
          ),
      ],
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

  Widget _buildReadyStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSO 3: SISTEMA PRONTO',
          style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          'A configuração inicial do Speew Alpha-1 está completa. Seu nó está pronto para se conectar à malha mesh e operar em modo de missão crítica.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(theme, 'STATUS', 'OPERACIONAL'),
        _buildInfoRow(theme, 'PRÓXIMO', 'MISSION CONTROL DASHBOARD'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _finishSetup,
          child: const Text('LAUNCH MISSION CONTROL'),
        ),
      ],
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
}
