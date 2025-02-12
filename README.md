# **AutoMobile.sh**
### **Automatización de Android Emulation y Proxying en Linux y macOS**

### **📌 Descripción**
**AutoMobile.sh** es un script de automatización para configurar y ejecutar emuladores de Android rooteados, permitiendo la interceptación de tráfico HTTPS a través de **Burp Suite**. Se encarga de iniciar el emulador, instalar certificados de Burp Suite en el sistema y establecer configuraciones de proxy de forma rápida y eficiente.

### **🚀 Características**
✔ **Soporte multiplataforma**: Funciona en **Linux** y **macOS**.  
✔ **Configuración automática de entornos**: Verifica dependencias esenciales como **ADB, Android Emulator y Java**.  
✔ **Instalación de certificados SSL/TLS**: Instala automáticamente el certificado de **Burp Suite** en el sistema para proxear tráfico.  
✔ **Selección de dispositivos AVD**: Permite elegir qué emulador ejecutar en tiempo de ejecución.  
✔ **Remount del sistema**: Automatiza la configuración de permisos de escritura (`rw`) en `/system` y la instalación del certificado.  
✔ **Proxy automático**: Configura el proxy en el emulador para interceptar tráfico HTTP/HTTPS con **Burp Suite**.  

---

## **📦 Instalación**
### **1️⃣ Requisitos previos**
- **Linux/macOS**
- **Android Studio + SDK Tools**
- **ADB (Android Debug Bridge)**
- **Java (OpenJDK 8+ recomendado)**
- **Burp Suite** (o cualquier proxy HTTP que necesites usar)

#### **Linux**
```bash
sudo apt update && sudo apt install -y android-tools-adb openjdk-17-jdk wget
```

#### **macOS**
```bash
brew install android-platform-tools openjdk wget
```

### **2️⃣ Clonar el repositorio**
```bash
git clone https://github.com/tu-usuario/AutoMobile.sh.git
cd AutoMobile.sh
chmod +x AutoMobile.sh
```

---

## **⚡ Uso**

### **1️⃣ Configurar e instalar el entorno**

```bash
./AutoMobile.sh -i
```

Este comando:

- **Verifica dependencias** (ADB, Emulator, Java).
- **Permite seleccionar un AVD** disponible en tu sistema.
- **Inicia el emulador con `writable-system` habilitado**.
- **Realiza el remount automático de `/system` para escritura**.
- **Descarga e instala el certificado de Burp Suite en `/system/etc/security/cacerts/`**.

### **2️⃣ Iniciar el emulador en modo writable-system sin reinstalar certificados**

```bash
./AutoMobile.sh -s
```

Este comando:

- **Inicia el emulador con `writable-system` habilitado**, permitiendo modificaciones en el sistema.
- No reinstala el certificado de Burp Suite (útil si ya fue instalado previamente).
- Se usa cuando ya configuraste el entorno con `i` y solo necesitas levantar el emulador nuevamente.

### **3️⃣ Opciones disponibles**
```bash
./AutoMobile.sh -h
```
Muestra el panel de ayuda.

---

## **🔍 Diagnóstico y solución de problemas**
### **1️⃣ El certificado no aparece en Trusted Credentials**
- **Esto es normal en Android 11+**. Aunque el certificado está instalado en el sistema, no se muestra en `Configuración > Seguridad > Credenciales de confianza`.
- Si necesitas que Chrome lo acepte, instala el certificado manualmente en el almacén de usuario:
  ```bash
  adb push burp_certificate.der /sdcard/
  ```
  Luego, en el emulador:
  - Ir a `Configuración > Seguridad > Instalar desde almacenamiento`.
  - Seleccionar el archivo `.der`.

### **2️⃣ Chrome sigue sin confiar en el certificado**
- Abre `chrome://flags` en el navegador.
- Activa **"Allow invalid certificates for resources loaded from localhost"**.
- Reinicia Chrome.

### **3️⃣ Proxy no funciona o el tráfico no aparece en Burp**
```bash
adb shell settings put global http_proxy 10.0.2.2:8080
adb shell settings get global http_proxy  # Verificar si está activado
```

---

## **📌 Compatibilidad**
✅ **Linux** (Ubuntu, Debian, Arch, Fedora).  
✅ **macOS** (Intel y Apple Silicon).  
❌ **Windows** *(No soportado directamente, pero puedes usar WSL2 con Ubuntu)*.  

---

## **📜 Licencia**
Este proyecto está bajo la licencia **MIT**.

---

### **🔗 Contacto**
Si tienes preguntas, reportes de errores o sugerencias, abre un **issue** en el repositorio o contáctame en `tu-email@example.com`. 🚀

