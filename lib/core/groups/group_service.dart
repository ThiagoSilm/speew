import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../storage/database_service.dart';
import '../crypto/crypto_service.dart';
import '../p2p/p2p_service.dart';
import '../utils/logger_service.dart';

/// Serviço de gerenciamento de grupos - MVP V1.3
/// Permite criação de grupos locais e associação de membros
class GroupService extends ChangeNotifier {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  final P2PService _p2p = P2PService();

  /// Cache de grupos
  final Map<String, Group> _groupsCache = {};
  
  /// Lista de grupos do usuário atual
  List<Group> get userGroups => _groupsCache.values.toList();

  // ==================== CRIAÇÃO DE GRUPOS ====================

  /// Cria um novo grupo
  Future<Group?> createGroup({
    required String name,
    required String description,
    required String creatorId,
    required List<String> initialMemberIds,
  }) async {
    try {
      // Gerar ID único para o grupo
      final groupId = _crypto.generateUniqueId();
      
      // Adicionar criador aos membros
      final memberIds = {...initialMemberIds, creatorId}.toList();
      
      // Criar grupo
      final group = Group(
        groupId: groupId,
        name: name,
        description: description,
        memberIds: memberIds,
        creatorId: creatorId,
        createdAt: DateTime.now(),
      );

      // Salvar no banco de dados
      await _db.insertGroup(group);
      
      // Adicionar ao cache
      _groupsCache[groupId] = group;
      
      // Notificar membros via P2P
      await _notifyGroupCreation(group);
      
      notifyListeners();
      logger.info('Grupo criado: $name (${memberIds.length} membros)', tag: 'GroupService');
      
      return group;
    } catch (e) {
      logger.error('Erro ao criar grupo: $e', tag: 'GroupService');
      return null;
    }
  }

  /// Notifica membros sobre criação do grupo
  Future<void> _notifyGroupCreation(Group group) async {
    for (final memberId in group.memberIds) {
      if (memberId == group.creatorId) continue; // Não notificar criador
      
      try {
        final message = P2PMessage(
          messageId: _crypto.generateUniqueId(),
          senderId: group.creatorId,
          receiverId: memberId,
          type: 'group_invite',
          payload: {
            'groupId': group.groupId,
            'groupName': group.name,
            'groupData': group.toMap(),
          },
        );
        
        await _p2p.sendMessage(memberId, message);
      } catch (e) {
        logger.warn('Falha ao notificar membro $memberId: $e', tag: 'GroupService');
      }
    }
  }

  // ==================== GERENCIAMENTO DE MEMBROS ====================

  /// Adiciona um membro ao grupo
  Future<bool> addMember({
    required String groupId,
    required String memberId,
    required String requesterId,
  }) async {
    try {
      final group = await getGroup(groupId);
      if (group == null) {
        logger.warn('Grupo não encontrado: $groupId', tag: 'GroupService');
        return false;
      }

      // Verificar se o requisitante é o criador
      if (!group.isCreator(requesterId)) {
        logger.warn('Apenas o criador pode adicionar membros', tag: 'GroupService');
        return false;
      }

      // Verificar se já é membro
      if (group.isMember(memberId)) {
        logger.warn('Usuário já é membro do grupo', tag: 'GroupService');
        return false;
      }

      // Adicionar membro
      final updatedGroup = group.copyWith(
        memberIds: [...group.memberIds, memberId],
      );

      // Atualizar no banco
      await _db.updateGroup(updatedGroup);
      
      // Atualizar cache
      _groupsCache[groupId] = updatedGroup;
      
      // Notificar novo membro
      await _notifyMemberAdded(updatedGroup, memberId);
      
      notifyListeners();
      logger.info('Membro adicionado ao grupo $groupId', tag: 'GroupService');
      
      return true;
    } catch (e) {
      logger.error('Erro ao adicionar membro: $e', tag: 'GroupService');
      return false;
    }
  }

  /// Notifica membro adicionado
  Future<void> _notifyMemberAdded(Group group, String memberId) async {
    try {
      final message = P2PMessage(
        messageId: _crypto.generateUniqueId(),
        senderId: group.creatorId,
        receiverId: memberId,
        type: 'group_member_added',
        payload: {
          'groupId': group.groupId,
          'groupName': group.name,
          'groupData': group.toMap(),
        },
      );
      
      await _p2p.sendMessage(memberId, message);
    } catch (e) {
      logger.warn('Falha ao notificar membro adicionado: $e', tag: 'GroupService');
    }
  }

  /// Remove um membro do grupo
  Future<bool> removeMember({
    required String groupId,
    required String memberId,
    required String requesterId,
  }) async {
    try {
      final group = await getGroup(groupId);
      if (group == null) return false;

      // Verificar se o requisitante é o criador
      if (!group.isCreator(requesterId)) {
        logger.warn('Apenas o criador pode remover membros', tag: 'GroupService');
        return false;
      }

      // Não permitir remover o criador
      if (memberId == group.creatorId) {
        logger.warn('Não é possível remover o criador do grupo', tag: 'GroupService');
        return false;
      }

      // Remover membro
      final updatedGroup = group.copyWith(
        memberIds: group.memberIds.where((id) => id != memberId).toList(),
      );

      // Atualizar no banco
      await _db.updateGroup(updatedGroup);
      
      // Atualizar cache
      _groupsCache[groupId] = updatedGroup;
      
      notifyListeners();
      logger.info('Membro removido do grupo $groupId', tag: 'GroupService');
      
      return true;
    } catch (e) {
      logger.error('Erro ao remover membro: $e', tag: 'GroupService');
      return false;
    }
  }

  // ==================== CONSULTAS ====================

  /// Obtém um grupo pelo ID
  Future<Group?> getGroup(String groupId) async {
    try {
      // Verificar cache
      if (_groupsCache.containsKey(groupId)) {
        return _groupsCache[groupId];
      }

      // Buscar no banco
      final group = await _db.getGroup(groupId);
      
      if (group != null) {
        _groupsCache[groupId] = group;
      }
      
      return group;
    } catch (e) {
      logger.error('Erro ao obter grupo: $e', tag: 'GroupService');
      return null;
    }
  }

  /// Obtém todos os grupos de um usuário
  Future<List<Group>> getUserGroups(String userId) async {
    try {
      final groups = await _db.getUserGroups(userId);
      
      // Atualizar cache
      for (final group in groups) {
        _groupsCache[group.groupId] = group;
      }
      
      return groups;
    } catch (e) {
      logger.error('Erro ao obter grupos do usuário: $e', tag: 'GroupService');
      return [];
    }
  }

  /// Obtém membros de um grupo
  Future<List<String>> getGroupMembers(String groupId) async {
    try {
      final group = await getGroup(groupId);
      return group?.memberIds ?? [];
    } catch (e) {
      logger.error('Erro ao obter membros do grupo: $e', tag: 'GroupService');
      return [];
    }
  }

  // ==================== MENSAGENS DE GRUPO ====================

  /// Envia mensagem para um grupo
  Future<bool> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
    required String type,
  }) async {
    try {
      final group = await getGroup(groupId);
      if (group == null) return false;

      // Verificar se o remetente é membro
      if (!group.isMember(senderId)) {
        logger.warn('Apenas membros podem enviar mensagens', tag: 'GroupService');
        return false;
      }

      // Enviar mensagem para todos os membros (exceto remetente)
      for (final memberId in group.memberIds) {
        if (memberId == senderId) continue;
        
        try {
          final message = P2PMessage(
            messageId: _crypto.generateUniqueId(),
            senderId: senderId,
            receiverId: memberId,
            type: 'group_message',
            payload: {
              'groupId': groupId,
              'groupName': group.name,
              'content': content,
              'messageType': type,
            },
          );
          
          await _p2p.sendMessage(memberId, message);
        } catch (e) {
          logger.warn('Falha ao enviar para membro $memberId: $e', tag: 'GroupService');
        }
      }
      
      logger.info('Mensagem enviada para grupo $groupId', tag: 'GroupService');
      return true;
    } catch (e) {
      logger.error('Erro ao enviar mensagem de grupo: $e', tag: 'GroupService');
      return false;
    }
  }

  // ==================== LIMPEZA ====================

  /// Limpa o cache de grupos
  void clearCache() {
    _groupsCache.clear();
    notifyListeners();
    logger.info('Cache de grupos limpo', tag: 'GroupService');
  }

  /// Recarrega todos os grupos de um usuário
  Future<void> reloadUserGroups(String userId) async {
    clearCache();
    await getUserGroups(userId);
    notifyListeners();
  }
}
