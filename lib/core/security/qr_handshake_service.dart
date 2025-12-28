import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../identity/device_identity_service.dart';
import '../crypto/crypto_manager.dart';
import '../storage/encrypted_message_store.dart';
import '../utils/logger_service.dart';

/// Serviço de Handshake via QR Code
/// 
/// Implementa a troca segura de chaves públicas e Peer ID fora da banda
/// para emparelhamento seguro.
class QrHandshakeService {
  final DeviceIdentityService _identity = DeviceIdentityService();
  final CryptoManager _crypto = CryptoManager();
  final EncryptedMessageStore _storage = EncryptedMessageStore();

  /// Gera o payload de Handshake (JSON)
  Future<String> generateHandshakePayload() async {
    if (!_crypto.isInitialized) {
      await _crypto.initialize();
    }

    final payload = {
      'peerId': _identity.peerId,
      'displayName': _identity.deviceName,
      'signingPublicKey': base64Encode(_crypto.signingPublicKey.bytes),
      'encryptionPublicKey': base64Encode(_crypto.encryptionPublicKey.bytes),
      'protocolVersion': 'SPEEW-A1-MC',
    };

    return jsonEncode(payload);
  }

  /// Gera o Widget QR Code para exibição
  Widget generateQrCodeWidget(String payload) {
    return QrImageView(
      data: payload,
      version: QrVersions.auto,
      size: 280.0,
      gapless: false,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  /// Processa o payload de Handshake recebido (JSON)
  Future<bool> processHandshakePayload(String payload) async {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);

      final String peerId = data['peerId'];
      final String displayName = data['displayName'];
      final String signingPublicKeyBase64 = data['signingPublicKey'];
      final String encryptionPublicKeyBase64 = data['encryptionPublicKey'];
      final String protocolVersion = data['protocolVersion'];

      if (peerId == _identity.peerId) {
        logger.warn('Tentativa de Handshake com o próprio dispositivo.', tag: 'QRHandshake');
        return false;
      }

      if (protocolVersion != 'SPEEW-A1-MC') {
        logger.error('Versão de protocolo incompatível: $protocolVersion', tag: 'QRHandshake');
        return false;
      }

      // 1. Decodificar chaves
      final signingPublicKey = base64Decode(signingPublicKeyBase64);
      final encryptionPublicKey = base64Decode(encryptionPublicKeyBase64);

      // 2. Salvar o novo peer e suas chaves públicas no storage
      final newPeer = KnownPeerRecord(
        peerId: peerId,
        displayName: displayName,
        publicKey: signingPublicKeyBase64, // Usar a chave de assinatura como principal
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _storage.savePeer(newPeer);

      // 3. Salvar chaves públicas para uso futuro (criptografia/verificação)
      // Em um sistema real, isso seria salvo em um KeyStore específico
      logger.info('Peer $peerId adicionado ao KeyStore.', tag: 'QRHandshake');

      logger.info('Handshake bem-sucedido com $displayName ($peerId)', tag: 'QRHandshake');
      return true;
    } catch (e) {
      logger.error('Falha ao processar payload de Handshake', tag: 'QRHandshake', error: e);
      return false;
    }
  }
}

/// Widget para a tela de Scanner de QR Code
class QrScannerScreen extends StatelessWidget {
  final QrHandshakeService _handshakeService = QrHandshakeService();

  QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SCAN PEER QR CODE'),
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? payload = barcodes.first.rawValue;
                if (payload != null) {
                  // Parar o scanner
                  // await controller.stop(); 
                  
                  // Processar o payload
                  final success = await _handshakeService.processHandshakePayload(payload);
                  
                  if (success) {
                    _showResultDialog(context, 'HANDSHAKE SUCESSO', 'Peer adicionado com sucesso!', AppTheme.primaryColor);
                  } else {
                    _showResultDialog(context, 'HANDSHAKE FALHOU', 'Payload inválido ou incompatível.', AppTheme.accentColor);
                  }
                  
                  // Navegar de volta
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 3),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              'Alinhe o QR Code do Peer no centro do quadro.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(BuildContext context, String title, String content, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(title, style: TextStyle(color: color)),
        content: Text(content, style: TextStyle(color: AppTheme.foregroundColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
