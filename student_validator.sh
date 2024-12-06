#!/bin/bash

# URL base para los validadores en GitHub (actualiza con tu usuario y repositorio)
GITHUB_RAW_URL="https://raw.githubusercontent.com/VictorGSandoval/LabK8S/main"
#!/bin/bash

# URL base para los validadores en GitHub
#GITHUB_RAW_URL="https://raw.githubusercontent.com/<GITHUB_USER>/<REPO_NAME>/main"
TEMP_DIR="/tmp/validator_temp"
LOG_FILE="/tmp/validator_log.txt"

# Variables para el correo y nombre del estudiante
STUDENT_EMAIL=$STUDENT_EMAIL
USER_NAME=""
FASE=$FASE

#Test
# Función para limpiar archivos temporales
cleanup() {
    echo "Limpiando archivos temporales..." | tee -a "$LOG_FILE"
    rm -rf "$TEMP_DIR"
}

# Manejo de errores
trap 'cleanup; echo "Error crítico: terminando ejecución."; exit 1' ERR

# Validar conexión a internet
validate_internet() {
    echo "Validando conexión a internet..." | tee -a "$LOG_FILE"

    # Intentar con ping a 8.8.8.8
    if command -v ping > /dev/null 2>&1; then
        if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
            echo "Conexión a internet verificada con ping." | tee -a "$LOG_FILE"
            return 0
        fi
    fi

    # Intentar con ping a google.com
    if command -v ping > /dev/null 2>&1; then
        if ping -c 1 -W 2 www.google.com > /dev/null 2>&1; then
            echo "Conexión a internet verificada con ping a www.google.com." | tee -a "$LOG_FILE"
            return 0
        fi
    fi

    # Validar conexión con /dev/tcp
    if [ -e /dev/tcp/8.8.8.8/53 ]; then
        echo > /dev/tcp/8.8.8.8/53 && {
            echo "Conexión a internet verificada mediante /dev/tcp." | tee -a "$LOG_FILE"
            return 0
        }
    fi

    # Intentar con wget
    if command -v wget > /dev/null 2>&1; then
        if wget -q --spider http://www.google.com; then
            echo "Conexión a internet verificada con wget." | tee -a "$LOG_FILE"
            return 0
        fi
    fi

    # Intentar con curl
    if command -v curl > /dev/null 2>&1; then
        if curl -s --head http://www.google.com | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
            echo "Conexión a internet verificada con curl." | tee -a "$LOG_FILE"
            return 0
        fi
    fi

    # Si ninguno funciona
    echo "Error: No hay conexión a internet." | tee -a "$LOG_FILE"
    exit 1
}


get_student_email() {
    # Validar si la variable de entorno STUDENT_EMAIL está configurada
    if [[ -n "$STUDENT_EMAIL" ]]; then
        echo "🟢 [INFO] Usando correo desde variable de entorno: $STUDENT_EMAIL"
        USER_NAME=$(echo "$STUDENT_EMAIL" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    else
        # Solicitar el correo si no está configurado en la variable de entorno
        echo "🔴 [ERROR] La variable de entorno STUDENT_EMAIL no está configurada."
        echo -n "✏ [INPUT] Por favor, ingresa tu correo institucional (terminado en vallegrande.edu.pe): "
        read STUDENT_EMAIL
        if [[ ! "$STUDENT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@vallegrande\.edu\.pe$ ]]; then
            echo "❌ [ERROR] El correo debe ser válido y del dominio vallegrande.edu.pe."
            exit 1
        fi
        USER_NAME=$(echo "$STUDENT_EMAIL" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
        echo "🟢 [INFO] Correo proporcionado y procesado: $STUDENT_EMAIL"
    fi
   #echo "Variables de entorno disponibles:"
   #printenv
}




get_fase() {
    # Verificar si FASE está configurada como variable de entorno y es válida
    if [[ -n "$FASE" && ( "$FASE" == "1" || "$FASE" == "2" || "$FASE" == "3" ) ]]; then
        echo "Usando la fase proporcionada en la variable de entorno: FASE=$FASE"
    else
        # Solicitar al usuario que introduzca la fase si no está configurada o es inválida
        echo -n "Ingresa la fase que deseas validar (1, 2 o 3): "
        read FASE
        if [[ "$FASE" != "1" && "$FASE" != "2" && "$FASE" != "3" ]]; then
            echo "Error: La fase debe ser 1, 2 o 3." | tee -a "$LOG_FILE"
            exit 1
        fi
    fi
}


# Detectar compatibilidad con base64
detect_base64_option() {
    echo "Detectando compatibilidad de base64..." | tee -a "$LOG_FILE"
    if echo "test" | base64 -d > /dev/null 2>&1; then
        BASE64_DECODE="-d"
    elif echo "test" | base64 -D > /dev/null 2>&1; then
        BASE64_DECODE="-D"
    else
        echo "Error: No se encontró una opción válida para decodificar base64." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Descargar el validador correspondiente a la fase
download_validator() {
    local encoded_file="validator_fase_$FASE.sh.b64"
    echo "Descargando validador para la fase $FASE desde el servidor..." | tee -a "$LOG_FILE"
    curl -s -o "$TEMP_DIR/$encoded_file" "$GITHUB_RAW_URL/$encoded_file"

    if [[ ! -s "$TEMP_DIR/$encoded_file" ]]; then
        echo "Error: No se pudo descargar el validador o el archivo está vacío." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Decodificar el archivo usando redirección estándar
    base64 $BASE64_DECODE -i "$TEMP_DIR/$encoded_file" > "$TEMP_DIR/validator.sh"
    chmod +x "$TEMP_DIR/validator.sh"
}

# Ejecutar el validador descargado
execute_validator() {
    echo "Ejecutando el validador para la fase $FASE..." | tee -a "$LOG_FILE"
    if ! "$TEMP_DIR/validator.sh" "$USER_NAME" "$FASE"; then
        echo "Error: El validador encontró un problema." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Limpieza tras ejecución exitosa
final_cleanup() {
    echo "Ejecución completada correctamente. Limpiando archivos temporales..." | tee -a "$LOG_FILE"
    cleanup
}

# Ejecución principal
main() {
    mkdir -p "$TEMP_DIR"

    # Validar conexión a internet
    validate_internet

    # Obtener correo del estudiante
    get_student_email

    # Validar la fase seleccionada
    get_fase

    # Detectar compatibilidad de base64
    detect_base64_option

    # Descargar y ejecutar el validador correspondiente
    download_validator
    execute_validator

    # Limpieza final
    final_cleanup
}

main
