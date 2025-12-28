# Como Compilar o App Speew

Este documento explica como compilar e executar o aplicativo **Speew** para Android e iOS.

## Pré-requisitos

### 1. Instalar o Flutter

Baixe e instale o Flutter SDK:
- **Site oficial**: https://flutter.dev/docs/get-started/install
- **Versão mínima**: Flutter 3.0.0
- **Dart SDK**: Incluído no Flutter

### 2. Configurar Ambiente de Desenvolvimento

#### Para Android:
- **Android Studio** (recomendado) ou **VS Code**
- **Android SDK** (API Level 21 ou superior)
- **Java JDK** (versão 11 ou superior)

#### Para iOS (apenas no macOS):
- **Xcode** (versão 13 ou superior)
- **CocoaPods** (gerenciador de dependências iOS)
- **Conta de desenvolvedor Apple** (para testes em dispositivos físicos)

### 3. Verificar Instalação

Execute o comando para verificar se tudo está configurado:

```bash
flutter doctor
```

Corrija quaisquer problemas indicados antes de prosseguir.

---

## Passos para Compilação

### 1. Clonar ou Baixar o Projeto

Se você recebeu o código, navegue até o diretório do projeto:

```bash
cd /caminho/para/rede_p2p_offline
```

### 2. Instalar Dependências

Execute o comando para baixar todas as dependências do projeto:

```bash
flutter pub get
```

### 3. Configurar Permissões

#### Android

Edite o arquivo `android/app/src/main/AndroidManifest.xml` e adicione as permissões necessárias:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissões de rede -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
    
    <!-- Permissões Wi-Fi Direct -->
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Permissões Bluetooth -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    
    <!-- Permissões de armazenamento -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <application>
        <!-- Configuração do app -->
    </application>
</manifest>
```

#### iOS

Edite o arquivo `ios/Runner/Info.plist` e adicione as descrições de uso:

```xml
<dict>
    <!-- Permissões de localização -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Necessário para descobrir dispositivos próximos via Wi-Fi Direct</string>
    
    <key>NSLocationAlwaysUsageDescription</key>
    <string>Necessário para manter conexões P2P em segundo plano</string>
    
    <!-- Permissões Bluetooth -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Necessário para comunicação P2P via Bluetooth Mesh</string>
    
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Necessário para atuar como servidor Bluetooth</string>
    
    <!-- Permissões de rede local -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>Necessário para comunicação P2P local</string>
    
    <key>NSBonjourServices</key>
    <array>
        <string>_p2p._tcp</string>
    </array>
</dict>
```

### 4. Compilar para Android

#### Modo Debug (para testes):

```bash
flutter build apk --debug
```

O APK será gerado em: `build/app/outputs/flutter-apk/app-debug.apk`

#### Modo Release (para distribuição):

```bash
flutter build apk --release
```

O APK será gerado em: `build/app/outputs/flutter-apk/app-release.apk`

#### App Bundle (recomendado para Google Play):

```bash
flutter build appbundle --release
```

O bundle será gerado em: `build/app/outputs/bundle/release/app-release.aab`

### 5. Compilar para iOS

#### Modo Debug:

```bash
flutter build ios --debug
```

#### Modo Release:

```bash
flutter build ios --release
```

Após a compilação, abra o projeto no Xcode:

```bash
open ios/Runner.xcworkspace
```

No Xcode:
1. Selecione seu dispositivo ou simulador
2. Configure o **Team** em **Signing & Capabilities**
3. Clique em **Product > Archive** para gerar o arquivo IPA
4. Use o **Organizer** para distribuir ou instalar

---

## Executar em Dispositivos

### Android

#### Emulador:

1. Abra o Android Studio
2. Inicie um emulador Android (AVD Manager)
3. Execute:

```bash
flutter run
```

#### Dispositivo Físico:

1. Ative o **Modo Desenvolvedor** no dispositivo Android
2. Ative a **Depuração USB**
3. Conecte o dispositivo via USB
4. Execute:

```bash
flutter run
```

### iOS

#### Simulador:

```bash
flutter run -d "iPhone 14 Pro"
```

#### Dispositivo Físico:

1. Conecte o iPhone/iPad via USB
2. Confie no computador no dispositivo
3. Execute:

```bash
flutter run
```

---

## Solução de Problemas Comuns

### Erro: "SDK location not found"

Configure a variável de ambiente `ANDROID_HOME`:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

### Erro: "CocoaPods not installed"

Instale o CocoaPods no macOS:

```bash
sudo gem install cocoapods
pod setup
```

### Erro: "Gradle build failed"

Limpe o cache do Gradle:

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Erro de permissões no iOS

Certifique-se de que todas as chaves de permissão estão no `Info.plist` e que o usuário concedeu as permissões no dispositivo.

---

## Estrutura do Projeto

```
rede_p2p_offline/
├── lib/
│   ├── models/              # Modelos de dados (User, Message, etc.)
│   ├── services/            # Serviços de negócio
│   │   ├── network/         # P2P, Mesh, Transferência de arquivos
│   │   ├── crypto/          # Criptografia e assinaturas
│   │   ├── storage/         # Banco de dados SQLite
│   │   ├── wallet/          # Moeda simbólica
│   │   └── reputation/      # Sistema de reputação
│   ├── ui/                  # Interface do usuário
│   │   ├── screens/         # Telas principais
│   │   └── widgets/         # Componentes reutilizáveis
│   └── main.dart            # Ponto de entrada
├── android/                 # Configurações Android
├── ios/                     # Configurações iOS
├── docs/                    # Documentação
└── pubspec.yaml             # Dependências do projeto
```

---

## Próximos Passos

### Implementações Pendentes

Esta versão é um **MVP funcional** com a estrutura completa. Para produção, implemente:

1. **Integração real de Wi-Fi Direct**
   - Usar plugin `nearby_connections`
   - Implementar descoberta e conexão real

2. **Integração real de Bluetooth Mesh**
   - Usar plugin `flutter_blue_plus`
   - Implementar mesh networking

3. **Noise Protocol completo**
   - Usar biblioteca especializada
   - Implementar handshake completo

4. **Armazenamento seguro de chaves**
   - Usar `flutter_secure_storage`
   - Proteger chaves privadas

5. **Seleção de arquivos**
   - Usar `file_picker`
   - Implementar upload/download

6. **Notificações locais**
   - Usar `flutter_local_notifications`
   - Notificar mensagens recebidas

---

## Suporte

Para dúvidas ou problemas:
- Consulte a documentação do Flutter: https://flutter.dev/docs
- Verifique os logs com: `flutter logs`
- Use o modo verbose: `flutter run -v`

---

**Desenvolvido com Flutter 🚀**
