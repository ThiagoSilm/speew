# Arquitetura Técnica - Speew

Este documento descreve em detalhes a arquitetura técnica do aplicativo **Speew com Speew Trust Tokens (STT)**.

---

## 📐 Visão Geral da Arquitetura

O aplicativo segue uma arquitetura em camadas com separação clara de responsabilidades:

```
┌─────────────────────────────────────────┐
│         UI Layer (Screens/Widgets)       │
├─────────────────────────────────────────┤
│       Service Layer (Business Logic)     │
│  ┌──────────┬──────────┬──────────────┐ │
│  │ Network  │  Crypto  │   Storage    │ │
│  │ Wallet   │ Reputation│             │ │
│  └──────────┴──────────┴──────────────┘ │
├─────────────────────────────────────────┤
│         Data Layer (Models)              │
├─────────────────────────────────────────┤
│      Platform Layer (Android/iOS)        │
└─────────────────────────────────────────┘
```

---

## 🔐 Módulo de Criptografia

### Algoritmos Utilizados

#### 1. XChaCha20-Poly1305 (Criptografia Simétrica)

**Uso**: Criptografar mensagens e blocos de arquivo

**Características**:
- Nonce de 24 bytes (maior que ChaCha20 padrão)
- Autenticação integrada (AEAD)
- Alta performance em dispositivos móveis
- Resistente a ataques de timing

**Implementação**:
```dart
// Gerar chave simétrica
final symmetricKey = await generateSymmetricKey();

// Criptografar dados
final encrypted = await encryptData(plaintext, symmetricKey);
// Retorna: { ciphertext, nonce, mac }

// Descriptografar dados
final plaintext = await decryptData(
  ciphertext, nonce, mac, symmetricKey
);
```

#### 2. Ed25519 (Assinatura Digital)

**Uso**: Assinar transações de moeda simbólica

**Características**:
- Curva elíptica de alta segurança
- Assinaturas de 64 bytes
- Verificação rápida
- Resistente a ataques de canal lateral

**Implementação**:
```dart
// Gerar par de chaves
final keyPair = await generateKeyPair();
// Retorna: { publicKey, privateKey }

// Assinar dados
final signature = await signData(data, privateKey);

// Verificar assinatura
final isValid = await verifySignature(data, signature, publicKey);
```

#### 3. SHA-256 (Hashing)

**Uso**: Checksums de blocos de arquivo

**Características**:
- Hash de 256 bits
- Resistente a colisões
- Padrão da indústria

**Implementação**:
```dart
// Calcular hash
final checksum = sha256Hash(data);
```

### Noise Protocol (Simplificado)

**Uso**: Troca de chaves entre peers

**Fluxo**:
1. Peer A gera chave efêmera
2. Peer B gera chave efêmera
3. Troca de chaves públicas
4. Derivação de chave de sessão via ECDH
5. Autenticação mútua

**Nota**: A implementação atual é simplificada. Para produção, usar biblioteca completa do Noise Protocol Framework.

---

## 📡 Módulo de Rede P2P

### Componentes

#### 1. P2PService

**Responsabilidades**:
- Descoberta de dispositivos próximos
- Gerenciamento de conexões
- Envio e recepção de mensagens
- Propagação mesh

**Estados**:
- `isServerRunning`: Servidor P2P ativo
- `isDiscovering`: Descoberta em andamento
- `connectedPeers`: Lista de peers conectados
- `discoveredPeers`: Lista de peers descobertos

**Fluxo de Conexão**:
```
1. startServer() → Torna dispositivo visível
2. startDiscovery() → Busca dispositivos próximos
3. connectToPeer() → Estabelece conexão
4. Noise Handshake → Troca de chaves
5. sendMessage() → Comunicação segura
```

#### 2. Wi-Fi Direct

**Tecnologia**: IEEE 802.11 (Wi-Fi Peer-to-Peer)

**Características**:
- Alcance: até 200 metros
- Velocidade: até 250 Mbps
- Sem necessidade de roteador
- Um dispositivo atua como Group Owner

**Implementação**:
- Plugin: `nearby_connections` (Android)
- Descoberta via Service Discovery
- Conexão direta entre dispositivos

#### 3. Bluetooth Mesh

**Tecnologia**: Bluetooth Low Energy (BLE) Mesh

**Características**:
- Alcance: até 100 metros por hop
- Consumo baixo de energia
- Topologia mesh (muitos-para-muitos)
- Flooding para propagação

**Implementação**:
- Plugin: `flutter_blue_plus`
- Advertising para descoberta
- GATT para comunicação

### Store-and-Forward

**Conceito**: Mensagens são armazenadas localmente e encaminhadas quando o destinatário estiver disponível.

**Fluxo**:
```
Sender → Peer1 → Peer2 → ... → Receiver
         ↓        ↓              ↓
      Storage  Storage       Storage
```

**Implementação**:
1. Mensagem é salva no banco de dados local
2. Tentativa de envio direto ao destinatário
3. Se falhar, propagar para peers conectados
4. Cada peer armazena e tenta reenviar
5. Hop count evita loops infinitos

**Controle de Loops**:
```dart
class P2PMessage {
  final int hopCount;
  
  P2PMessage incrementHop() {
    return P2PMessage(
      // ... outros campos
      hopCount: hopCount + 1,
    );
  }
}

// Limitar hops
if (message.hopCount < MAX_HOPS) {
  propagateMessage(message.incrementHop());
}
```

---

## 📁 Módulo de Transferência de Arquivos

### Fragmentação

**Tamanhos de Bloco**:
- Mínimo: 32 KB
- Padrão: 64 KB
- Máximo: 128 KB

**Processo de Fragmentação**:
```
1. Ler arquivo completo
2. Dividir em blocos de N KB
3. Para cada bloco:
   a. Gerar chave única
   b. Criptografar com XChaCha20-Poly1305
   c. Calcular checksum SHA-256
   d. Salvar no banco de dados
4. Enviar blocos via P2P
```

**Estrutura do Bloco**:
```dart
FileBlock {
  blockId: UUID
  fileId: UUID
  blockIndex: int (0-based)
  totalBlocks: int
  dataEncrypted: base64
  checksum: SHA-256 hash
}
```

### Reagrupamento

**Processo**:
```
1. Receber blocos via P2P
2. Salvar no banco de dados
3. Verificar checksum de cada bloco
4. Quando todos os blocos chegarem:
   a. Ordenar por blockIndex
   b. Descriptografar cada bloco
   c. Concatenar dados
   d. Escrever arquivo no disco
```

### Retransmissão

**Detecção de Blocos Faltantes**:
```dart
Future<List<int>> getMissingBlocks(String fileId) async {
  final blocks = await db.getFileBlocks(fileId);
  final totalBlocks = blocks.first.totalBlocks;
  final receivedIndices = blocks.map((b) => b.blockIndex).toSet();
  
  final missing = <int>[];
  for (int i = 0; i < totalBlocks; i++) {
    if (!receivedIndices.contains(i)) {
      missing.add(i);
    }
  }
  return missing;
}
```

**Solicitação de Retransmissão**:
```dart
// Enviar mensagem de controle
final message = P2PMessage(
  type: 'request_blocks',
  payload: {
    'fileId': fileId,
    'missingBlocks': [2, 5, 7],
  },
);
```

---

## 💰 Módulo de Speew Trust Tokens (STT)

### Características da Moeda

- **Infinita**: Não há limite de emissão
- **Voluntária**: Transações dependem de aceite
- **Sem valor real**: Não pode ser convertida em dinheiro
- **Descentralizada**: Sincronização P2P

### Ciclo de Vida de uma Transação

```
1. Criação
   └─> sendCoins(senderId, receiverId, amount)
       └─> Gerar transactionId
       └─> Assinar com chave privada do remetente
       └─> Status: pending
       └─> Salvar no banco de dados local

2. Envio
   └─> Enviar via P2P para destinatário
       └─> Se offline, usar store-and-forward

3. Recepção
   └─> Destinatário recebe transação
       └─> Salvar em pendingTransactions
       └─> Notificar usuário

4. Decisão
   └─> Aceitar
       └─> Assinar com chave privada do destinatário
       └─> Status: accepted
       └─> Atualizar saldo
       └─> Notificar remetente
   └─> Rejeitar
       └─> Status: rejected
       └─> Notificar remetente
```

### Cálculo de Saldo

```dart
Future<double> getUserBalance(String userId) async {
  // Moedas recebidas e aceitas
  final received = await db.rawQuery(
    'SELECT SUM(amount) FROM coin_transactions 
     WHERE receiver_id = ? AND status = ?',
    [userId, 'accepted']
  );
  
  // Moedas enviadas e aceitas
  final sent = await db.rawQuery(
    'SELECT SUM(amount) FROM coin_transactions 
     WHERE sender_id = ? AND status = ?',
    [userId, 'accepted']
  );
  
  return received - sent;
}
```

### Segurança

**Assinatura Dupla**:
1. Remetente assina ao criar transação
2. Destinatário assina ao aceitar
3. Ambas as assinaturas são verificáveis

**Dados Assinados**:
```
Remetente: transactionId|senderId|receiverId|amount|timestamp
Destinatário: transactionId|accepted|timestamp
```

---

## ⭐ Módulo de Reputação

### Fórmula de Cálculo

```
score = transações aceitas / total de interações

Onde:
- transações aceitas: status = 'accepted'
- total de interações: status = 'accepted' OR 'rejected'
- transações pendentes não contam
```

### Classificação

| Score | Label | Cor |
|-------|-------|-----|
| 0.90 - 1.00 | Excelente | Verde |
| 0.75 - 0.89 | Muito Boa | Verde |
| 0.60 - 0.74 | Boa | Verde |
| 0.40 - 0.59 | Regular | Amarelo |
| 0.25 - 0.39 | Baixa | Vermelho |
| 0.00 - 0.24 | Muito Baixa | Vermelho |

### Priorização na Mesh

**Conceito**: Usuários com alta reputação têm prioridade no roteamento de mensagens.

**Implementação**:
```dart
Future<int> getMeshPriority(String userId) async {
  final reputation = await getReputation(userId);
  return (reputation * 10).round(); // 0-10
}

// Ao propagar mensagem
final peers = await getSortedPeersByReputation();
for (final peer in peers) {
  if (await shouldPrioritize(peer.userId)) {
    await sendMessage(peer.peerId, message);
  }
}
```

### Sugestão de Ação

**Sistema de Recomendação**:
```dart
Future<String> suggestTransactionAction(String senderId) async {
  final reputation = await getReputation(senderId);
  
  if (reputation >= 0.8) return 'accept';
  if (reputation >= 0.6) return 'accept';
  if (reputation >= 0.4) return 'review';
  return 'reject';
}
```

---

## 💾 Módulo de Armazenamento

### Banco de Dados SQLite

**Tabelas**:
1. `users` - Usuários da rede
2. `messages` - Mensagens trocadas
3. `files` - Metadados de arquivos
4. `file_blocks` - Blocos de arquivo
5. `coin_transactions` - Transações de moeda

**Índices**:
```sql
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_status ON messages(status);
CREATE INDEX idx_file_blocks_file ON file_blocks(file_id);
CREATE INDEX idx_transactions_sender ON coin_transactions(sender_id);
CREATE INDEX idx_transactions_receiver ON coin_transactions(receiver_id);
CREATE INDEX idx_transactions_status ON coin_transactions(status);
```

### Padrão de Acesso

**Singleton**:
```dart
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
}
```

---

## 🔄 Fluxos de Dados Principais

### 1. Envio de Mensagem

```
User Input
  ↓
UI (ChatScreen)
  ↓
CryptoService.encryptData()
  ↓
DatabaseService.insertMessage()
  ↓
P2PService.sendMessage()
  ↓
[Network] → Peer
```

### 2. Recepção de Mensagem

```
[Network] ← Peer
  ↓
P2PService.messageStream
  ↓
CryptoService.decryptData()
  ↓
DatabaseService.insertMessage()
  ↓
UI Update (ChatScreen)
```

### 3. Transferência de Arquivo

```
File Selection
  ↓
FileTransferService.fragmentFile()
  ↓
For each block:
  ├─> CryptoService.encryptBytes()
  ├─> CryptoService.sha256HashBytes()
  └─> DatabaseService.insertFileBlock()
  ↓
P2PService.sendMessage() for each block
  ↓
[Network] → Peer
```

### 4. Transação de Moeda

```
User Input (amount)
  ↓
WalletService.sendCoins()
  ↓
CryptoService.signData()
  ↓
DatabaseService.insertTransaction()
  ↓
P2PService.sendMessage()
  ↓
[Network] → Receiver
  ↓
WalletService.receiveTransaction()
  ↓
UI (WalletScreen) - Pending
  ↓
User Decision (accept/reject)
  ↓
WalletService.acceptTransaction()
  ↓
CryptoService.signData()
  ↓
DatabaseService.updateTransactionStatus()
  ↓
ReputationService.updateReputation()
```

---

## 🧪 Considerações de Produção

### Segurança

1. **Armazenamento de Chaves**
   - Usar `flutter_secure_storage`
   - Keychain (iOS) / Keystore (Android)
   - Nunca armazenar chaves em texto plano

2. **Validação de Entrada**
   - Sanitizar todos os inputs do usuário
   - Validar tamanhos de mensagens/arquivos
   - Limitar hop count para evitar loops

3. **Proteção contra Ataques**
   - Rate limiting de mensagens
   - Blacklist de peers maliciosos
   - Verificação de assinaturas em todas as transações

### Performance

1. **Otimização de Banco de Dados**
   - Usar índices apropriados
   - Limpar mensagens antigas periodicamente
   - Usar transações para operações em lote

2. **Gerenciamento de Memória**
   - Limitar tamanho de cache
   - Liberar recursos não utilizados
   - Usar streams para dados grandes

3. **Rede**
   - Comprimir dados antes de enviar
   - Usar batching para múltiplas mensagens
   - Implementar retry com backoff exponencial

### Escalabilidade

1. **Limitações**
   - Máximo de peers conectados: 10-20
   - Tamanho máximo de arquivo: 100 MB
   - Máximo de hops: 5-7

2. **Otimizações**
   - Priorizar peers por reputação
   - Descartar mensagens antigas
   - Implementar garbage collection

---

## 📚 Referências Técnicas

- **XChaCha20-Poly1305**: [RFC 8439](https://tools.ietf.org/html/rfc8439)
- **Ed25519**: [RFC 8032](https://tools.ietf.org/html/rfc8032)
- **Noise Protocol**: [noiseprotocol.org](https://noiseprotocol.org/)
- **Wi-Fi Direct**: [Wi-Fi Alliance](https://www.wi-fi.org/discover-wi-fi/wi-fi-direct)
- **Bluetooth Mesh**: [Bluetooth SIG](https://www.bluetooth.com/specifications/mesh-specifications/)

---

**Documento de Arquitetura Técnica v1.0**
