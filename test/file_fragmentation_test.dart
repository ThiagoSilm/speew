import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_p2p_offline/services/network/file_transfer_service.dart';
import 'package:rede_p2p_offline/services/crypto/crypto_service.dart';

void main() {
  late FileTransferService fileTransferService;
  late CryptoService cryptoService;
  late Directory tempDir;

  setUp(() async {
    fileTransferService = FileTransferService();
    cryptoService = CryptoService();
    tempDir = await Directory.systemTemp.createTemp('file_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileTransferService - Fragmentação', () {
    test('Deve fragmentar arquivo pequeno corretamente', () async {
      // Criar arquivo de teste (10 KB)
      final testFile = File('${tempDir.path}/test_small.txt');
      final testData = List.generate(10 * 1024, (i) => i % 256);
      await testFile.writeAsBytes(testData);

      // Fragmentar
      final result = await fileTransferService.fragmentFile(
        testFile,
        'user123',
        blockSize: 4096, // 4 KB por bloco
      );

      expect(result, containsPair('file', isNotNull));
      expect(result, containsPair('blocks', isNotNull));

      final blocks = result['blocks'] as List;
      expect(blocks.length, greaterThan(0));
      expect(blocks.length, lessThanOrEqualTo(3)); // ~10KB / 4KB = 2-3 blocos
    });

    test('Deve calcular checksum correto para cada bloco', () async {
      final testFile = File('${tempDir.path}/test_checksum.txt');
      await testFile.writeAsString('Teste de checksum');

      final result = await fileTransferService.fragmentFile(
        testFile,
        'user123',
        blockSize: 1024,
      );

      final blocks = result['blocks'] as List;
      for (final block in blocks) {
        expect(block.checksum, isNotEmpty);
        expect(block.checksum, hasLength(64)); // SHA-256 em hex
      }
    });

    test('Deve criptografar cada bloco', () async {
      final testFile = File('${tempDir.path}/test_encrypted.txt');
      await testFile.writeAsString('Dados sensíveis');

      final result = await fileTransferService.fragmentFile(
        testFile,
        'user123',
      );

      final blocks = result['blocks'] as List;
      for (final block in blocks) {
        expect(block.dataEncrypted, isNotEmpty);
        // Dados criptografados devem ser diferentes dos originais
        expect(block.dataEncrypted, isNot(contains('Dados sensíveis')));
      }
    });

    test('Deve manter índices corretos dos blocos', () async {
      final testFile = File('${tempDir.path}/test_indices.txt');
      final testData = List.generate(20 * 1024, (i) => i % 256);
      await testFile.writeAsBytes(testData);

      final result = await fileTransferService.fragmentFile(
        testFile,
        'user123',
        blockSize: 4096,
      );

      final blocks = result['blocks'] as List;
      for (int i = 0; i < blocks.length; i++) {
        expect(blocks[i].blockIndex, equals(i));
        expect(blocks[i].totalBlocks, equals(blocks.length));
      }
    });
  });

  group('FileTransferService - Validação', () {
    test('Deve rejeitar tamanho de bloco inválido', () async {
      final testFile = File('${tempDir.path}/test_invalid.txt');
      await testFile.writeAsString('Teste');

      expect(
        () => fileTransferService.fragmentFile(
          testFile,
          'user123',
          blockSize: 100, // Muito pequeno (< 1KB)
        ),
        throwsException,
      );
    });

    test('Deve rejeitar tamanho de bloco muito grande', () async {
      final testFile = File('${tempDir.path}/test_toolarge.txt');
      await testFile.writeAsString('Teste');

      expect(
        () => fileTransferService.fragmentFile(
          testFile,
          'user123',
          blockSize: 20 * 1024 * 1024, // Muito grande (> 10MB)
        ),
        throwsException,
      );
    });
  });

  group('FileTransferService - Progresso', () {
    test('Deve atualizar progresso durante fragmentação', () async {
      final testFile = File('${tempDir.path}/test_progress.txt');
      final testData = List.generate(50 * 1024, (i) => i % 256);
      await testFile.writeAsBytes(testData);

      var progressUpdates = 0;
      fileTransferService.addListener(() {
        progressUpdates++;
      });

      await fileTransferService.fragmentFile(
        testFile,
        'user123',
        blockSize: 4096,
      );

      expect(progressUpdates, greaterThan(0));
    });
  });
}
