import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../themes/app_theme.dart';
import '../components/p2p_components.dart';
import '../components/app_button.dart';

/// Tela de perfil e configurações
class ProfileScreen extends StatelessWidget {
  final User currentUser;

  const ProfileScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Header com avatar
        AppCard(
          child: Column(
            children: [
              AppAvatar(
                name: currentUser.displayName,
                size: 80,
                showBorder: true,
              ),
              SizedBox(height: 16),
              Text(
                currentUser.displayName,
                style: theme.textTheme.displaySmall,
              ),
              SizedBox(height: 8),
              Text(
                'ID: ${currentUser.userId.substring(0, 8)}...',
                style: theme.textTheme.bodySmall,
              ),
              SizedBox(height: 16),
              // Reputação
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: AppTheme.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Reputação: ${currentUser.reputationScore.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 24),
        Text(
          'Configurações',
          style: theme.textTheme.titleLarge,
        ),
        SizedBox(height: 12),
        
        // Opções
        _buildOption(
          context,
          'Editar Perfil',
          Icons.edit,
          () {
            // TODO: Implementar edição
          },
        ),
        
        _buildOption(
          context,
          'Rotação de Chaves',
          Icons.key,
          () {
            // TODO: Implementar rotação
          },
        ),
        
        _buildOption(
          context,
          'Exportar Identidade',
          Icons.file_download,
          () {
            // TODO: Implementar exportação
          },
        ),
        
        _buildOption(
          context,
          'Tema',
          Icons.palette,
          () {
            // TODO: Implementar troca de tema
          },
        ),
        
        AppDivider(),
        
        _buildOption(
          context,
          'Staking Simbólico',
          Icons.lock_open,
          () {
            // TODO: Navegar para StakingScreen
          },
        ),
        
        _buildOption(
          context,
          'Marketplace P2P',
          Icons.shopping_cart,
          () {
            // TODO: Navegar para MarketplaceScreen
          },
        ),
        
        _buildOption(
          context,
          'Leilões Simbólicos',
          Icons.gavel,
          () {
            // TODO: Navegar para AuctionScreen
          },
        ),
        
        SizedBox(height: 24),
        
        // Sobre
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sobre',
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Text(
                'Speew v0.6.0',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Comunicação descentralizada e privada',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryDark),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.textSecondaryDark),
        ],
      ),
    );
  }
}
