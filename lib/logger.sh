#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: lib/logger.sh
# Funções de logging com timestamp e captura de erros
# ==============================================================================

LOG_FILE="${LOG_FILE:-/tmp/fedora-noctalia-installer.log}"

# Inicializa o arquivo de log com cabeçalho de sistema
log_init() {
    local target_file="${LOG_FILE}"
    mkdir -p "$(dirname "$target_file")"
    
    {
        echo "=============================================================================="
        echo "fedora-noctalia: Log de Instalação iniciado em $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Host: $(hostname 2>/dev/null || echo 'desconhecido')"
        echo "Kernel: $(uname -r 2>/dev/null || echo 'desconhecido')"
        echo "Fedora Release: $(rpm -E %fedora 2>/dev/null || echo 'desconhecido')"
        echo "Usuário: ${USER:-$(id -un)}"
        echo "=============================================================================="
    } > "$target_file"
}

# Escreve entrada estruturada no arquivo de log
log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
}

# Tratador de Erros do Shell (ativado com trap ERR)
error_handler() {
    local exit_code="$1"
    local line_no="$2"
    local command="$3"
    local script_name="${4:-$(basename "$0")}"

    local err_msg="Falha no comando '${command}' em ${script_name}:${line_no} (Código: ${exit_code})"
    echo "" >&2
    if declare -f log_error >/dev/null 2>&1; then
        log_error "$err_msg"
        log_error "A instalação foi interrompida. Verifique o log completo em: ${LOG_FILE}"
    else
        echo -e "\e[1;31m[ERRO]\e[0m ${err_msg}" >&2
        echo -e "\e[1;31m[ERRO]\e[0m Verifique o log completo em: ${LOG_FILE}" >&2
    fi

    # Garante que processos em background (ex: keepalive) sejam finalizados
    if declare -f cleanup_installer >/dev/null 2>&1; then
        cleanup_installer
    fi

    exit "$exit_code"
}

# Ativa o trap de erro para o script chamador
enable_error_trap() {
    trap 'error_handler $? $LINENO "$BASH_COMMAND" "$0"' ERR
}
