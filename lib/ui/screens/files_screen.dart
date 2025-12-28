import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../themes/app_theme.dart';
import '../components/p2p_components.dart';

/// Tela de arquivos P2P
class FilesScreen extends StatelessWidget {
  final User currentUser;

  const FilesScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Placeholder para arquivos
          _buildFileItem(
            context,
            'documento.pdf',
            '2.5 MB',
            0.75,
            'João Silva',
          ),
          _buildFileItem(
            context,
            'imagem.jpg',
            '1.2 MB',
            1.0,
            'Maria Santos',
          ),
          _buildFileItem(
            context,
            'video.mp4',
            '15.8 MB',
            0.35,
            'Pedro Costa',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar envio de arquivo
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildFileItem(
    BuildContext context,
    String filename,
    String size,
    double progress,
    String sender,
  ) {
    final theme = Theme.of(context);
    final isComplete = progress >= 1.0;
    
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getFileIcon(filename),
                size: 32,
                color: AppTheme.primaryDark,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$size • $sender',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isComplete)
                Icon(Icons.check_circle, color: AppTheme.success)
              else
                Icon(Icons.downloading, color: AppTheme.info),
            ],
          ),
          if (!isComplete) ...[
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.cardDark,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryDark),
            ),
            SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      case 'mp3':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
