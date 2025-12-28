import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_theme.dart';
import '../../core/identity/device_identity_service.dart';
import '../../core/mesh/message_queue_processor.dart';
import 'message_models.dart';

/// Tela Principal de Mensagens (Chat)
/// 
/// Exibe a lista de threads (peers) e a conversa ativa.
class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPeerId = Provider.of<DeviceIdentityService>(context, listen: false).peerId;
    
    return ChangeNotifierProvider(
      create: (_) => MessageStateProvider(currentPeerId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SPEEW ALPHA-1: COMMS TERMINAL'),
          centerTitle: true,
        ),
        body: const SafeArea(
          child: Row(
            children: [
              // Painel Esquerdo: Lista de Threads
              SizedBox(
                width: 300,
                child: _ThreadList(),
              ),
              // Painel Direito: Chat View
              Expanded(
                child: _ChatView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== WIDGETS INTERNOS ====================

/// Lista de Threads (Peers)
class _ThreadList extends StatelessWidget {
  const _ThreadList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = Provider.of<MessageStateProvider>(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5), width: 1)),
        color: AppTheme.backgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'ACTIVE THREADS',
              style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: state.threads.length,
              itemBuilder: (context, index) {
                final thread = state.threads[index];
                final isActive = thread.id == state.activeThread?.id;
                
                return _ThreadListItem(thread: thread, isActive: isActive);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Item Individual da Thread
class _ThreadListItem extends StatelessWidget {
  final MessageThread thread;
  final bool isActive;

  const _ThreadListItem({required this.thread, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = Provider.of<MessageStateProvider>(context, listen: false);
    final lastMessage = thread.lastMessage;
    
    Color priorityColor = AppTheme.foregroundColor;
    if (lastMessage != null) {
      final bubble = MessageBubble.fromRecord(lastMessage, state._currentPeerId);
      priorityColor = _getPriorityColor(bubble.priority);
    }

    return InkWell(
      onTap: () => state.setActiveThread(thread),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withOpacity(0.2) : AppTheme.backgroundColor,
          border: Border(
            left: BorderSide(
              color: isActive ? AppTheme.primaryColor : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  thread.displayName.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isActive ? AppTheme.primaryColor : AppTheme.foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (thread.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      thread.unreadCount.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.backgroundColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              lastMessage?.content ?? 'No messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: priorityColor),
            ),
            if (lastMessage != null)
              Text(
                '${DateTime.fromMillisecondsSinceEpoch(lastMessage.timestamp).hour}:${DateTime.fromMillisecondsSinceEpoch(lastMessage.timestamp).minute}',
                style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.infoColor.withOpacity(0.7)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Visualização do Chat (Mensagens)
class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = Provider.of<MessageStateProvider>(context);

    if (state.activeThread == null) {
      return Center(
        child: Text(
          'SELECIONE UMA THREAD PARA INICIAR COMUNICAÇÃO',
          style: theme.textTheme.headlineSmall?.copyWith(color: AppTheme.infoColor.withOpacity(0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        // Cabeçalho da Thread
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5), width: 1)),
            color: AppTheme.backgroundColor,
          ),
          child: Row(
            children: [
              Text(
                'COMMS WITH: ',
                style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.infoColor),
              ),
              Text(
                state.activeThread!.displayName.toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // Lista de Mensagens
        Expanded(
          child: ListView.builder(
            reverse: true, // Mostrar as mais recentes embaixo
            itemCount: state.currentMessages.length,
            itemBuilder: (context, index) {
              final message = state.currentMessages[index];
              return _MessageBubbleWidget(message: message);
            },
          ),
        ),
        
        // Campo de Entrada
        _MessageInput(thread: state.activeThread!),
      ],
    );
  }
}

/// Widget para exibir uma bolha de mensagem
class _MessageBubbleWidget extends StatelessWidget {
  final MessageBubble message;

  const _MessageBubbleWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelf = message.isSelf;
    final priorityColor = _getPriorityColor(message.priority);
    
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
        decoration: BoxDecoration(
          color: isSelf ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.infoColor.withOpacity(0.1),
          border: Border.all(color: priorityColor, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sinalização de Prioridade
            Text(
              'PRIORITY: ${message.priority.toString().split('.').last.toUpperCase()}',
              style: theme.textTheme.labelSmall?.copyWith(color: priorityColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            
            // Conteúdo da Mensagem
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.foregroundColor),
            ),
            const SizedBox(height: 4),
            
            // Status e Timestamp
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute}',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.infoColor.withOpacity(0.7)),
                ),
                const SizedBox(width: 8),
                Icon(
                  _getStatusIcon(message.status),
                  size: 12,
                  color: _getStatusColor(message.status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de Entrada de Mensagens com Seletor de Prioridade
class _MessageInput extends StatefulWidget {
  final MessageThread thread;

  const _MessageInput({required this.thread});

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final TextEditingController _controller = TextEditingController();
  MessagePriority _selectedPriority = MessagePriority.normal;

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final content = _controller.text.trim();
    final state = Provider.of<MessageStateProvider>(context, listen: false);

    state.sendMessage(content, _selectedPriority);
    
    _controller.clear();
    // Resetar prioridade após envio (opcional)
    setState(() {
      _selectedPriority = MessagePriority.normal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5), width: 1)),
        color: AppTheme.backgroundColor,
      ),
      child: Row(
        children: [
          // Seletor de Prioridade
          PopupMenuButton<MessagePriority>(
            initialValue: _selectedPriority,
            onSelected: (MessagePriority result) {
              setState(() {
                _selectedPriority = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MessagePriority>>[
              _buildPriorityMenuItem(MessagePriority.critical, 'CRITICAL', AppTheme.accentColor),
              _buildPriorityMenuItem(MessagePriority.high, 'HIGH', AppTheme.warningColor),
              _buildPriorityMenuItem(MessagePriority.normal, 'NORMAL', AppTheme.primaryColor),
              _buildPriorityMenuItem(MessagePriority.low, 'LOW', AppTheme.infoColor),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getPriorityColor(_selectedPriority).withOpacity(0.2),
                border: Border.all(color: _getPriorityColor(_selectedPriority), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedPriority.toString().split('.').last.toUpperCase(),
                style: theme.textTheme.bodyMedium?.copyWith(color: _getPriorityColor(_selectedPriority)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Campo de Texto
          Expanded(
            child: TextField(
              controller: _controller,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.foregroundColor),
              decoration: InputDecoration(
                hintText: 'TRANSMIT: Mensagem para ${widget.thread.displayName}...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.infoColor.withOpacity(0.5)),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          
          // Botão de Envio
          IconButton(
            icon: const Icon(Icons.send, color: AppTheme.primaryColor),
            onPressed: _sendMessage,
            tooltip: 'Transmit Message',
          ),
        ],
      ),
    );
  }
  
  PopupMenuEntry<MessagePriority> _buildPriorityMenuItem(MessagePriority priority, String label, Color color) {
    return PopupMenuItem<MessagePriority>(
      value: priority,
      child: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }
}

// ==================== FUNÇÕES DE ESTILO ====================

Color _getPriorityColor(MessagePriority priority) {
  switch (priority) {
    case MessagePriority.critical:
      return AppTheme.accentColor; // Vermelho Neon
    case MessagePriority.high:
      return AppTheme.warningColor; // Amarelo
    case MessagePriority.normal:
      return AppTheme.primaryColor; // Verde Neon
    case MessagePriority.low:
      return AppTheme.infoColor; // Azul
  }
}

IconData _getStatusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.access_time;
    case 'sent':
      return Icons.done;
    case 'delivered':
      return Icons.done_all;
    case 'failed':
      return Icons.error;
    case 'received':
      return Icons.inbox;
    default:
      return Icons.help_outline;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'pending':
      return AppTheme.warningColor;
    case 'sent':
      return AppTheme.primaryColor.withOpacity(0.7);
    case 'delivered':
      return AppTheme.primaryColor;
    case 'failed':
      return AppTheme.accentColor;
    case 'received':
      return AppTheme.infoColor;
    default:
      return AppTheme.infoColor;
  }
}
