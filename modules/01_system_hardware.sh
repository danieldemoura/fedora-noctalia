#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/01_system_hardware.sh
# Instalação de firmwares, microcódigos, som (PipeWire), energia (Tuned) e rede
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

ui_section_header "MÓDULO 01: INFRAESTRUTURA DE HARDWARE E ÁUDIO"

# 1. Detecção e Instalação de Microcódigo de Processador
log_info "Identificando arquitetura e fabricante da CPU..."
CPU_UCODE_PKG=""
if grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
    CPU_UCODE_PKG="intel-microcode"
    log_info "Processador Intel detectado. Pacote selecionado: ${CPU_UCODE_PKG}"
elif grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
    CPU_UCODE_PKG="amd-ucode-firmware"
    log_info "Processador AMD detectado. Pacote selecionado: ${CPU_UCODE_PKG}"
else
    log_warn "Fabricante de CPU não identificado explicitamente. Prosseguindo sem microcódigo específico."
fi

if [[ -n "$CPU_UCODE_PKG" ]]; then
    sudo dnf install -y "$CPU_UCODE_PKG" || log_warn "Não foi possível instalar ${CPU_UCODE_PKG} (pode já estar incorporado)."
fi

# 2. Instalação dos Pacotes da Base do Sistema
log_info "Instalando pacotes da infraestrutura base (Áudio, Rede, Energia, Impressão, Autenticação)..."
BASE_PACKAGES="$(read_package_list "${INSTALLER_ROOT}/config/packages-base.conf")"

if [[ -n "$BASE_PACKAGES" ]]; then
    # shellcheck disable=SC2086
    sudo dnf install -y $BASE_PACKAGES
else
    log_warn "Nenhum pacote encontrado em config/packages-base.conf."
fi

# Assegura explicitamente a instalação do módulo PAM do GNOME Keyring via DNF
if ! rpm -q gnome-keyring-pam >/dev/null 2>&1; then
    log_info "Garantindo a instalação do pacote gnome-keyring-pam via DNF..."
    sudo dnf install -y gnome-keyring-pam
fi

# 3. Ativação dos Serviços Essenciais de Sistema
log_info "Habilitando e iniciando serviços de hardware e conectividade..."

# Serviço de perfis de energia moderno (Tuned)
if systemctl list-unit-files | grep -q "tuned.service"; then
    sudo systemctl enable --now tuned.service || log_warn "Aviso ao ativar tuned.service."
fi

# Conectividade e Periféricos
sudo systemctl enable --now NetworkManager.service bluetooth.service cups.socket cups.service cups-browsed.service avahi-daemon.service || true

if systemctl is-active --quiet firewalld 2>/dev/null; then
    log_info "Liberando serviços de descoberta de impressoras (mDNS e IPP) no firewall..."
    sudo firewall-cmd --add-service=mdns --add-service=ipp --add-service=ipp-client --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
fi

log_success "Módulo 01 (Hardware e Áudio) concluído com sucesso."
