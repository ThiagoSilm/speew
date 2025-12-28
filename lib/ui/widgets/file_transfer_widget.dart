import 'package:flutter/material.dart';

/// Widget para exibir o progresso de transferência de arquivos (chunks)
class FileTransferWidget extends StatefulWidget {
  final String fileId;
  final String fileName;
  final int totalSize;
  final bool isSending;

  const FileTransferWidget({
    Key? key,
    required this.fileId,
    required this.fileName,
    required this.totalSize,
    required this.isSending,
  }) : super(key: key);

  @override
  State<FileTransferWidget> createState() => _FileTransferWidgetState();
}

class _FileTransferWidgetState extends State<FileTransferWidget> {
  // Simulação de estado de transferência
  double _progress = 0.0; // 0.0 a 1.0
  int _transferredBytes = 0;
  bool _isTransferring = true;

  @override
  void initState() {
    super.initState();
    // Simulação: Iniciar transferência
    _simulateTransfer();
  }

  /// Simula o progresso da transferência de chunks
  void _simulateTransfer() async {
    const int chunkSize = 1024 * 50; // 50KB
    final int totalChunks = (widget.totalSize / chunkSize).ceil();
    
    for (int i = 0; i <= totalChunks; i++) {
      if (!mounted || !_isTransferring) return;
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      setState(() {
        _transferredBytes = (i * chunkSize).clamp(0, widget.totalSize);
        _progress = _transferredBytes / widget.totalSize;
      });
      
      if (_progress >= 1.0) {
        setState(() {
          _isTransferring = false;
        });
        break;
      }
    }
  }

  /// Formata o tamanho em bytes para KB/MB
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSending ? Colors.blue : Colors.green;
    final icon = widget.isSending ? Icons.upload_file : Icons.download_for_offline;
    final statusText = _isTransferring 
        ? (widget.isSending ? 'Enviando...' : 'Recebendo...')
        : (widget.isSending ? 'Enviado' : 'Recebido');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Barra de progresso
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          
          const SizedBox(height: 4),
          
          // Detalhes do progresso
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '${_formatBytes(_transferredBytes)} / ${_formatBytes(widget.totalSize)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
