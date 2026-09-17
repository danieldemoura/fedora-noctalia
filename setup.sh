#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: setup.sh
# Ponto de entrada: checagens iniciais, menu interativo e orquestrador de módulos
# ==============================================================================
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregamento de Configurações e Bibliotecas
# shellcheck source=config/settings.conf
source "${INSTALLER_ROOT}/config/settings.conf"
# shellcheck source=lib/ui.sh
source "${INSTALLER_ROOT}/lib/ui.sh"
# shellcheck source=lib/logger.sh
source "${INSTALLER_ROOT}/lib/logger.sh"
# shellcheck source=lib/utils.sh
source "${INSTALLER_ROOT}/lib/utils.sh"

# 1. Validação de Execução (Não permitir execução direta como root)
check_not_root

# 2. Inicialização de Logs e Tratamento de Erros
log_init
enable_error_trap

# 3. Banner Visual
ui_banner

# 4. Verificação de Conectividade e Elevação Sudo com Keepalive
check_internet
start_sudo_keepalive

# 5. Menu Interativo - Pergunta 1: Seleção de Ambiente
ui_section_header "[1] SELEÇÃO DO AMBIENTE DE INSTALAÇÃO"
echo "  Por favor, informe a plataforma onde o sistema irá rodar:"
echo "    [1] Máquina Física (Bare Metal / Notebook / PC)"
echo "    [2] Máquina Virtual (VMware / VirtualBox / QEMU-KVM)"
echo ""
read -r -p "  Escolha uma opção [1-2] (Padrão: 1): " env_choice
env_choice="${env_choice:-1}"

if [[ "$env_choice" == "2" ]]; then
    IS_VM=true
    INSTALL_NVIDIA=false
    ENV_DESC="Máquina Virtual (VM)"
    GPU_DESC="Mesa / Software Emulation"
else
    IS_VM=false
    ENV_DESC="Máquina Física (Bare Metal)"
    
    # Menu Interativo - Pergunta 2: Drivers NVIDIA (apenas se máquina física)
    ui_section_header "[2] SELEÇÃO DE DRIVER DE VÍDEO (NVIDIA)"
    echo "  Seu computador possui uma placa de vídeo dedicada NVIDIA?"
    echo "  Se optar por não, os drivers livres de alta performance da Mesa serão usados."
    echo ""
    read -r -p "  Deseja instalar os drivers proprietários da NVIDIA? [s/N]: " nvidia_choice
    nvidia_choice="${nvidia_choice:-n}"
    
    if [[ "$nvidia_choice" =~ ^[sSyY]$ ]]; then
        INSTALL_NVIDIA=true
        GPU_DESC="NVIDIA Proprietário (akmods)"
        # Exibe banner educativo obrigatório sobre Secure Boot na BIOS
        ui_secure_boot_warning
    else
        INSTALL_NVIDIA=false
        GPU_DESC="Mesa Open-Source (Intel/AMD/Nouveau)"
    fi
fi

# Menu Interativo - Pergunta 3: Layout de Teclado
ui_section_header "[3] CONFIGURAÇÃO DE TECLADO"
echo "  Deseja definir o padrão Brasileiro ABNT2 (com tecla ç e acentuação br)?"
echo ""
read -r -p "  Configurar layout ABNT2 no compositor? [S/n]: " kbd_choice
kbd_choice="${kbd_choice:-s}"

if [[ "$kbd_choice" =~ ^[sSyY]$ ]]; then
    KEYBOARD_ABNT2=true
    KBD_DESC="Brasileiro (ABNT2 / br)"
else
    KEYBOARD_ABNT2=false
    KBD_DESC="Padrão do Sistema (US / Atual)"
fi

# Exporta variáveis para os módulos
export IS_VM
export INSTALL_NVIDIA
export KEYBOARD_ABNT2
export LOG_FILE

# 6. Resumo e Confirmação de Instalação
ui_summary_box "$ENV_DESC" "$GPU_DESC" "$KBD_DESC"

read -r -p "  Deseja iniciar a instalação com estas definições? [S/n]: " confirm_install
confirm_install="${confirm_install:-s}"

if [[ ! "$confirm_install" =~ ^[sSyY]$ ]]; then
    echo ""
    log_warn "Operação cancelada pelo usuário. Nenhuma alteração foi realizada no sistema."
    exit 0
fi

START_TIME=$(date +%s)
echo ""
log_info "Iniciando processo de instalação modular do Fedora Noctalia..."

# 7. Execução Sequencial dos Módulos
MODULES=(
    "00_repos.sh"
    "01_system_hardware.sh"
    "02_gpu_drivers.sh"
    "03_display_stack.sh"
    "04_compositor_shell.sh"
    "05_desktop_apps.sh"
    "06_post_install.sh"
)

for mod in "${MODULES[@]}"; do
    mod_path="${INSTALLER_ROOT}/modules/${mod}"
    if [[ -f "$mod_path" ]]; then
        chmod +x "$mod_path"
        log_info "Executando: ${mod}..."
        bash "$mod_path"
    else
        log_error "Módulo obrigatório não encontrado: ${mod_path}"
        exit 1
    fi
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))

# 8. Finalização e Sucesso
echo ""
echo -e "${CLR_GREEN}"
echo "  ╔═════════════════════════════════════════════════════════════════════╗"
echo "  ║ 🎉  INSTALAÇÃO CONCLUÍDA COM SUCESSO!                              ║"
echo "  ╚═════════════════════════════════════════════════════════════════════╝"
echo -e "${CLR_RESET}"
echo -e "  Tempo total de instalação: ${CLR_BOLD}${MINUTES}m ${SECONDS}s${CLR_RESET}"
echo -e "  Log completo da instalação: ${CLR_CYAN}${LOG_FILE}${CLR_RESET}"
echo ""

if [[ "${INSTALL_NVIDIA:-false}" == true ]] && [[ "${IS_VM:-false}" == false ]]; then
    echo -e "${CLR_YELLOW}[LEMBRETE IMPORTANTE DE HARDWARE]${CLR_RESET}"
    echo -e "  Se o seu computador possui ${CLR_BOLD}Secure Boot ativado na BIOS${CLR_RESET},"
    echo -e "  reinicie, entre na BIOS e desative-o para carregar o driver NVIDIA."
    echo ""
fi

echo -e "  Seu sistema está pronto para inicializar na interface ${CLR_BOLD}Noctalia Pure Wayland${CLR_RESET}."
echo ""
read -r -p "  Deseja reiniciar o sistema agora? [s/N]: " reboot_choice
reboot_choice="${reboot_choice:-n}"

if [[ "$reboot_choice" =~ ^[sSyY]$ ]]; then
    log_info "Reiniciando o sistema em 3 segundos..."
    sleep 3
    sudo systemctl reboot
else
    log_info "Instalação finalizada. Para iniciar a interface, execute manualmente: sudo systemctl reboot"
fi
