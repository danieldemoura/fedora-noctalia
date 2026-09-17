#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: lib/utils.sh
# Funções utilitárias: validações, sudo keepalive, permissões e manipulação segura
# ==============================================================================

SUDO_KEEPALIVE_PID=""

# Impede a execução direta do script como root (Segurança / Seção 1.2 da especificação)
check_not_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        echo -e "\e[1;31m[ERRO] Não execute este script diretamente com sudo ou como usuário root!\e[0m" >&2
        echo -e "Execute como seu usuário comum: \e[1;36m./setup.sh\e[0m" >&2
        echo -e "O script solicitará privilégios administrativos (sudo) internamente quando necessário." >&2
        exit 1
    fi
}

# Obtém o usuário real e o diretório home correspondente
get_real_user() {
    local target_user="${SUDO_USER:-${USER}}"
    echo "$target_user"
}

get_real_user_home() {
    local target_user
    target_user="$(get_real_user)"
    eval echo "~${target_user}"
}

# Garante que arquivos criados pertençam ao usuário comum, nunca a root:root
ensure_user_ownership() {
    local target_path="$1"
    local real_user
    real_user="$(get_real_user)"

    if [[ -e "$target_path" ]]; then
        sudo chown -R "${real_user}:${real_user}" "$target_path"
    fi
}

# Inicializa validação do sudo e dispara loop de keepalive em background
start_sudo_keepalive() {
    log_info "Verificando privilégios administrativos (sudo)..."
    if ! sudo -v; then
        log_error "Falha ao obter privilégios de sudo. O usuário atual deve pertencer ao grupo wheel."
        exit 1
    fi

    # Loop de keepalive em segundo plano atualizando o timestamp do sudo a cada 50s
    (
        while true; do
            sudo -n true 2>/dev/null
            sleep 50
            kill -0 "$$" 2>/dev/null || exit
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
    log_info "Sudo keepalive ativado (PID: ${SUDO_KEEPALIVE_PID})."
}

# Finaliza o processo de keepalive do sudo
stop_sudo_keepalive() {
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "${SUDO_KEEPALIVE_PID}" 2>/dev/null; then
        kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
        wait "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
        SUDO_KEEPALIVE_PID=""
    fi
}

# Limpeza geral de encerramento do script
cleanup_installer() {
    stop_sudo_keepalive
}

# Registra saída limpa ao receber sinais comuns de finalização
trap cleanup_installer EXIT INT TERM

# Valida conectividade com a Internet
check_internet() {
    log_info "Verificando conexão com a internet..."
    local test_hosts=("1.1.1.1" "8.8.8.8" "fedoraproject.org")
    local connected=false

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            connected=true
            break
        fi
    done

    if [[ "$connected" != true ]]; then
        if curl -fsI --connect-timeout 5 https://fedoraproject.org >/dev/null 2>&1; then
            connected=true
        fi
    fi

    if [[ "$connected" != true ]]; then
        log_error "Sem conexão com a internet detectada. Verifique o cabo de rede ou Wi-Fi antes de prosseguir."
        exit 1
    fi
    log_success "Conectividade com a internet confirmada."
}

# Lê lista de pacotes de um arquivo .conf (ignora linhas vazias e comentários)
read_package_list() {
    local conf_file="$1"
    if [[ ! -f "$conf_file" ]]; then
        log_error "Arquivo de lista de pacotes não encontrado: $conf_file"
        return 1
    fi

    grep -E -v '^[[:space:]]*#' "$conf_file" | grep -E -v '^[[:space:]]*$' | tr '\n' ' '
}

# Insere linha de forma idempotente em arquivo se não existir
append_if_missing() {
    local file="$1"
    local line="$2"
    local use_sudo="${3:-false}"

    if [[ "$use_sudo" == true ]]; then
        if ! sudo grep -qF "$line" "$file" 2>/dev/null; then
            echo "$line" | sudo tee -a "$file" >/dev/null
        fi
    else
        if ! grep -qF "$line" "$file" 2>/dev/null; then
            echo "$line" >> "$file"
        fi
    fi
}

# Cria backup seguro do arquivo apenas se não houver um backup prévio
backup_file() {
    local file="$1"
    local use_sudo="${2:-false}"

    if [[ -f "$file" ]] && [[ ! -f "${file}.bak" ]]; then
        if [[ "$use_sudo" == true ]]; then
            sudo cp "$file" "${file}.bak"
        else
            cp "$file" "${file}.bak"
        fi
        log_info "Backup criado: ${file}.bak"
    fi
}
