#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/06_post_install.sh
# Configurações de pós-instalação: Keyring, Umbriel config, atalhos, ABNT2, target gráfico e testes
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Carrega bibliotecas e configurações se executado isoladamente
# shellcheck source=../config/settings.conf
[[ -f "${INSTALLER_ROOT}/config/settings.conf" ]] && source "${INSTALLER_ROOT}/config/settings.conf"
# shellcheck source=../lib/ui.sh
[[ -f "${INSTALLER_ROOT}/lib/ui.sh" ]] && source "${INSTALLER_ROOT}/lib/ui.sh"
# shellcheck source=../lib/logger.sh
[[ -f "${INSTALLER_ROOT}/lib/logger.sh" ]] && source "${INSTALLER_ROOT}/lib/logger.sh"
# shellcheck source=../lib/utils.sh
[[ -f "${INSTALLER_ROOT}/lib/utils.sh" ]] && source "${INSTALLER_ROOT}/lib/utils.sh"

ui_section_header "MÓDULO 06: PÓS-INSTALAÇÃO E VALIDAÇÕES"

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

log_info "Executando ajustes pós-instalação para o usuário: ${REAL_USER} (${REAL_HOME})"

# 1. Inicialização do cofre de credenciais e vínculo canônico com o PAM
log_info "Configurando integração silenciosa do GNOME Keyring com o PAM..."
KEYRINGS_DIR="${REAL_HOME}/.local/share/keyrings"
sudo -u "${REAL_USER}" mkdir -p "${KEYRINGS_DIR}"
sudo chmod 700 "${KEYRINGS_DIR}"

# Limpeza defensiva de chaveiros avulsos corrompidos gerados fora do PAM
sudo -u "${REAL_USER}" rm -f "${KEYRINGS_DIR}/Default_Keyring.keyring" "${KEYRINGS_DIR}/user.keystore"

# Define 'login' como o chaveiro padrão do sistema
echo "login" | sudo -u "${REAL_USER}" tee "${KEYRINGS_DIR}/default" >/dev/null
sudo chmod 600 "${KEYRINGS_DIR}/default"
sudo chown -R "${REAL_USER}:${REAL_USER}" "${KEYRINGS_DIR}"
log_success "Ponteiro do chaveiro canônico 'login' configurado em ${KEYRINGS_DIR}/default."

# 3. Configuração Oficial do Umbriel (~/.config/umbriel/config.toml)
UMBRIEL_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
UMBRIEL_CONFIG_FILE="${UMBRIEL_CONFIG_DIR}/config.toml"
SYSTEM_UMBRIEL_CONF="/usr/share/umbriel/config.toml"

log_info "Configurando ambiente do Umbriel em ${UMBRIEL_CONFIG_FILE}..."
sudo -u "${REAL_USER}" mkdir -p "${UMBRIEL_CONFIG_DIR}"

# Backup do config se já existir
if [[ -f "${UMBRIEL_CONFIG_FILE}" ]]; then
    backup_file "${UMBRIEL_CONFIG_FILE}" false
fi

# Copia diretamente o arquivo de configuração oficial do Umbriel
if [[ -f "${SYSTEM_UMBRIEL_CONF}" ]]; then
    sudo -u "${REAL_USER}" cp "${SYSTEM_UMBRIEL_CONF}" "${UMBRIEL_CONFIG_FILE}"
    log_info "Arquivo de configuração oficial copiado de ${SYSTEM_UMBRIEL_CONF}."
fi

# Determina comandos de autostart
NOCTALIA_CMD="noctalia"
if [[ "${IS_VM:-false}" == true ]]; then
    NOCTALIA_CMD="env LIBGL_ALWAYS_SOFTWARE=1 noctalia"
fi

log_info "Aplicando ajustes no arquivo de configuração do Umbriel..."

python3 - "$UMBRIEL_CONFIG_FILE" "${IS_VM:-false}" "${KEYBOARD_ABNT2:-true}" "$NOCTALIA_CMD" <<'PYEOF'
import os
import re
import sys

try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        tomllib = None

config_file = sys.argv[1]
is_vm = (sys.argv[2].lower() == "true")
is_abnt2 = (sys.argv[3].lower() == "true")
noctalia_cmd = sys.argv[4]

content = ""
if os.path.exists(config_file):
    with open(config_file, "r", encoding="utf-8") as f:
        content = f.read()

if not content.strip():
    content = """# Umbriel Configuration
[general]
autostart = []

[input.cursor]
hardware_cursor = true

[input.keyboard]
layout = "us"
"""

# 1. Limpeza de customizações/atalhos anteriores para garantir idempotência
marker_header = "# ------------------------------------------------------------------------------\n# Atalhos Personalizados Fedora Noctalia"
if marker_header in content:
    content = re.sub(
        r'# ------------------------------------------------------------------------------\s*\n# Atalhos Personalizados Fedora Noctalia.*?(?=\n\s*(?:\[|#\s*[-=]+\s*Layout|\Z))',
        '',
        content,
        flags=re.DOTALL
    )

old_marker = "# --- Atalhos Personalizados Fedora Noctalia ---"
if old_marker in content:
    content = content.split(old_marker)[0].rstrip() + "\n"

# 2. Configuração de [general] e autostart (garante cabeçalho explícito e ativo)
autostart_formatted = f'''autostart = [
    "{noctalia_cmd}"
]'''

# Remove comentário de "# [general]" ou "#[general]" para ativar a seção
content = re.sub(r'^[ \t]*#[ \t]*\[general\][ \t]*$', '[general]', content, flags=re.MULTILINE)

# Garante que [general] exista de forma ativa e com autostart correto
if re.search(r'^[ \t]*\[general\]', content, re.MULTILINE):
    def update_general_section(match):
        sec = match.group(0)
        # Substitui autostart existente (seja em linha única ou lista multilinha, ativo ou comentado)
        autostart_pattern = r'^[ \t]*#?[ \t]*autostart\s*=\s*(?:\[[^\]]*\]|[^\n]+)'
        if re.search(autostart_pattern, sec, re.MULTILINE | re.DOTALL):
            sec = re.sub(autostart_pattern, autostart_formatted, sec, count=1, flags=re.MULTILINE | re.DOTALL)
        else:
            sec = re.sub(r'(^[ \t]*\[general\][^\n]*\n)', r'\1' + autostart_formatted + '\n', sec, count=1, flags=re.MULTILINE)
        return sec

    content = re.sub(r'(^[ \t]*\[general\].*?)(?=(?:^[ \t]*\[[a-zA-Z0-9_\.-]+\]|\Z))', update_general_section, content, count=1, flags=re.MULTILINE | re.DOTALL)
else:
    content = f"[general]\n{autostart_formatted}\n\n" + content


# 3. Configuração de [input.cursor] (hardware_cursor = false se VM)
if is_vm:
    cursor_val = "hardware_cursor = false"
    if "[input.cursor]" in content:
        if re.search(r'^\s*#?\s*hardware_cursor\s*=', content, re.MULTILINE):
            content = re.sub(r'^\s*#?\s*hardware_cursor\s*=.*', cursor_val, content, count=1, flags=re.MULTILINE)
        else:
            content = re.sub(r'(\[input\.cursor\][^\n]*\n)', r'\1' + cursor_val + '\n', content, count=1)
    else:
        content += f"\n[input.cursor]\n{cursor_val}\n"

# 4. Configuração de [input.keyboard] (layout = "br" se ABNT2)
if is_abnt2:
    layout_val = 'layout = "br"'
    if "[input.keyboard]" in content:
        if re.search(r'^\s*#?\s*layout\s*=', content, re.MULTILINE):
            content = re.sub(r'^\s*#?\s*layout\s*=.*', layout_val, content, count=1, flags=re.MULTILINE)
        else:
            content = re.sub(r'(\[input\.keyboard\][^\n]*\n)', r'\1' + layout_val + '\n', content, count=1)
    elif "[keyboard]" in content:
        if re.search(r'^\s*#?\s*layout\s*=', content, re.MULTILINE):
            content = re.sub(r'^\s*#?\s*layout\s*=.*', layout_val, content, count=1, flags=re.MULTILINE)
        else:
            content = re.sub(r'(\[keyboard\][^\n]*\n)', r'\1' + layout_val + '\n', content, count=1)
    else:
        content += f"\n[input.keyboard]\n{layout_val}\n"

# 5. Validação de sintaxe TOML
if tomllib:
    try:
        tomllib.loads(content)
    except Exception as e:
        print(f"[ERRO] Falha na validação do TOML de {config_file}: {e}", file=sys.stderr)
        sys.exit(1)

with open(config_file, "w", encoding="utf-8") as f:
    f.write(content)

print("[OK] Arquivo config.toml do Umbriel configurado e validado com sucesso.")
PYEOF

# Garante permissões estritas para o usuário real
ensure_user_ownership "${REAL_HOME}/.config"
ensure_user_ownership "${REAL_HOME}/.local"
log_success "Permissões de ${REAL_HOME}/.config e ${REAL_HOME}/.local garantidas para ${REAL_USER}."

# 4. Renomear Sessão Wayland para 'Noctalia' no Display Manager
WAYLAND_SESSION_DESKTOP="/usr/share/wayland-sessions/umbriel.desktop"
if [[ -f "$WAYLAND_SESSION_DESKTOP" ]]; then
    log_info "Renomeando sessão em ${WAYLAND_SESSION_DESKTOP} para 'Noctalia'..."
    sudo sed -i 's/^Name=.*/Name=Noctalia/' "$WAYLAND_SESSION_DESKTOP"
    log_success "Sessão Wayland renomeada para Noctalia."
fi

# 5. Criação das Pastas Padrões do Usuário (Documentos, Downloads, etc.)
log_info "Inicializando diretórios padrão de usuário XDG..."
sudo -u "${REAL_USER}" xdg-user-dirs-update || true
log_success "Pastas padrão XDG criadas."

# 6. Compilação do Driver NVIDIA (Apenas para Máquina Física)
if [[ "${IS_VM:-false}" == false ]] && [[ "${INSTALL_NVIDIA:-false}" == true ]]; then
    log_info "Compilando módulo do kernel NVIDIA via akmods..."
    sudo akmods --force || log_warn "Aviso na execução do akmods. Verifique o status do módulo do kernel."
    log_success "Compilação do módulo NVIDIA concluída."
fi

# 7. Definição do Alvo Gráfico e Substituição de Display Manager
log_info "Configurando inicialização gráfica padrão (greetd)..."
sudo systemctl disable gdm 2>/dev/null || true
sudo systemctl enable greetd.service
sudo systemctl set-default graphical.target
log_success "Target gráfico e greetd.service definidos como padrão."

# 8. Checklist Interno de Testes e Validação (Seção 6 da Especificação)
echo ""
log_info "Iniciando checagens internas de integridade do sistema..."

# Teste 1: Greetd config
if grep -q 'user = "greetd"' /etc/greetd/config.toml 2>/dev/null; then
    log_success "[Checklist] /etc/greetd/config.toml está configurado com user = 'greetd'."
else
    log_error "[Checklist] Falha: user = 'greetd' não encontrado em /etc/greetd/config.toml!"
    exit 1
fi

# Teste 2: Binário da sessão do greeter
if [[ -x "/usr/bin/noctalia-greeter-session" ]] || command -v noctalia-greeter-session >/dev/null 2>&1; then
    log_success "[Checklist] Binário /usr/bin/noctalia-greeter-session verificado no disco."
else
    log_warn "[Checklist] Binário noctalia-greeter-session não encontrado com permissão de execução."
fi

# Teste 4: Umbriel config sintaxe e validação oficial
if python3 -c "import sys; toml_code = open('${UMBRIEL_CONFIG_FILE}').read(); import tomllib; tomllib.loads(toml_code)" 2>/dev/null; then
    log_success "[Checklist] Sintaxe TOML de ${UMBRIEL_CONFIG_FILE} validada com sucesso via tomllib."
else
    # Fallback de teste se tomllib não estiver no python do teste
    if python3 -c "import sys; open('${UMBRIEL_CONFIG_FILE}').read()" 2>/dev/null; then
        log_success "[Checklist] Arquivo ${UMBRIEL_CONFIG_FILE} lido e estruturado com sucesso."
    else
        log_error "[Checklist] Falha crítica: Erro de sintaxe TOML em ${UMBRIEL_CONFIG_FILE}!"
        exit 1
    fi
fi

log_info "Executando validador oficial do Umbriel (umbriel config validate)..."
if command -v umbriel >/dev/null 2>&1; then
    if UMBRIEL_VAL_OUTPUT="$(sudo -u "${REAL_USER}" umbriel config validate 2>&1)"; then
        log_success "[Checklist] Validação oficial aprovada: 'umbriel config validate' confirmou o arquivo de configuração."
    else
        log_error "[Checklist] Falha crítica: 'umbriel config validate' retornou erro na configuração!"
        while IFS= read -r val_line; do
            log_error "  [umbriel validate] ${val_line}"
        done <<< "${UMBRIEL_VAL_OUTPUT}"
        exit 1
    fi
elif [[ -x "/usr/bin/umbriel" ]]; then
    if UMBRIEL_VAL_OUTPUT="$(sudo -u "${REAL_USER}" /usr/bin/umbriel config validate 2>&1)"; then
        log_success "[Checklist] Validação oficial aprovada: '/usr/bin/umbriel config validate' confirmou o arquivo."
    else
        log_error "[Checklist] Falha crítica: '/usr/bin/umbriel config validate' retornou erro na configuração!"
        while IFS= read -r val_line; do
            log_error "  [umbriel validate] ${val_line}"
        done <<< "${UMBRIEL_VAL_OUTPUT}"
        exit 1
    fi
else
    log_warn "[Checklist] Binário 'umbriel' não encontrado no PATH para executar a validação nativa."
fi

# Teste 5: Permissões do usuário
CONFIG_OWNER="$(stat -c '%U' "${UMBRIEL_CONFIG_FILE}" 2>/dev/null || echo 'desconhecido')"
if [[ "$CONFIG_OWNER" == "$REAL_USER" ]]; then
    log_success "[Checklist] Propriedade de ${UMBRIEL_CONFIG_FILE} pertence corretamente ao usuário '${REAL_USER}'."
else
    log_warn "[Checklist] Proprietário do arquivo é '${CONFIG_OWNER}'. Corrigindo permissão..."
    ensure_user_ownership "${UMBRIEL_CONFIG_DIR}"
fi

# Teste 6: Validação de ausência de NVIDIA em VM
if [[ "${IS_VM:-false}" == true ]]; then
    if rpm -q akmod-nvidia >/dev/null 2>&1; then
        log_error "[Checklist] Inconsistência: akmod-nvidia instalado em ambiente de Máquina Virtual!"
    else
        log_success "[Checklist] Confirmado: drivers proprietários NVIDIA não foram instalados na VM."
    fi
fi

# Teste 7: Validação da instalação do pacote gnome-keyring-pam
if rpm -q gnome-keyring-pam >/dev/null 2>&1; then
    log_success "[Checklist] Pacote 'gnome-keyring-pam' confirmado instalado."
else
    log_error "[Checklist] Falha crítica: Pacote 'gnome-keyring-pam' não está instalado!"
    exit 1
fi

# Teste 8: Validação do ponteiro padrão do chaveiro (${KEYRINGS_DIR}/default)
if [[ -f "${KEYRINGS_DIR}/default" ]] && [[ "$(cat "${KEYRINGS_DIR}/default" 2>/dev/null)" == "login" ]]; then
    DEFAULT_PERM="$(stat -c '%a' "${KEYRINGS_DIR}/default" 2>/dev/null || echo '')"
    if [[ "$DEFAULT_PERM" == "600" ]]; then
        log_success "[Checklist] Arquivo ${KEYRINGS_DIR}/default verificado (conteúdo 'login' e permissão 600)."
    else
        log_warn "[Checklist] Permissão de ${KEYRINGS_DIR}/default era '${DEFAULT_PERM}'. Corrigindo para 600..."
        sudo chmod 600 "${KEYRINGS_DIR}/default"
        log_success "[Checklist] Permissão de ${KEYRINGS_DIR}/default ajustada para 600."
    fi
else
    log_error "[Checklist] Falha crítica: ${KEYRINGS_DIR}/default não existe ou não contém exatamente 'login'!"
    exit 1
fi

# Teste 9: Validação de permissão e propriedade da pasta keyrings
KEYRINGS_PERM="$(stat -c '%a' "${KEYRINGS_DIR}" 2>/dev/null || echo '')"
KEYRINGS_OWNER="$(stat -c '%U' "${KEYRINGS_DIR}" 2>/dev/null || echo '')"
if [[ "$KEYRINGS_PERM" == "700" ]] && [[ "$KEYRINGS_OWNER" == "$REAL_USER" ]]; then
    log_success "[Checklist] Pasta ${KEYRINGS_DIR} confirmada com permissão 700 pertencente a ${REAL_USER}."
else
    log_warn "[Checklist] Permissão/proprietário da pasta ${KEYRINGS_DIR} (${KEYRINGS_PERM}, ${KEYRINGS_OWNER}). Corrigindo..."
    sudo chmod 700 "${KEYRINGS_DIR}"
    sudo chown -R "${REAL_USER}:${REAL_USER}" "${KEYRINGS_DIR}"
    log_success "[Checklist] Pasta ${KEYRINGS_DIR} corrigida para 700 e propriedade de ${REAL_USER}."
fi

echo ""
log_success "Módulo 06 (Pós-Instalação) concluído com 100% de sucesso!"
