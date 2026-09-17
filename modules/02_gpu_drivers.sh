#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/02_gpu_drivers.sh
# Instalação dos drivers gráficos (Mesa livre ou NVIDIA proprietário com akmods)
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

ui_section_header "MÓDULO 02: DRIVERS GRÁFICOS E GPU"

# 1. Instalação dos Drivers Livres Mesa (Base universal para todas as máquinas)
log_info "Instalando pilha de aceleração gráfica aberta (Mesa DRI/Vulkan/VA-API)..."
sudo dnf install -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-va-drivers-freeworld \
    libva-utils \
    switcheroo-control

if systemctl list-unit-files | grep -q "switcheroo-control.service"; then
    sudo systemctl enable --now switcheroo-control.service || log_warn "Aviso ao ativar switcheroo-control."
fi
log_success "Drivers livres Mesa e switcheroo-control configurados."

# 2. Ramo Condicional: Drivers Proprietários NVIDIA
if [[ "${IS_VM:-false}" == true ]]; then
    log_info "Ambiente de Máquina Virtual detectado. Pulando instalação de drivers proprietários NVIDIA."
elif [[ "${INSTALL_NVIDIA:-false}" == true ]]; then
    log_warn "Iniciando instalação da pilha proprietária NVIDIA (akmod-nvidia)..."
    NVIDIA_PACKAGES="$(read_package_list "${INSTALLER_ROOT}/config/packages-nvidia.conf")"
    
    if [[ -n "$NVIDIA_PACKAGES" ]]; then
        # shellcheck disable=SC2086
        sudo dnf install -y $NVIDIA_PACKAGES
    else
        log_error "Lista config/packages-nvidia.conf está vazia ou inacessível."
        exit 1
    fi

    log_info "Habilitando serviços de gerenciamento de energia NVIDIA (RTD3)..."
    for srv in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
        if systemctl list-unit-files | grep -q "$srv"; then
            sudo systemctl enable "$srv" || log_warn "Aviso ao habilitar ${srv}."
        fi
    done
    log_success "Pilha NVIDIA instalada e serviços de energia configurados."
else
    log_info "Opção NVIDIA não selecionada. O sistema utilizará os drivers abertos Mesa."
fi

log_success "Módulo 02 (Drivers Gráficos) concluído com sucesso."
