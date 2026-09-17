#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/04_compositor_shell.sh
# Instalação do Compositor Umbriel, Noctalia Shell, Xwayland-satellite e Portais
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

ui_section_header "MÓDULO 04: COMPOSITOR, SHELL E PORTAIS XDG"

# 1. Instalação dos Componentes Centrais da Interface Wayland
log_info "Instalando Umbriel (Nightly), Noctalia Shell e Xwayland-satellite..."
sudo dnf install -y \
    umbriel-nightly \
    noctalia \
    xwayland-satellite \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-umbriel-nightly \
    polkit \
    mate-polkit \
    gnome-keyring \
    libsecret \
    swaylock

# 2. Configuração de Prioridade dos Portais XDG para a Sessão Umbriel
log_info "Configurando integração e prioridades de portais XDG..."
sudo mkdir -p /usr/share/xdg-desktop-portal/portals
sudo mkdir -p /etc/xdg/xdg-desktop-portal

# Garante fallback ordenado: umbriel -> gtk
sudo tee /etc/xdg/xdg-desktop-portal/umbriel-portals.conf >/dev/null <<'EOF'
[preferred]
default=gtk;
org.freedesktop.impl.portal.ScreenCast=umbriel;
org.freedesktop.impl.portal.Screenshot=umbriel;
EOF

log_success "Portais XDG configurados."

# 3. Verificação do Agente de Autenticação Polkit
if [[ -f "/usr/libexec/polkit-mate-authentication-agent-1" ]] || [[ -f "/usr/lib/polkit-mate-authentication-agent-1" ]]; then
    log_success "Agente mate-polkit localizado no sistema."
else
    log_warn "Agente mate-polkit não localizado nos caminhos padrão (/usr/libexec/polkit-mate-authentication-agent-1)."
fi

log_success "Módulo 04 (Compositor e Shell) concluído com sucesso."
