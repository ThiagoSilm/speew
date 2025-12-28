import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/user.dart';
import '../../core/models/group.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/reputation/reputation_service.dart';
import '../components/p2p_components.dart';
import '../widgets/stt_indicator.dart';
import '../widgets/sync_status_indicator.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// Dashboard principal - V1.3 focado em Usabilidade e Funcionalidade Social
/// Exibe lista de contatos/grupos e permite navegação para chat
class DashboardScreen extends StatefulWidget {
  final User currentUser;

  const DashboardScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final P2PService _p2pService = P2PService();
  final ReputationService _reputationService = ReputationService();
  final TextEditingController _searchController = TextEditingController();
  
  List<User> _allContacts = [];
  List<Map<String, dynamic>> _allGroups = [];
  List<User> _filteredContacts = [];
  List<Map<String, dynamic>> _filteredGroups = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Contatos, 1: Grupos

  @override
  void initState() {
    super.initState();
    _loadContactsAndGroups();
    _listenToP2PChanges();
    _searchController.addListener(_onSearchChanged);
  }

  /// Carrega contatos e grupos
  Future<void> _loadContactsAndGroups() async {
    setState(() => _isLoading = true);
    
    try {
      // Carregar contatos conectados da rede P2P
      final connectedPeers = _p2pService.connectedPeers;
      
      // Simular carregamento de contatos (em produção, buscar do DB)
      _allContacts = connectedPeers.map((peerId) => User(
        userId: peerId,
        username: 'Peer $peerId',
        publicKey: '',
        reputationScore: 0.5,
        createdAt: DateTime.now(),
      )).toList();
      
      // Simular carregamento de grupos (será implementado no GroupService)
      _allGroups = [
        {
          'groupId': 'group_1',
          'name': 'Grupo Geral',
          'members': 5,
          'lastMessage': 'Última mensagem...',
          'timestamp': DateTime.now(),
        },
        {
          'groupId': 'group_2',
          'name': 'Speew Devs',
          'members': 3,
          'lastMessage': 'Nova versão lançada!',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ];
      
      _filterLists(_searchController.text);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao carregar contatos: $e');
    }
  }

  /// Escuta mudanças na rede P2P
  void _listenToP2PChanges() {
    // Recarregar quando houver mudanças na rede
    _p2pService.addListener(() {
      if (mounted) {
        _loadContactsAndGroups();
      }
    });
  }

  /// Navega para tela de chat com um contato
  void _openChat(User contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userId: widget.currentUser.userId,
          peerId: contact.userId,
          peerName: contact.username,
        ),
      ),
    );
  }

  /// Navega para tela de chat de grupo
  void _openGroupChat(Map<String, dynamic> groupMap) {
    // Simulação: Converter Map para Group
    final group = Group.fromMap(groupMap);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          userId: widget.currentUser.userId,
          group: group,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        title: _searchController.text.isEmpty
            ? const Text('Speew Mesh')
            : TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Buscar contatos ou grupos...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            : TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar contatos ou grupos...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
              ),
        actions: [
          // STT Score do usuário atual
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: STTIndicator(
                score: widget.currentUser.reputationScore,
                size: STTIndicatorSize.small,
              ),
            ),
          ),
          
          // Status da rede P2P
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: P2PStatusIndicator(
                isConnected: _p2pService.isServerRunning,
                connectedPeers: _p2pService.connectedPeers.length,
              ),
            ),
          ),
          
          // Botão de busca
          IconButton(
            icon: Icon(_searchController.text.isEmpty ? Icons.search : Icons.close),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                _filterLists('');
              } else {
                // Apenas foca no campo de busca (já está no title)
              }
              setState(() {}); // Força rebuild para mudar o title
            },
          ),
          
          // Perfil
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    currentUser: widget.currentUser,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de Sincronização
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Consumer<P2PService>(
              builder: (context, p2p, child) {
                return const SyncStatusIndicator();
              },
            ),
          ),
          
          // Tabs: Contatos / Grupos
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Contatos',
                    icon: Icons.people,
                    index: 0,
                    count: _contacts.length,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Grupos',
                    icon: Icons.group,
                    index: 1,
                    count: _groups.length,
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildContactsList(_filteredContacts)
                    : _buildGroupsList(_filteredGroups),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton(
              onPressed: () {
                // TODO: Abrir tela de criação de grupo
                _showInfo('Criar novo grupo');
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Constrói botão de tab
  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int index,
    required int count,
  }) {
    final isSelected = _selectedTab == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói lista de contatos
  Widget _buildContactsList(List<User> contacts) {
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum contato conectado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Aguarde outros peers se conectarem à rede',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContactsAndGroups,
      child: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return _buildContactTile(contact);
        },
      ),
    );
  }

  /// Constrói tile de contato
  Widget _buildContactTile(User contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Text(
          contact.username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(contact.username),
      subtitle: Row(
        children: [
          STTIndicator(
            score: contact.reputationScore,
            size: STTIndicatorSize.tiny,
          ),
          const SizedBox(width: 8),
          Text(
            _reputationService.getReputationLabel(contact.reputationScore),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openChat(contact),
    );
  }

  /// Constrói lista de grupos
  Widget _buildGroupsList(List<Map<String, dynamic>> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum grupo criado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no + para criar um novo grupo',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupTile(group);
      },
    );
  }

  /// Constrói tile de grupo
  Widget _buildGroupTile(Map<String, dynamic> group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[100],
        child: Icon(Icons.group, color: Colors.green),
      ),
      title: Text(group['name']),
      subtitle: Text(
        '${group['members']} membros • ${group['lastMessage']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(group['timestamp']),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      onTap: () => _openGroupChat(group),
    );
  }

  /// Formata timestamp
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Agora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  void _onSearchChanged() {
    _filterLists(_searchController.text);
  }

  void _filterLists(String query) {
    final lowerCaseQuery = query.toLowerCase();
    
    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        return contact.username.toLowerCase().contains(lowerCaseQuery) ||
               contact.userId.toLowerCase().contains(lowerCaseQuery);
      }).toList();
      
      _filteredGroups = _allGroups.where((group) {
        return group['name'].toLowerCase().contains(lowerCaseQuery) ||
               group['groupId'].toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }

  @override
  void dispose() {
    _p2pService.removeListener(() {});
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
