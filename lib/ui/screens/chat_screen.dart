import 'package:flutter/material.dart';
import '../../core/models/message.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/storage/database_service.dart';
import '../../core/audio/audio_stream_service.dart';
import '../widgets/stt_indicator.dart';

/// Tela de chat V1.3 - Com integração de áudio
/// Permite enviar texto e mensagens de voz
class ChatScreen extends StatefulWidget {
  final String userId;
  final String peerId;
  final String peerName;

  const ChatScreen({
    Key? key,
    required this.userId,
    required this.peerId,
    required this.peerName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  final P2PService _p2p = P2PService();
  final AudioStreamService _audioStream = AudioStreamService();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isRecording = false;
  double _peerReputation = 0.5;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToIncomingMessages();
    _loadPeerReputation();
  }

  /// Carrega mensagens do banco de dados
  Future<void> _loadMessages() async {
    try {
      final messages = await _db.getMessagesBetweenUsers(widget.userId, widget.peerId);
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

  /// Carrega reputação do peer
  Future<void> _loadPeerReputation() async {
    try {
      final peer = await _db.getUser(widget.peerId);
      if (peer != null) {
        setState(() {
          _peerReputation = peer.reputationScore;
        });
      }
    } catch (e) {
      // Mantém reputação padrão
    }
  }

  /// Escuta mensagens recebidas em tempo real
  void _listenToIncomingMessages() {
    _p2p.messageStream.listen((p2pMessage) {
      if (p2pMessage.senderId == widget.peerId && 
          p2pMessage.receiverId == widget.userId) {
        
        // Se for chunk de áudio, processar
        if (p2pMessage.type == 'audio_chunk') {
          _audioStream.handleReceivedAudioChunk(p2pMessage);
        } else {
          _loadMessages(); // Recarrega mensagens de texto
        }
      }
    });
  }

  /// Envia mensagem de texto ou anexo
  Future<void> _sendMessage({required String type, required String content}) async {
    if (content.isEmpty) return;

    try {
      // Gerar chave simétrica para criptografar a mensagem
      final symmetricKey = await _crypto.generateSymmetricKey();
      final encrypted = await _crypto.encryptData(content, symmetricKey);
      final encryptedContent = '${encrypted['ciphertext']}|${encrypted['nonce']}|${encrypted['mac']}';

      // Criar mensagem
      final message = Message(
        messageId: _crypto.generateUniqueId(),
        senderId: widget.userId,
        receiverId: widget.peerId,
        contentEncrypted: encryptedContent,
        timestamp: DateTime.now(),
        status: 'pending',
        type: type,
      );

      // Salvar no banco de dados
      await _db.insertMessage(message);

      // Enviar via P2P
      await _p2p.sendMessage(
        widget.peerId,
        P2PMessage(
          messageId: message.messageId,
          senderId: message.senderId,
          receiverId: message.receiverId,
          type: message.type,
          payload: {'content': encryptedContent},
        ),
      );

      // Limpar campo de texto se for mensagem de texto
      if (type == 'text') {
        _messageController.clear();
      }
      
      await _loadMessages();
    } catch (e) {
      _showError('Erro ao enviar mensagem: $e');
    }
  }

  /// Envia mensagem de texto
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    await _sendMessage(type: 'text', content: text);
  }

    try {
      // Gerar chave simétrica para criptografar a mensagem
      final symmetricKey = await _crypto.generateSymmetricKey();
      
      // Criptografar o conteúdo
      final encrypted = await _crypto.encryptData(text, symmetricKey);
      final encryptedContent = '${encrypted['ciphertext']}|${encrypted['nonce']}|${encrypted['mac']}';

      // Criar mensagem
      final message = Message(
        messageId: _crypto.generateUniqueId(),
        senderId: widget.userId,
        receiverId: widget.peerId,
        contentEncrypted: encryptedContent,
        timestamp: DateTime.now(),
        status: 'pending',
        type: 'text',
      );

      // Salvar no banco de dados
      await _db.insertMessage(message);

      // Enviar via P2P
      final p2pMessage = P2PMessage(
        messageId: message.messageId,
        senderId: widget.userId,
        receiverId: widget.peerId,
        type: 'text',
        payload: message.toMap(),
      );
      
      await _p2p.sendMessage(widget.peerId, p2pMessage);

      // Limpar campo de texto
      _messageController.clear();

      // Recarregar mensagens
      await _loadMessages();
    } catch (e) {
      _showError('Erro ao enviar mensagem: $e');
    }
  }

  /// Inicia gravação de áudio
  void _startRecording() {
    try {
      _audioStream.startStreaming(widget.peerId);
      setState(() {
        _isRecording = true;
      });
      _showInfo('Gravando áudio...');
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
      _showSuccess('Áudio enviado');
      
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
        receiverId: widget.peerId,
        contentEncrypted: '[Audio Message]',
        timestamp: DateTime.now(),
        status: 'delivered',
        type: 'audio',
      );

      await _db.insertMessage(message);
      await _loadMessages();
    } catch (e) {
      // Falha silenciosa - áudio já foi enviado
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

  /// Mostra mensagem de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Mostra mensagem de sucesso
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Mostra mensagem de informação
  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.peerName),
            const SizedBox(width: 8),
            STTIndicator(
              score: _peerReputation,
              size: STTIndicatorSize.tiny,
            ),
          ],
        ),
        actions: [
          // Status da conexão P2P
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Icon(
                _p2p.connectedPeers.contains(widget.peerId)
                    ? Icons.circle
                    : Icons.circle_outlined,
                color: _p2p.connectedPeers.contains(widget.peerId)
                    ? Colors.green
                    : Colors.grey,
                size: 12,
              ),
            ),
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

  /// Constrói a lista de mensagens
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma mensagem ainda',
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
    // V1.7: Status de Sincronização Multi-Dispositivo
    String syncStatusText = '';
    // Simulação: message.deviceId é o ID do dispositivo que enviou/sincronizou a mensagem
    // Assumindo que o Message model foi atualizado para incluir 'deviceId'
    // if (message.deviceId != null && message.deviceId != _p2p.currentDeviceId) {
    //   syncStatusText = 'Enviado por Dispositivo Secundário';
    // } else if (message.status == 'synced') {
    //   syncStatusText = 'Sincronizado';
    // }
    
    // Simulação para fins de demonstração V1.7
    if (isMe && message.messageId.endsWith('1')) {
      syncStatusText = 'Sincronizado';
    } else if (isMe && message.messageId.endsWith('2')) {
      syncStatusText = 'Dispositivo Secundário';
    }

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
            else if (message.type == 'file_transfer')
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: FileTransferWidget(
                  fileId: message.contentEncrypted,
                  fileName: 'Arquivo ${message.contentEncrypted.substring(0, 8)}', // Simulação
                  totalSize: 1024 * 1024 * 2, // 2MB simulados
                  isSending: isMe,
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
                // V1.7: Exibir status de sincronização
                if (syncStatusText.isNotEmpty) ...[
                  Text(
                    syncStatusText,
                    style: TextStyle(fontSize: 10, color: Colors.purple[600], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                ],
                
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

  /// Inicia o fluxo de envio de anexo (Real)
  Future<void> _sendAttachment() async {
    // Simulação de seleção de arquivo
    const fileName = 'foto_speew_2MB.png';
    const filePath = '/temp/user/foto_speew_2MB.png';
    const fileSize = 1024 * 1024 * 2; // 2MB
    
    // 1. Criar a mensagem de requisição de transferência
    final fileId = _crypto.generateUniqueId();
    final fileTransferRequest = P2PMessage(
      messageId: _crypto.generateUniqueId(),
      senderId: widget.userId,
      receiverId: widget.peerId,
      type: 'file_transfer_request',
      payload: {
        'fileId': fileId,
        'fileName': fileName,
        'fileSize': fileSize,
        'filePath': filePath,
      },
    );
    
    // 2. Enviar a requisição (o P2PService iniciará o chunking)
    await _p2p.sendMessage(widget.peerId, fileTransferRequest);
    
    // 3. Criar a mensagem de placeholder no chat (para exibir o progresso)
    final message = Message(
      messageId: fileTransferRequest.messageId,
      senderId: widget.userId,
      receiverId: widget.peerId,
      contentEncrypted: fileId, // Usar o fileId como conteúdo
      timestamp: DateTime.now(),
      status: 'pending',
      type: 'file_transfer',
    );
    
    await _db.insertMessage(message);
    await _loadMessages();
    
    _showInfo('Transferência de arquivo iniciada: $fileName');
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
          
          // Botão de anexo (Real)
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: Colors.grey,
            onPressed: _sendAttachment,
          ),
          
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
