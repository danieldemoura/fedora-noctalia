#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/00_repos.sh
# Configuração e ativação de repositórios oficiais e de terceiros
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

ui_section_header "MÓDULO 00: CONFIGURAÇÃO DE REPOSITÓRIOS"

FEDORA_VER="$(rpm -E %fedora)"
log_info "Detectada distribuição: Fedora ${FEDORA_VER}"

# 1. Instalação do RPM Fusion Free e Nonfree
log_info "Configurando repositórios RPM Fusion (Free & Nonfree)..."
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
log_success "RPM Fusion configurado com sucesso."

# 2. Instalação do Repositório Terra (Fyra Labs)
if ! rpm -q terra-release &>/dev/null && [ ! -f /etc/yum.repos.d/terra.repo ]; then
    log_info "Configurando repositório Terra (Fyra Labs)..."
    sudo dnf install -y --nogpgcheck \
        --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release terra-gpg-keys
    log_success "Repositório Terra configurado com sucesso."
else
    log_info "Repositório Terra já está instalado e configurado. Pulando etapa..."
fi

# 3. Instalação do Repositório Brave Software
log_info "Configurando repositório oficial do Brave Browser..."
sudo dnf install -y dnf-plugins-core

if dnf config-manager --help 2>&1 | grep -q "addrepo"; then
    sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
elif dnf config-manager --help 2>&1 | grep -q -- "--add-repo"; then
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
else
    sudo curl -fsSL https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo -o /etc/yum.repos.d/brave-browser.repo
fi
log_success "Repositório Brave configurado com sucesso."

# 4. Habilitação do Flathub Oficial
log_info "Configurando Flatpak e repositório Flathub..."
sudo dnf install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
log_success "Repositório Flathub adicionado com sucesso."

# 5. Atualização e Sincronização dos Metadados
log_info "Atualizando índices e cache dos repositórios..."
sudo dnf upgrade --refresh -y
log_success "Módulo 00 (Repositórios) concluído com sucesso."
