import 'dart:io';
import 'package:test/test.dart';

/// Teste de Sanidade de Estrutura Nativa
/// 
/// Este teste valida que a estrutura nativa do projeto Speew foi
/// corretamente refatorada, removendo todas as referências ao template
/// 'example' e configurando o applicationId/bundleIdentifier correto.
void main() {
  group('Teste de Sanidade - Estrutura Nativa', () {
    test('Android: applicationId deve ser com.speew.app', () {
      final buildGradle = File('android/app/build.gradle');
      
      expect(buildGradle.existsSync(), isTrue,
          reason: 'Arquivo build.gradle deve existir');
      
      final content = buildGradle.readAsStringSync();
      
      // Verificar applicationId correto
      expect(content.contains('applicationId "com.speew.app"'), isTrue,
          reason: 'applicationId deve ser com.speew.app');
      
      // Verificar namespace correto
      expect(content.contains('namespace "com.speew.app"'), isTrue,
          reason: 'namespace deve ser com.speew.app');
      
      // Garantir que não há referências ao template example
      expect(content.contains('com.example'), isFalse,
          reason: 'Não deve haver referências a com.example');
      
      print('✓ Android applicationId validado: com.speew.app');
    });

    test('Android: MainActivity deve estar no pacote correto', () {
      final mainActivity = File('android/app/src/main/kotlin/com/speew/app/MainActivity.kt');
      
      expect(mainActivity.existsSync(), isTrue,
          reason: 'MainActivity deve existir no caminho correto');
      
      final content = mainActivity.readAsStringSync();
      
      // Verificar package correto
      expect(content.contains('package com.speew.app'), isTrue,
          reason: 'Package deve ser com.speew.app');
      
      // Verificar que não há referências ao template example
      expect(content.contains('com.example'), isFalse,
          reason: 'Não deve haver referências a com.example');
      
      // Verificar inicialização de P2PManager
      expect(content.contains('P2PManager'), isTrue,
          reason: 'MainActivity deve inicializar P2PManager');
      
      // Verificar inicialização de EnergyManager
      expect(content.contains('EnergyManager'), isTrue,
          reason: 'MainActivity deve inicializar EnergyManager');
      
      print('✓ Android MainActivity validada no pacote com.speew.app');
    });

    test('Android: Pasta antiga com.example deve ter sido removida', () {
      final oldPackageDir = Directory('android/app/src/main/kotlin/com/example');
      
      expect(oldPackageDir.existsSync(), isFalse,
          reason: 'Pasta com.example deve ter sido removida');
      
      print('✓ Pasta antiga com.example removida com sucesso');
    });

    test('Android: AndroidManifest.xml deve conter permissões críticas', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      
      expect(manifest.existsSync(), isTrue,
          reason: 'AndroidManifest.xml deve existir');
      
      final content = manifest.readAsStringSync();
      
      // Verificar permissão BLUETOOTH_SCAN
      expect(content.contains('android.permission.BLUETOOTH_SCAN'), isTrue,
          reason: 'Deve conter permissão BLUETOOTH_SCAN');
      
      // Verificar permissão ACCESS_FINE_LOCATION
      expect(content.contains('android.permission.ACCESS_FINE_LOCATION'), isTrue,
          reason: 'Deve conter permissão ACCESS_FINE_LOCATION');
      
      // Verificar permissão BLUETOOTH_ADVERTISE
      expect(content.contains('android.permission.BLUETOOTH_ADVERTISE'), isTrue,
          reason: 'Deve conter permissão BLUETOOTH_ADVERTISE');
      
      // Verificar permissão BLUETOOTH_CONNECT
      expect(content.contains('android.permission.BLUETOOTH_CONNECT'), isTrue,
          reason: 'Deve conter permissão BLUETOOTH_CONNECT');
      
      print('✓ AndroidManifest.xml contém todas as permissões críticas');
    });

    test('iOS: Info.plist deve conter descrições de uso obrigatórias', () {
      final infoPlist = File('ios/Runner/Info.plist');
      
      expect(infoPlist.existsSync(), isTrue,
          reason: 'Info.plist deve existir');
      
      final content = infoPlist.readAsStringSync();
      
      // Verificar NSMicrophoneUsageDescription
      expect(content.contains('NSMicrophoneUsageDescription'), isTrue,
          reason: 'Deve conter NSMicrophoneUsageDescription');
      
      // Verificar NSBluetoothAlwaysUsageDescription
      expect(content.contains('NSBluetoothAlwaysUsageDescription'), isTrue,
          reason: 'Deve conter NSBluetoothAlwaysUsageDescription');
      
      // Verificar NSLocalNetworkUsageDescription
      expect(content.contains('NSLocalNetworkUsageDescription'), isTrue,
          reason: 'Deve conter NSLocalNetworkUsageDescription');
      
      // Verificar UIBackgroundModes
      expect(content.contains('UIBackgroundModes'), isTrue,
          reason: 'Deve conter UIBackgroundModes');
      
      // Verificar bluetooth-central em background modes
      expect(content.contains('bluetooth-central'), isTrue,
          reason: 'Deve conter bluetooth-central em UIBackgroundModes');
      
      print('✓ Info.plist contém todas as descrições de uso obrigatórias');
    });

    test('iOS: AppDelegate.swift deve existir e conter inicialização', () {
      final appDelegate = File('ios/Runner/AppDelegate.swift');
      
      expect(appDelegate.existsSync(), isTrue,
          reason: 'AppDelegate.swift deve existir');
      
      final content = appDelegate.readAsStringSync();
      
      // Verificar inicialização de P2PManager
      expect(content.contains('P2PManager'), isTrue,
          reason: 'AppDelegate deve inicializar P2PManager');
      
      // Verificar inicialização de EnergyManager
      expect(content.contains('EnergyManager'), isTrue,
          reason: 'AppDelegate deve inicializar EnergyManager');
      
      // Verificar método channel
      expect(content.contains('com.speew.app/native'), isTrue,
          reason: 'AppDelegate deve configurar method channel correto');
      
      print('✓ AppDelegate.swift validado com inicialização completa');
    });

    test('iOS: project.pbxproj deve conter bundleIdentifier correto', () {
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');
      
      expect(pbxproj.existsSync(), isTrue,
          reason: 'project.pbxproj deve existir');
      
      final content = pbxproj.readAsStringSync();
      
      // Verificar PRODUCT_BUNDLE_IDENTIFIER correto
      expect(content.contains('PRODUCT_BUNDLE_IDENTIFIER = com.speew.app'), isTrue,
          reason: 'PRODUCT_BUNDLE_IDENTIFIER deve ser com.speew.app');
      
      // Verificar que não há referências ao template example
      expect(content.contains('com.example'), isFalse,
          reason: 'Não deve haver referências a com.example');
      
      print('✓ iOS bundleIdentifier validado: com.speew.app');
    });

    test('Estrutura: Managers nativos devem existir', () {
      // Android
      final androidP2PManager = File('android/app/src/main/kotlin/com/speew/app/P2PManager.kt');
      final androidEnergyManager = File('android/app/src/main/kotlin/com/speew/app/EnergyManager.kt');
      
      expect(androidP2PManager.existsSync(), isTrue,
          reason: 'P2PManager.kt deve existir');
      expect(androidEnergyManager.existsSync(), isTrue,
          reason: 'EnergyManager.kt deve existir');
      
      // iOS
      final iosP2PManager = File('ios/Runner/P2PManager.swift');
      final iosEnergyManager = File('ios/Runner/EnergyManager.swift');
      
      expect(iosP2PManager.existsSync(), isTrue,
          reason: 'P2PManager.swift deve existir');
      expect(iosEnergyManager.existsSync(), isTrue,
          reason: 'EnergyManager.swift deve existir');
      
      print('✓ Todos os managers nativos existem e estão no lugar correto');
    });

    test('Consistência: Nenhuma referência a "example" deve existir', () {
      final files = [
        'android/app/build.gradle',
        'android/app/src/main/kotlin/com/speew/app/MainActivity.kt',
        'android/app/src/main/AndroidManifest.xml',
        'ios/Runner.xcodeproj/project.pbxproj',
        'ios/Runner/AppDelegate.swift',
      ];
      
      for (final filePath in files) {
        final file = File(filePath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          expect(content.toLowerCase().contains('com.example'), isFalse,
              reason: '$filePath não deve conter referências a com.example');
        }
      }
      
      print('✓ Nenhuma referência a "example" encontrada nos arquivos críticos');
    });
  });

  group('Teste de Sanidade - Integração de Serviços', () {
    test('Android: P2PManager deve ter métodos essenciais', () {
      final p2pManager = File('android/app/src/main/kotlin/com/speew/app/P2PManager.kt');
      final content = p2pManager.readAsStringSync();
      
      expect(content.contains('fun initialize()'), isTrue,
          reason: 'P2PManager deve ter método initialize()');
      expect(content.contains('fun startDiscovery()'), isTrue,
          reason: 'P2PManager deve ter método startDiscovery()');
      expect(content.contains('fun cleanup()'), isTrue,
          reason: 'P2PManager deve ter método cleanup()');
      
      print('✓ P2PManager Android contém métodos essenciais');
    });

    test('Android: EnergyManager deve ter métodos essenciais', () {
      final energyManager = File('android/app/src/main/kotlin/com/speew/app/EnergyManager.kt');
      final content = energyManager.readAsStringSync();
      
      expect(content.contains('fun initialize()'), isTrue,
          reason: 'EnergyManager deve ter método initialize()');
      expect(content.contains('fun getBatteryLevel()'), isTrue,
          reason: 'EnergyManager deve ter método getBatteryLevel()');
      expect(content.contains('fun setEnergyMode('), isTrue,
          reason: 'EnergyManager deve ter método setEnergyMode()');
      expect(content.contains('enum class EnergyMode'), isTrue,
          reason: 'EnergyManager deve ter enum EnergyMode');
      
      print('✓ EnergyManager Android contém métodos essenciais');
    });

    test('iOS: P2PManager deve ter métodos essenciais', () {
      final p2pManager = File('ios/Runner/P2PManager.swift');
      final content = p2pManager.readAsStringSync();
      
      expect(content.contains('func initialize()'), isTrue,
          reason: 'P2PManager deve ter método initialize()');
      expect(content.contains('func startDiscovery()'), isTrue,
          reason: 'P2PManager deve ter método startDiscovery()');
      expect(content.contains('func cleanup()'), isTrue,
          reason: 'P2PManager deve ter método cleanup()');
      
      print('✓ P2PManager iOS contém métodos essenciais');
    });

    test('iOS: EnergyManager deve ter métodos essenciais', () {
      final energyManager = File('ios/Runner/EnergyManager.swift');
      final content = energyManager.readAsStringSync();
      
      expect(content.contains('func initialize()'), isTrue,
          reason: 'EnergyManager deve ter método initialize()');
      expect(content.contains('func getBatteryLevel()'), isTrue,
          reason: 'EnergyManager deve ter método getBatteryLevel()');
      expect(content.contains('func setEnergyMode('), isTrue,
          reason: 'EnergyManager deve ter método setEnergyMode()');
      expect(content.contains('enum EnergyMode'), isTrue,
          reason: 'EnergyManager deve ter enum EnergyMode');
      
      print('✓ EnergyManager iOS contém métodos essenciais');
    });
  });
}
