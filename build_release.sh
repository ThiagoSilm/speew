#!/bin/bash

# ==============================================================================
# SPEEW ALPHA-1: PLUG AND PLAY RELEASE BUILD SCRIPT
# Autor: Manus AI
# Data: 2025-12-23
#
# Este script automatiza o processo de build de release para Android (APK) e
# iOS (IPA) do projeto Speew Alpha-1.
#
# Uso: ./build_release.sh
# ==============================================================================

# Cores para o terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
PROJECT_DIR=$(dirname "$0")
BUILD_DIR="$PROJECT_DIR/build/releases"
ANDROID_OUTPUT="$BUILD_DIR/speew_alpha1_release.apk"
IOS_OUTPUT="$BUILD_DIR/speew_alpha1_release.ipa"

# Função para exibir cabeçalho
header() {
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${BLUE}  SPEEW ALPHA-1: PLUG AND PLAY RELEASE BUILD SCRIPT${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${YELLOW}Diretório do Projeto: $PROJECT_DIR${NC}"
    echo -e "${YELLOW}Diretório de Saída: $BUILD_DIR${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
}

# Função para limpar builds anteriores
cleanup() {
    echo -e "\n${YELLOW}--- Limpando builds anteriores... ---${NC}"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    echo -e "${GREEN}Limpeza concluída.${NC}"
}

# Função para instalar dependências
get_dependencies() {
    echo -e "\n${BLUE}--- 1. Obtendo dependências do Flutter... ---${NC}"
    (cd "$PROJECT_DIR" && flutter pub get)
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERRO: Falha ao obter dependências. Verifique sua instalação do Flutter.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Dependências obtidas com sucesso.${NC}"
}

# Função para build Android
build_android() {
    echo -e "\n${BLUE}--- 2. Iniciando Build de Release para Android (APK)... ---${NC}"
    (cd "$PROJECT_DIR" && flutter build apk --release)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERRO: Falha no build do Android APK.${NC}"
        return 1
    fi

    # Mover e renomear o APK
    APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        cp "$APK_PATH" "$ANDROID_OUTPUT"
        echo -e "${GREEN}Build Android concluído! APK salvo em: $ANDROID_OUTPUT${NC}"
    else
        echo -e "${RED}ERRO: Arquivo APK de saída não encontrado em $APK_PATH.${NC}"
        return 1
    fi
}

# Função para build iOS
build_ios() {
    echo -e "\n${BLUE}--- 3. Iniciando Build de Release para iOS (IPA)... ---${NC}"
    
    # Verifica se está em ambiente macOS (necessário para build iOS)
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}AVISO: O build de iOS (IPA) requer um ambiente macOS com Xcode.${NC}"
        echo -e "${YELLOW}O comando será executado, mas pode falhar neste ambiente.${NC}"
    fi

    (cd "$PROJECT_DIR" && flutter build ipa --release)

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERRO: Falha no build do iOS IPA. Verifique seu ambiente macOS/Xcode.${NC}"
        return 1
    fi

    # O Flutter geralmente coloca o IPA em build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
    # A localização exata pode variar. Vamos apenas informar o sucesso.
    echo -e "${GREEN}Build iOS concluído! O IPA estará localizado em: $PROJECT_DIR/build/ios/archive/${NC}"
    echo -e "${YELLOW}Você precisará do Xcode para exportar o IPA final para distribuição.${NC}"
}

# Função principal
main() {
    header
    cleanup
    get_dependencies
    
    # Executa builds
    build_android
    build_ios

    echo -e "\n${BLUE}=====================================================================${NC}"
    echo -e "${GREEN}PROCESSO DE BUILD PLUG AND PLAY CONCLUÍDO.${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${YELLOW}Verifique o diretório $BUILD_DIR para os artefatos de release.${NC}"
}

# Executa a função principal
main
