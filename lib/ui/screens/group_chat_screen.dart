import 'package:flutter/material.dart';
import '../../core/models/group.dart';
import '../../core/models/message.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/storage/database_service.dart';
import '../../core/groups/group_service.dart';
import '../../core/audio/audio_stream_service.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/stt_indicator.dart';

/// Tela de chat para conversas em grupo
class GroupChatScreen extends StatefulWidget {
  final String userId;
  final Group group;

  const GroupChatScreen({
    Key? key,
    required this.userId,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  final P2PService _p2p = P2PService();
  final GroupService _groupService = GroupService();
  final AudioStreamService _audioStream = AudioStreamService();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToIncomingMessages();
  }

  /// Carrega mensagens do banco de dados
  Future<void> _loadMessages() async {
    try {
      // Simulação: Carregar mensagens do grupo
      final messages = await _db.getMessagesByReceiverId(widget.group.groupId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      _showError('Erro ao carregar mensagens: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Escuta mensagens recebidas em tempo real
  void _listenToIncomingMessages() {
    _p2p.messageStream.listen((p2pMessage) {
      // Se a mensagem for para este grupo
      if (p2pMessage.receiverId == widget.group.groupId) {
        if (p2pMessage.type == 'audio_chunk') {
          _audioStream.handleReceivedAudioChunk(p2pMessage);
        } else {
          _loadMessages();
        }
      }
    });
  }

  /// Envia mensagem de texto para o grupo
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Gerar chave simétrica para criptografar a mensagem
      final symmetricKey = await _crypto.generateSymmetricKey();
      final encrypted = await _crypto.encryptData(text, symmetricKey);
      final encryptedContent = '${encrypted['ciphertext']}|${encrypted['nonce']}|${encrypted['mac']}';

      // Criar mensagem (ReceiverId é o GroupId)
      final message = Message(
        messageId: _crypto.generateUniqueId(),
        senderId: widget.userId,
        receiverId: widget.group.groupId,
        contentEncrypted: encryptedContent,
        timestamp: DateTime.now(),
        status: 'pending',
        type: 'text',
      );

      // Salvar no banco de dados
      await _db.insertMessage(message);

      // Enviar via GroupService
      await _groupService.sendGroupMessage(
        groupId: widget.group.groupId,
        senderId: widget.userId,
        content: encryptedContent,
        type: 'text',
      );

      // Limpar campo de texto
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      _showError('Erro ao enviar mensagem: $e');
    }
  }

  /// Inicia gravação de áudio
  void _startRecording() {
    try {
      // Simulação: Stream para todos os membros do grupo
      _audioStream.startStreaming(widget.group.groupId);
      setState(() {
        _isRecording = true;
      });
      _showInfo('Gravando áudio para o grupo...');
    } catch (e) {
      _showError('Erro ao iniciar gravação: $e');
    }
  }

  /// Para gravação de áudio
  void _stopRecording() {
    try {
      _audioStream.stopStreaming();
      setState(() {
        _isRecording = false;
      });
      _showSuccess('Áudio enviado para o grupo');
      
      // Criar registro de mensagem de áudio no banco
      _saveAudioMessage();
    } catch (e) {
      _showError('Erro ao parar gravação: $e');
    }
  }

  /// Salva mensagem de áudio no banco
  Future<void> _saveAudioMessage() async {
    try {
      final message = Message(
        messageId: _crypto.generateUniqueId(),
        senderId: widget.userId,
        receiverId: widget.group.groupId,
        contentEncrypted: '[Audio Message]',
        timestamp: DateTime.now(),
        status: 'delivered',
        type: 'audio',
      );

      await _db.insertMessage(message);
      await _loadMessages();
    } catch (e) {
      // Falha silenciosa
    }
  }

  /// Rola para o final da lista de mensagens
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),
          
          // Campo de entrada de mensagem
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Exibe informações do grupo (membros)
  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Membros do Grupo (${widget.group.memberIds.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.group.memberIds.length,
                  itemBuilder: (context, index) {
                    final memberId = widget.group.memberIds[index];
                    final isCreator = memberId == widget.group.creatorId;
                    final isMe = memberId == widget.userId;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(memberId.substring(0, 2).toUpperCase()),
                      ),
                      title: Text(
                        memberId + (isMe ? ' (Você)' : ''),
                        style: TextStyle(fontWeight: isCreator ? FontWeight.bold : FontWeight.normal),
                      ),
                      subtitle: Text(isCreator ? 'Criador' : 'Membro'),
                      trailing: isCreator && !isMe
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                // Simulação de remoção
                                _groupService.removeMember(
                                  groupId: widget.group.groupId,
                                  memberId: memberId,
                                  requesterId: widget.userId,
                                );
                                Navigator.pop(context);
                              },
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Constrói a lista de mensagens
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_work, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma mensagem no grupo',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Envie a primeira mensagem!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == widget.userId;
        
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  /// Constrói um balão de mensagem
  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome do remetente (apenas se não for eu)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  message.senderId, // Em produção, buscar username
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange, // Cor para diferenciar
                    fontSize: 12,
                  ),
                ),
              ),
              
            // Conteúdo da mensagem
            if (message.type == 'text')
              const Text(
                '[Mensagem criptografada]',
                style: TextStyle(fontSize: 16),
              )
            else if (message.type == 'audio')
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: AudioPlayerWidget(
                  audioFilePath: message.contentEncrypted, // Simula o caminho do arquivo
                  isMe: isMe,
                ),
              )
            else
              Text(
                '[${message.type.toUpperCase()}]',
                style: const TextStyle(fontSize: 16),
              ),
            
            const SizedBox(height: 4),
            
            // Timestamp e status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'delivered' 
                      ? Icons.done_all 
                      : Icons.done,
                    size: 16,
                    color: message.status == 'read' 
                      ? Colors.blue 
                      : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o campo de entrada de mensagem
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botão de áudio
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Campo de texto
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Digite ou segure o microfone...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Botão de enviar
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.blue,
            onPressed: _sendTextMessage,
          ),
        ],
      ),
    );
  }

  /// Formata timestamp para exibição
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioStream.dispose();
    super.dispose();
  }
}
