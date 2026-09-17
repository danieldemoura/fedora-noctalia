#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/05_desktop_apps.sh
# Instalação de aplicações desktop, Brave Origin, codecs e Flathub WebApp
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

ui_section_header "MÓDULO 05: APLICAÇÕES DE USUÁRIO E MULTIMÍDIA"

# 1. Instalação dos Aplicativos do Usuário e Codecs
log_info "Sincronizando ffmpeg com repositório RPM Fusion (swap ffmpeg-free -> ffmpeg)..."
sudo dnf swap -y --allowerasing ffmpeg-free ffmpeg || true

log_info "Instalando aplicações desktop e utilitários multimídia..."
APPS_PACKAGES="$(read_package_list "${INSTALLER_ROOT}/config/packages-apps.conf")"

if [[ -n "$APPS_PACKAGES" ]]; then
    # shellcheck disable=SC2086
    sudo dnf install -y --allowerasing $APPS_PACKAGES
else
    log_warn "Lista config/packages-apps.conf está vazia ou inacessível."
fi

# 2. Instalação do Navegador Brave Origin (com contingência oficial)
log_info "Instalando navegador web Brave Origin (sem IA/crypto)..."
if ! sudo dnf install -y --allowerasing brave-origin; then
    log_warn "brave-origin não encontrado diretamente nos repositórios DNF. Disparando instalador oficial via curl..."
    if curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin sh; then
        log_success "Brave Origin instalado com sucesso via instalador oficial."
    else
        log_warn "Falha no script de instalação do Brave Origin. Tentando pacote brave-browser padrão..."
        sudo dnf install -y --allowerasing brave-browser || log_warn "Não foi possível instalar pacote do Brave via DNF."
    fi
else
    log_success "Brave Origin instalado com sucesso via DNF."
fi

# 3. Criação do Lançador WebApp do Flathub (/usr/share/applications/flathub-store.desktop)
log_info "Configurando lançador de WebApp da Loja de Aplicativos (Flathub)..."
DESKTOP_TEMPLATE="${INSTALLER_ROOT}/templates/flathub.desktop"
TARGET_DESKTOP="/usr/share/applications/flathub-store.desktop"

# Determina se usa brave-origin ou brave-browser no Exec
BRAVE_EXEC="brave-origin"
if ! command -v brave-origin >/dev/null 2>&1 && command -v brave-browser >/dev/null 2>&1; then
    BRAVE_EXEC="brave-browser"
fi

if [[ -f "$DESKTOP_TEMPLATE" ]]; then
    sudo sed "s|brave-origin|${BRAVE_EXEC}|g" "$DESKTOP_TEMPLATE" | sudo tee "$TARGET_DESKTOP" >/dev/null
else
    sudo tee "$TARGET_DESKTOP" >/dev/null <<EOF
[Desktop Entry]
Name=Loja de Aplicativos (Flathub)
Comment=Explore e instale aplicativos Flatpak
Exec=${BRAVE_EXEC} --app=https://flathub.org
Icon=package-x-generic
Terminal=false
Type=Application
Categories=System;PackageManager;
StartupNotify=true
EOF
fi

sudo chmod 644 "$TARGET_DESKTOP"
log_success "Lançador do Flathub criado em ${TARGET_DESKTOP}."

log_success "Módulo 05 (Aplicações Desktop) concluído com sucesso."
