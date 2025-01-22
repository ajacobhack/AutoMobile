#!/bin/bash

# Códigos de color ANSI
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Detectar el sistema operativo
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    OS_TYPE="windows"
else
    echo -e "${RED}[X] Sistema operativo no soportado.${RESET}"
    exit 1
fi

# Variables de entorno
user=$(whoami)
ADB_PATH=""
EMULATOR_PATH=""
JAVA_PATH=""

# Verificar si un ejecutable está disponible en el PATH
function checkExecutableInPath() {
    local executable=$1
    local friendly_name=$2

    if ! command -v "$executable" &> /dev/null; then
        echo -e "${RED}[X] $friendly_name no se encuentra en el PATH.${RESET}"
        echo -e "${YELLOW}[*] Por favor, instala o verifica la configuración de $friendly_name.${RESET}"
        return 1
    fi
    echo -e "${GREEN}[V] $friendly_name está disponible en el PATH.${RESET}"
    return 0
}

# Configurar rutas específicas por sistema operativo
function configurePaths() {
    echo -e "${BLUE}[*] Configurando rutas específicas para $OS_TYPE...${RESET}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

        # Buscar el emulador en Android Studio.app o en el SDK
        if [[ -d "/Applications/Android Studio.app" ]]; then
            EMULATOR_PATH=$(find "/Applications/Android Studio.app" -name "emulator" -type f 2>/dev/null | head -n 1)
        fi
        if [[ -z "$EMULATOR_PATH" ]]; then
            SDK_PATH="$HOME/Library/Android/sdk"
            EMULATOR_PATH="$SDK_PATH/emulator/emulator"
        fi
        if [[ -z "$EMULATOR_PATH" || ! -f "$EMULATOR_PATH" ]]; then
            echo -e "${RED}[X] No se encontró el Android Emulator. Verifica tu instalación del SDK.${RESET}"
            exit 1
        fi

        # Reemplazar la ruta completa del home por ~ de manera robusta
        if [[ "$EMULATOR_PATH" == "$HOME"* ]]; then
            EMULATOR_PATH_DISPLAY="~${EMULATOR_PATH#$HOME}"
        else
            EMULATOR_PATH_DISPLAY="$EMULATOR_PATH"
        fi
        echo -e "${GREEN}[V] Android Emulator detectado en: $EMULATOR_PATH_DISPLAY${RESET}"

        # Validar adb
        ADB_PATH=$(command -v adb)
        if [[ -z "$ADB_PATH" ]]; then
            echo -e "${RED}[X] adb no está disponible en el PATH.${RESET}"
            echo -e "${YELLOW}[*] Instálalo con: brew install android-platform-tools${RESET}"
            exit 1
        fi

        # Validar Java
        JAVA_PATH=$(command -v java)
        if [[ -z "$JAVA_PATH" ]]; then
            echo -e "${RED}[X] Java no está disponible en el PATH.${RESET}"
            echo -e "${YELLOW}[*] Instálalo con: brew install openjdk${RESET}"
            exit 1
        fi
    fi
    echo -e "${GREEN}[V] Configuración de rutas completada con éxito.${RESET}"
}

# Verificar dependencias generales
function checkDependencies() {
    echo -e "${BLUE}[*] Chequeando dependencias para $OS_TYPE...${RESET}"

    checkExecutableInPath "adb" "adb" || exit 1
    checkExecutableInPath "java" "Java" || exit 1

    if [[ -z "$EMULATOR_PATH" ]]; then
        echo -e "${RED}[X] Android Emulator no está configurado correctamente.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[V] Todas las dependencias están configuradas correctamente.${RESET}"
}

# Formateo del certificado
function formatCert() {
    local cert_file=$1
    openssl x509 -inform DER -in "$cert_file.der" -out "$cert_file.pem" || {
        echo -e "${RED}[X] Error al convertir el certificado DER a PEM.${RESET}"
        exit 1
    }

    local hash
    hash=$(openssl x509 -inform PEM -subject_hash_old -in "$cert_file.pem" | head -n 1) || {
        echo -e "${RED}[X] Error al calcular el hash del certificado.${RESET}"
        exit 1
    }

    mv "$cert_file.pem" "$hash.0"
    echo "$hash.0"
}

# Iniciar el emulador
function getDevice() {
    devices=$("$EMULATOR_PATH" -list-avds)
    if [[ -z "$devices" ]]; then
        echo -e "${RED}[X] No se detectó ningún dispositivo. Crea uno e inicia nuevamente.${RESET}"
        exit 1
    fi

    echo -e "${BLUE}[*] Selecciona un dispositivo:${RESET}"
    select device in $devices; do
        echo -e "${BLUE}[*] Iniciando emulador $device...${RESET}"
        "$EMULATOR_PATH" -avd "$device" -http-proxy 10.0.2.2:8080 -writable-system > /dev/null 2>&1 &
        break
    done

    echo -e "${BLUE}[*] Esperando que el emulador se conecte...${RESET}"
    while ! adb devices | grep -E "device$" > /dev/null; do
        sleep 1
    done

    echo -e "${GREEN}[V] Emulador conectado.${RESET}"
}

# Instalar certificado en el dispositivo
function uploadCert() {
    echo -e "${BLUE}[+] Instalando certificado en el dispositivo...${RESET}"
    adb root || {
        echo -e "${RED}[X] Error al ejecutar adb root.${RESET}"
        exit 1
    }
    adb remount || {
        echo -e "${RED}[X] Error al remount del sistema.${RESET}"
        exit 1
    }
    adb push "$1" /system/etc/security/cacerts/ || {
        echo -e "${RED}[X] Error al subir el certificado.${RESET}"
        exit 1
    }
    adb shell chmod 644 "/system/etc/security/cacerts/$1" || {
        echo -e "${RED}[X] Error al cambiar permisos del certificado.${RESET}"
        exit 1
    }
}

# Instalar Burp Suite
function installBurpCert() {
    if [[ -f *.0 ]]; then
        echo -e "${YELLOW}[*] Certificado ya encontrado en el directorio actual. Usando archivo existente...${RESET}"
        local hash=$(ls *.0 | head -n 1)
        uploadCert "$hash"
    else
        echo -e "${BLUE}[+] Descargando certificado de Burp Suite...${RESET}"
        wget -qO burp_certificate.der http://127.0.0.1:8080/cert || {
            echo -e "${RED}[X] Error al descargar el certificado de Burp Suite.${RESET}"
            exit 1
        }
        local hash
        hash=$(formatCert "burp_certificate")
        uploadCert "$hash"
    fi
}

# Panel de ayuda
function helpPanel() {
    echo -e "${BLUE}[*] Uso: ./RunAutomobile.sh${RESET}"
    echo -e "\t-i | --install --> Configura el entorno completo"
    echo -e "\t-s | --start --> Inicia el dispositivo configurado\n"
    exit 1
}

# Menú principal
if [[ -z "$1" ]]; then
    helpPanel
fi

configurePaths
checkDependencies

while [[ -n "$1" ]]; do
    case "$1" in
        -i|--install)
            echo -e "${BLUE}[*] Configurando entorno completo...${RESET}"
            getDevice
            installBurpCert
            shift
            ;;
        -s|--start)
            echo -e "${BLUE}[*] Iniciando dispositivo configurado...${RESET}"
            getDevice
            shift
            ;;
        -h|--help)
            helpPanel
            shift
            ;;
        *)
            echo -e "${RED}[X] Opción desconocida: $1${RESET}"
            helpPanel
            ;;
    esac
done
