#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/05_desktop_apps.sh
# Instalação de aplicações desktop, Brave Origin, codecs e Loja GNOME Software
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

# 3. Remoção do Atalho Legado WebApp do Flathub (substituído pela Loja Nativa GNOME Software)
LEGACY_FLATHUB_DESKTOP="/usr/share/applications/flathub-store.desktop"
if [[ -f "$LEGACY_FLATHUB_DESKTOP" ]]; then
    log_info "Removendo atalho legado da WebApp do Flathub (${LEGACY_FLATHUB_DESKTOP})..."
    sudo rm -f "$LEGACY_FLATHUB_DESKTOP"
    log_success "Atalho legado ${LEGACY_FLATHUB_DESKTOP} excluído com sucesso."
fi

# 4. Loja Gráfica de Aplicativos Nativa (GNOME Software e repositório Flathub)
log_info "Configurando Loja Gráfica oficial (GNOME Software) com suporte ao Flathub..."
sudo dnf install -y --allowerasing gnome-software

if command -v flatpak >/dev/null 2>&1; then
    log_info "Garantindo repositório Flathub ativo para o GNOME Software..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
fi
log_success "Loja Gráfica GNOME Software e integração Flathub configuradas."

log_success "Módulo 05 (Aplicações Desktop) concluído com sucesso."
