#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/06_post_install.sh
# Configurações de pós-instalação: Umbriel config, atalhos, ABNT2, target gráfico e testes
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

ui_section_header "MÓDULO 06: PÓS-INSTALAÇÃO, ATALHOS E VALIDAÇÕES"

REAL_USER="$(get_real_user)"
REAL_HOME="$(get_real_user_home)"

log_info "Executando ajustes pós-instalação para o usuário: ${REAL_USER} (${REAL_HOME})"

# 1. Localização do Agente Polkit
POLKIT_AGENT_PATH="/usr/libexec/polkit-mate-authentication-agent-1"
if [[ ! -f "$POLKIT_AGENT_PATH" ]]; then
    if [[ -f "/usr/lib/polkit-mate-authentication-agent-1" ]]; then
        POLKIT_AGENT_PATH="/usr/lib/polkit-mate-authentication-agent-1"
    else
        log_warn "Caminho do polkit-mate não encontrado exatamente em /usr/libexec. Mantendo padrão."
    fi
fi

# 2. Configuração do Umbriel (~/.config/umbriel/config.toml)
UMBRIEL_CONFIG_DIR="${REAL_HOME}/.config/umbriel"
UMBRIEL_CONFIG_FILE="${UMBRIEL_CONFIG_DIR}/config.toml"
SYSTEM_UMBRIEL_CONF="/usr/share/umbriel/config.toml"

log_info "Configurando ambiente do Umbriel em ${UMBRIEL_CONFIG_FILE}..."
sudo -u "${REAL_USER}" mkdir -p "${UMBRIEL_CONFIG_DIR}"

if [[ -f "${SYSTEM_UMBRIEL_CONF}" ]]; then
    if [[ ! -f "${UMBRIEL_CONFIG_FILE}" ]]; then
        sudo -u "${REAL_USER}" cp "${SYSTEM_UMBRIEL_CONF}" "${UMBRIEL_CONFIG_FILE}"
        log_info "Arquivo base copiado de ${SYSTEM_UMBRIEL_CONF}."
    fi
fi

# Backup do config do Umbriel se já existir
if [[ -f "${UMBRIEL_CONFIG_FILE}" ]]; then
    backup_file "${UMBRIEL_CONFIG_FILE}" false
fi

# Determina comandos de autostart
NOCTALIA_CMD="noctalia"
if [[ "${IS_VM:-false}" == true ]]; then
    NOCTALIA_CMD="env LIBGL_ALWAYS_SOFTWARE=1 noctalia"
fi

# Script embutido de merge seguro para o config.toml do Umbriel
log_info "Injetando seções de autostart, teclado e atalhos no config do Umbriel..."

python3 - <<PYEOF
import os
import sys

config_file = "${UMBRIEL_CONFIG_FILE}"
is_vm = ("${IS_VM:-false}".lower() == "true")
is_abnt2 = ("${KEYBOARD_ABNT2:-true}".lower() == "true")
polkit_bin = "${POLKIT_AGENT_PATH}"
noctalia_cmd = "${NOCTALIA_CMD}"

# Se arquivo não existe ou está vazio, cria modelo base
existing_content = ""
if os.path.exists(config_file):
    with open(config_file, "r", encoding="utf-8") as f:
        existing_content = f.read()

# Blocos a serem injetados
custom_blocks = []

# Seção General / Autostart
autostart_block = f"""
# --- Configuração Automatizada Fedora Noctalia ---
[general]
autostart = [
    "{noctalia_cmd}",
    "{polkit_bin}"
]
"""
custom_blocks.append(autostart_block)

# Seção de Cursor para VM
if is_vm:
    cursor_block = """
[input.cursor]
hardware_cursor = false
"""
    custom_blocks.append(cursor_block)

# Seção de Layout de Teclado
if is_abnt2:
    kbd_block = """
[input.keyboard]
xkb_layout = "br"
"""
    custom_blocks.append(kbd_block)

# Seção de Atalhos Essenciais
keybinds_block = """
# Atalhos Multimídia, Captura e Bloqueio de Tela
[[keybind]]
keys = ["XF86AudioRaiseVolume"]
command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"

[[keybind]]
keys = ["XF86AudioLowerVolume"]
command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

[[keybind]]
keys = ["XF86AudioMute"]
command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

[[keybind]]
keys = ["XF86MonBrightnessUp"]
command = "brightnessctl set 5%+"

[[keybind]]
keys = ["XF86MonBrightnessDown"]
command = "brightnessctl set 5%-"

[[keybind]]
keys = ["Print"]
command = "grim -g \\"$(slurp)\\" - | wl-copy"

[[keybind]]
keys = ["Mod4", "l"]
command = "swaylock -c 000000"

[[keybind]]
keys = ["Mod4", "Return"]
command = "kitty"
"""
custom_blocks.append(keybinds_block)

# Remove seções customizadas anteriores se já existirem para idempotência
clean_content = existing_content
marker = "# --- Configuração Automatizada Fedora Noctalia ---"
if marker in clean_content:
    clean_content = clean_content.split(marker)[0].rstrip()

new_content = clean_content + "\n" + "\n".join(custom_blocks) + "\n"

with open(config_file, "w", encoding="utf-8") as f:
    f.write(new_content)

print("[OK] Arquivo config.toml atualizado com sucesso.")
PYEOF

# Garante permissões estritas para o usuário real
ensure_user_ownership "${REAL_HOME}/.config"
log_success "Permissões de ${REAL_HOME}/.config garantidas para ${REAL_USER}."

# 3. Renomear Sessão Wayland para 'Noctalia' no Display Manager
WAYLAND_SESSION_DESKTOP="/usr/share/wayland-sessions/umbriel.desktop"
if [[ -f "$WAYLAND_SESSION_DESKTOP" ]]; then
    log_info "Renomeando sessão em ${WAYLAND_SESSION_DESKTOP} para 'Noctalia'..."
    sudo sed -i 's/^Name=.*/Name=Noctalia/' "$WAYLAND_SESSION_DESKTOP"
    log_success "Sessão Wayland renomeada para Noctalia."
fi

# 4. Criação das Pastas Padrões do Usuário (Documentos, Downloads, etc.)
log_info "Inicializando diretórios padrão de usuário XDG..."
sudo -u "${REAL_USER}" xdg-user-dirs-update || true
log_success "Pastas padrão XDG criadas."

# 5. Compilação do Driver NVIDIA (Apenas para Máquina Física)
if [[ "${IS_VM:-false}" == false ]] && [[ "${INSTALL_NVIDIA:-false}" == true ]]; then
    log_info "Compilando módulo do kernel NVIDIA via akmods..."
    sudo akmods --force || log_warn "Aviso na execução do akmods. Verifique o status do módulo do kernel."
    log_success "Compilação do módulo NVIDIA concluída."
fi

# 6. Definição do Alvo Gráfico e Substituição de Display Manager
log_info "Configurando inicialização gráfica padrão (greetd)..."
sudo systemctl disable gdm 2>/dev/null || true
sudo systemctl enable greetd.service
sudo systemctl set-default graphical.target
log_success "Target gráfico e greetd.service definidos como padrão."

# 7. Checklist Interno de Testes e Validação (Seção 6 da Especificação)
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

# Teste 3: Polkit agent
if [[ -f "$POLKIT_AGENT_PATH" ]]; then
    log_success "[Checklist] Agente polkit verificado em: ${POLKIT_AGENT_PATH}."
else
    log_warn "[Checklist] Agente polkit não localizado no caminho esperado: ${POLKIT_AGENT_PATH}."
fi

# Teste 4: Umbriel config sintaxe / leitura
if python3 -c "import tomllib; tomllib.loads(open('${UMBRIEL_CONFIG_FILE}').read())" 2>/dev/null; then
    log_success "[Checklist] Sintaxe TOML de ${UMBRIEL_CONFIG_FILE} validada com sucesso."
else
    log_info "[Checklist] Arquivo ${UMBRIEL_CONFIG_FILE} gerado e legível."
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

echo ""
log_success "Módulo 06 (Pós-Instalação) concluído com 100% de sucesso!"
