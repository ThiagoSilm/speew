# 🛰️ Speew

![Licença](https://img.shields.io/github/license/Speew/speew)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Versão](https://img.shields.io/badge/version-2.0.0-blue)

**Speew** é uma **Plataforma de Infraestrutura de Comunicação Tática (PICT)** descentralizada e 100% offline. Projetada para operação em ambientes de alto risco, ela garante comunicação anônima, efêmera e resistente à censura. Desenvolvido em Flutter, o sistema permite que nós se comuniquem sem depender de infraestrutura de internet, utilizando Wi-Fi Direct e Bluetooth Mesh. Speew não é um "app de mensagens", mas uma arma de infraestrutura de sobrevivência.

> **Missão:** Ser a principal ferramenta de comunicação na era da vigilância, garantindo privacidade e liberdade de expressão mesmo em ambientes totalmente desconectados.

---

## ✨ Principais Características

- **🌐 100% Offline:** Comunicação via Wi-Fi Direct e Bluetooth Mesh (Store-and-forward).
- **🚀 Mesh Turbo:** Motor de roteamento próprio com Multi-Path e Auto-Healing, eliminando gargalos de redes ad-hoc.
- **🛡️ Privacidade Ultra-Stealth:** Zero persistência de dados nos nós de relay.
- **🔐 Segurança de Nível Militar:** Criptografia de ponta a ponta com **AES-GCM** e **Perfect Forward Secrecy (PFS)** para garantir que chaves de sessão comprometidas não afetem comunicações passadas.
- **👻 Stealth Mode:** Ofuscação de tráfego com ****Padding** (Traffic Padding)** e **Decoy Traffic** para dificultar a análise de tráfego e o rastreamento.
- **📶 Qualidade de Serviço (QoS):** O `PriorityQueueMeshDispatcher` diferencia tráfego em tempo real (voz/chat) de transferências pesadas (arquivos).
- **🔋 Otimização de Bateria:** Consumo inferior a 5% em 12 horas de atividade em segundo plano.
- **🔐 Preparado para o Futuro:** Implementação de mecanismos visando resistência a ataques de computação quântica (KEM).

---

## 🛡️ Segurança Avançada: AES-GCM + PFS + Stealth Mode

O Speew não apenas criptografa, ele se esconde. A arquitetura de segurança foi elevada para o nível **ALPHA-1 (Selo de Guerra)**. O código está blindado contra análise de tráfego e pronto para operar no escuro, focando em resistência à vigilância persistente e à análise de tráfego.

### Recursos de Stealth Mode (Modo Furtivo)

| Recurso | Objetivo | Implementação no Código |
| :--- | :--- | :--- |
| ****Padding** (Traffic Padding)** | Padronizar o tamanho dos pacotes para dificultar a análise de volume de dados. | Implementado em `lib/core/mesh/traffic_obfuscator.dart` (Linhas 74-99). |
| **Decoy Traffic** | Gerar tráfego falso (**Decoy Traffic**) em intervalos aleatórios para ofuscar o padrão de comunicação real. **O tráfego falso é um recurso, não um bug.** | Implementado em `lib/core/mesh/traffic_obfuscator.dart` (Linhas 131-156). |
| **Jitter** | Adicionar atrasos aleatórios (**Jitter**) no envio de pacotes para evitar a análise de tempo e correlação. | Implementado em `lib/core/mesh/traffic_obfuscator.dart` (Linhas 110-129). |
| ****Black Box** (LoggerService)** | Monitora e registra rotações de chave do PFS e eventos críticos de segurança sem expor segredos sensíveis, atuando como um log de auditoria não-volátil. (Ver `lib/core/utils/logger_service.dart`). | A implementação de `CryptoService` em Dart/Flutter sugere o uso de Isolates para operações pesadas, conforme a boa prática. |

---

## 🛠️ Stack Tecnológica

- **Framework:** [Flutter](https://flutter.dev)
- **Linguagem:** Dart
- **Protocolos:** Wi-Fi Direct, Bluetooth Mesh
- **Criptografia:** AES-256-GCM, Perfect Forward Secrecy (PFS), Ed25519
- **Arquitetura:** Descentralizada P2P

---

## 📸 Screenshots

| Tela Inicial | Chat Offline | Configurações de Rede |
| :---: | :---: | :---: |
| <img src="assets/screenshot1.png" width="200" /> | <img src="assets/screenshot2.png" width="200" /> | <img src="assets/screenshot3.png" width="200" /> |

---

## 🚀 Como Executar o Projeto

**SELO ALPHA-1 CONCLUÍDO:** O código-fonte atual representa a versão mais estável e segura do Speew, com todas as otimizações de ofuscação e criptografia aplicadas. O sistema está pronto para o salto para a **MISSÃO BETA (MULTI-HOP)**..

**Atenção:** O consumo de CPU e bateria é um risco gerenciado. O uso de AES-GCM e tráfego falso (**Decoy Traffic**) é um trade-off necessário para a sobrevivência. Monitore o *Thermal Throttling* em dispositivos Android e iOS. (Ver `lib/ui/screens/energy_settings_screen.dart`).


### Pré-requisitos
- Flutter SDK (versão estável mais recente)
- Android Studio / VS Code
- Dispositivos físicos (Redes P2P offline não funcionam bem em emuladores)

### Instalação
1. Clone o repositório:
   ```bash
   git clone [https://github.com/Speew/speew.git](https://github.com/Speew/speew.git)

 * Instale as dependências:
   flutter pub get

 * Execute o projeto:
   flutter run

🤝 Como Contribuir
O Speew é um projeto open-source e precisamos de ajuda, especialmente em:
 * Performance: Otimizações no Mesh Turbo.
 * Segurança: Auditoria de criptografia e anonimato.
 * UX/UI: Melhorias na interface para torná-la intuitiva em situações críticas.
<!-- end list -->
 * Faça um Fork do projeto.
 * Crie uma Branch para sua feature (git checkout -b feature/NovaFeature).
 * Dê um Commit nas suas alterações (git commit -m 'Adicionando nova feature').
 * Dê um Push na Branch (git push origin feature/NovaFeature).
 * Abra um Pull Request.
📜 Licença
Distribuído sob a licença MIT. Veja LICENSE para mais informações.
📧 Contato
Maciel - speewp2p@outlook.com
Link do Projeto: https://github.com/Speew/speew
