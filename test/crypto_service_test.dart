import 'package:flutter_test/flutter_test.dart';
import 'package:rede_p2p_offline/services/crypto/crypto_service.dart';

void main() {
  late CryptoService cryptoService;

  setUp(() {
    cryptoService = CryptoService();
  });

  group('CryptoService - Chaves Simétricas', () {
    test('Deve gerar chave simétrica válida', () async {
      final key = await cryptoService.generateSymmetricKey();
      expect(key, isNotEmpty);
      expect(key.length, greaterThan(20)); // Base64 de 32 bytes
    });

    test('Deve gerar nonce de 24 bytes', () {
      final nonce = cryptoService.generateNonce();
      expect(nonce, hasLength(24));
      expect(nonce.every((byte) => byte >= 0 && byte <= 255), isTrue);
    });
  });

  group('CryptoService - Criptografia Simétrica', () {
    test('Deve criptografar e descriptografar dados corretamente', () async {
      final plaintext = 'Mensagem secreta de teste';
      final key = await cryptoService.generateSymmetricKey();

      // Criptografar
      final encrypted = await cryptoService.encryptData(plaintext, key);
      expect(encrypted, containsPair('ciphertext', isNotEmpty));
      expect(encrypted, containsPair('nonce', isNotEmpty));
      expect(encrypted, containsPair('mac', isNotEmpty));

      // Descriptografar
      final decrypted = await cryptoService.decryptData(
        encrypted['ciphertext']!,
        key,
        encrypted['nonce']!,
        encrypted['mac']!,
      );
      expect(decrypted, equals(plaintext));
    });

    test('Deve falhar ao descriptografar com chave errada', () async {
      final plaintext = 'Mensagem secreta';
      final key1 = await cryptoService.generateSymmetricKey();
      final key2 = await cryptoService.generateSymmetricKey();

      final encrypted = await cryptoService.encryptData(plaintext, key1);

      expect(
        () => cryptoService.decryptData(
          encrypted['ciphertext']!,
          key2, // Chave errada
          encrypted['nonce']!,
          encrypted['mac']!,
        ),
        throwsException,
      );
    });
  });

  group('CryptoService - Assinaturas Ed25519', () {
    test('Deve gerar par de chaves Ed25519', () async {
      final keyPair = await cryptoService.generateKeyPair();
      expect(keyPair, containsPair('publicKey', isNotEmpty));
      expect(keyPair, containsPair('privateKey', isNotEmpty));
    });

    test('Deve assinar e verificar dados corretamente', () async {
      final data = 'Documento importante';
      final keyPair = await cryptoService.generateKeyPair();

      // Assinar
      final signature = await cryptoService.signData(
        data,
        keyPair['privateKey']!,
      );
      expect(signature, isNotEmpty);

      // Verificar
      final isValid = await cryptoService.verifySignature(
        data,
        signature,
        keyPair['publicKey']!,
      );
      expect(isValid, isTrue);
    });

    test('Deve falhar verificação com assinatura inválida', () async {
      final data = 'Documento importante';
      final keyPair = await cryptoService.generateKeyPair();
      final signature = await cryptoService.signData(
        data,
        keyPair['privateKey']!,
      );

      // Modificar dados
      final modifiedData = 'Documento modificado';
      final isValid = await cryptoService.verifySignature(
        modifiedData,
        signature,
        keyPair['publicKey']!,
      );
      expect(isValid, isFalse);
    });

    test('Deve falhar verificação com chave pública errada', () async {
      final data = 'Documento importante';
      final keyPair1 = await cryptoService.generateKeyPair();
      final keyPair2 = await cryptoService.generateKeyPair();

      final signature = await cryptoService.signData(
        data,
        keyPair1['privateKey']!,
      );

      final isValid = await cryptoService.verifySignature(
        data,
        signature,
        keyPair2['publicKey']!, // Chave errada
      );
      expect(isValid, isFalse);
    });
  });

  group('CryptoService - Hashing', () {
    test('Deve gerar hash SHA-256 consistente', () {
      final data = 'Dados para hash';
      final hash1 = cryptoService.sha256Hash(data);
      final hash2 = cryptoService.sha256Hash(data);
      expect(hash1, equals(hash2));
      expect(hash1, hasLength(64)); // SHA-256 em hex = 64 caracteres
    });

    test('Deve gerar hashes diferentes para dados diferentes', () {
      final hash1 = cryptoService.sha256Hash('Dados 1');
      final hash2 = cryptoService.sha256Hash('Dados 2');
      expect(hash1, isNot(equals(hash2)));
    });

    test('Deve gerar hash de bytes corretamente', () {
      final bytes = [1, 2, 3, 4, 5];
      final hash = cryptoService.sha256HashBytes(bytes);
      expect(hash, isNotEmpty);
      expect(hash, hasLength(64));
    });
  });

  group('CryptoService - IDs Únicos', () {
    test('Deve gerar IDs únicos', () {
      final id1 = cryptoService.generateUniqueId();
      final id2 = cryptoService.generateUniqueId();
      expect(id1, isNot(equals(id2)));
      expect(id1, hasLength(36)); // UUID v4 format
    });

    test('Deve gerar múltiplos IDs únicos', () {
      final ids = List.generate(100, (_) => cryptoService.generateUniqueId());
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(100)); // Todos devem ser únicos
    });
  });
}
