import 'package:flutter/material.dart';
import '../../core/crypto/crypto_manager.dart';
import '../../core/models/user.dart';
import '../../core/storage/repository_pattern.dart';
import '../../core/utils/logger_service.dart';
import '../themes/app_theme.dart';
import '../components/app_button.dart';
import '../components/app_input.dart';
import '../components/p2p_components.dart';

/// Tela de criação de identidade
class SetupIdentityScreen extends StatefulWidget {
  final Function(User) onComplete;

  const SetupIdentityScreen({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SetupIdentityScreen> createState() => _SetupIdentityScreenState();
}

class _SetupIdentityScreenState extends State<SetupIdentityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final CryptoManager _cryptoManager = CryptoManager();
  
  Color _selectedColor = AppTheme.primaryDark;
  bool _isCreating = false;

  final List<Color> _availableColors = [
    AppTheme.primaryDark,
    AppTheme.secondaryDark,
    AppTheme.accentDark,
    AppTheme.success,
    AppTheme.warning,
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Identidade'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar preview
              Center(
                child: AppAvatar(
                  name: _nameController.text.isEmpty ? '?' : _nameController.text,
                  color: _selectedColor,
                  size: 96,
                  showBorder: true,
                ),
              ),
              SizedBox(height: 32),
              
              // Nome
              AppInput(
                label: 'Nome Simbólico',
                hint: 'Digite seu nome',
                controller: _nameController,
                prefixIcon: Icons.person,
                maxLength: 20,
                onChanged: (value) {
                  setState(() {});
                },
              ),
              SizedBox(height: 24),
              
              // Seletor de cor
              Text(
                'Escolha sua cor',
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableColors.map((color) {
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 32),
              
              // Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.info.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.info),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Suas chaves criptográficas serão geradas automaticamente',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              
              // Botão criar
              AppButton(
                text: 'Criar Identidade',
                isFullWidth: true,
                isLoading: _isCreating,
                onPressed: _nameController.text.isEmpty ? null : _createIdentity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createIdentity() async {
    if (_nameController.text.isEmpty) return;
    
    setState(() {
      _isCreating = true;
    });

    try {
      // Gerar par de chaves
      final keyPair = await _cryptoManager.generateKeyPair();
      
      // Criar usuário
      final user = User(
        userId: _cryptoManager.generateUniqueId(),
        publicKey: keyPair['publicKey']!,
        displayName: _nameController.text,
        reputationScore: 50.0,
        lastSeen: DateTime.now(),
      );
      
      // Salvar no repositório
      final userRepo = repositories.users;
      await userRepo.save(user);
      
      logger.info('Identidade criada: ${user.displayName}', tag: 'Setup');
      
      // Completar
      widget.onComplete(user);
      
    } catch (e) {
      logger.error('Erro ao criar identidade', tag: 'Setup', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar identidade: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
