#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: lib/ui.sh
# Funções de renderização visual, formatação ANSI e avisos visuais
# ==============================================================================

# Cores e Estilos ANSI
CLR_RESET="\e[0m"
CLR_BOLD="\e[1m"
CLR_DIM="\e[2m"

CLR_CYAN="\e[1;36m"
CLR_GREEN="\e[1;32m"
CLR_YELLOW="\e[1;33m"
CLR_RED="\e[1;31m"
CLR_BLUE="\e[1;34m"
CLR_MAGENTA="\e[1;35m"
CLR_WHITE="\e[1;37m"

# Renderiza o Banner Principal do Projeto
ui_banner() {
    clear 2>/dev/null || true
    echo -e "${CLR_CYAN}"
    echo "  ██████╗ ███████╗██████╗  ██████╗ ██████╗  █████╗ "
    echo "  ██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗"
    echo "  ██████╔╝█████╗  ██║  ██║██║   ██║██████╔╝███████║"
    echo "  ██╔═══╝ ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║"
    echo "  ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║"
    echo "  ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
    echo -e "${CLR_RESET}"
    echo -e "  ${CLR_BOLD}── Umbriel + Noctalia Shell + Noctalia Greeter ──${CLR_RESET}"
    echo -e "  ${CLR_DIM}Fedora 44 Minimal | Pure Wayland | Out-of-the-box${CLR_RESET}"
    echo ""
}

# Renderiza Título de Seção
ui_section_header() {
    local title="$1"
    echo ""
    echo -e "${CLR_CYAN}┌─────────────────────────────────────────────────────────┐${CLR_RESET}"
    printf "${CLR_CYAN}│ %-55s │${CLR_RESET}\n" "$title"
    echo -e "${CLR_CYAN}└─────────────────────────────────────────────────────────┘${CLR_RESET}"
}

# Funções de Mensagem Padronizadas
log_info() {
    local msg="$1"
    echo -e "${CLR_BLUE}[INFO]${CLR_RESET} ${msg}"
    if declare -f log_to_file >/dev/null 2>&1; then
        log_to_file "INFO" "$msg"
    fi
}

log_success() {
    local msg="$1"
    echo -e "${CLR_GREEN}[OK]${CLR_RESET} ${msg}"
    if declare -f log_to_file >/dev/null 2>&1; then
        log_to_file "OK" "$msg"
    fi
}

log_warn() {
    local msg="$1"
    echo -e "${CLR_YELLOW}[AVISO]${CLR_RESET} ${msg}"
    if declare -f log_to_file >/dev/null 2>&1; then
        log_to_file "AVISO" "$msg"
    fi
}

log_error() {
    local msg="$1"
    echo -e "${CLR_RED}[ERRO]${CLR_RESET} ${msg}" >&2
    if declare -f log_to_file >/dev/null 2>&1; then
        log_to_file "ERRO" "$msg"
    fi
}

# Banner Educativo Crítico sobre Secure Boot (Obrigatório se NVIDIA = Sim)
ui_secure_boot_warning() {
    echo ""
    echo -e "${CLR_YELLOW}  ╔═════════════════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_YELLOW}  ║ ⚠️  AVISO CRÍTICO DE HARDWARE: SECURE BOOT NA BIOS                  ║${CLR_RESET}"
    echo -e "${CLR_YELLOW}  ╚═════════════════════════════════════════════════════════════════════╝${CLR_RESET}"
    echo -e "   Os drivers proprietários da NVIDIA são compilados diretamente no seu"
    echo -e "   computador pelo serviço 'akmods' para se integrarem ao kernel Linux."
    echo -e "   Com o ${CLR_BOLD}SECURE BOOT ATIVADO${CLR_RESET} na placa-mãe, o kernel do Fedora bloqueia"
    echo -e "   o carregamento desses módulos compilados localmente por falta de"
    echo -e "   assinatura digital de fábrica. Isso causará ${CLR_RED}${CLR_BOLD}TELA PRETA${CLR_RESET} no boot."
    echo ""
    echo -e "   ${CLR_BOLD}RECOMENDAÇÃO:${CLR_RESET}"
    echo -e "   Reinicie o computador, acesse a BIOS/UEFI e ${CLR_BOLD}DESATIVE o Secure Boot${CLR_RESET}"
    echo -e "   antes de reiniciar no ambiente gráfico final."
    echo -e "${CLR_YELLOW}  ───────────────────────────────────────────────────────────────────────${CLR_RESET}"
    echo -ne "  ${CLR_CYAN}Pressione [ENTER] para confirmar que está ciente e prosseguir...${CLR_RESET}"
    read -r _
    echo ""
}

# Resumo da Configuração Escolhida
ui_summary_box() {
    local env_name="$1"
    local gpu_name="$2"
    local kbd_name="$3"

    echo ""
    echo -e "${CLR_CYAN}╔═════════════════════════════════════════════════════════╗${CLR_RESET}"
    echo -e "${CLR_CYAN}║             RESUMO DAS DEFINIÇÕES DA SESSÃO             ║${CLR_RESET}"
    echo -e "${CLR_CYAN}╠═════════════════════════════════════════════════════════╣${CLR_RESET}"
    printf "${CLR_CYAN}║${CLR_RESET}  %-23s : ${CLR_BOLD}%-26s${CLR_RESET} ${CLR_CYAN}║${CLR_RESET}\n" "Ambiente de Execução" "$env_name"
    printf "${CLR_CYAN}║${CLR_RESET}  %-23s : ${CLR_BOLD}%-26s${CLR_RESET} ${CLR_CYAN}║${CLR_RESET}\n" "Driver Gráfico / GPU" "$gpu_name"
    printf "${CLR_CYAN}║${CLR_RESET}  %-23s : ${CLR_BOLD}%-26s${CLR_RESET} ${CLR_CYAN}║${CLR_RESET}\n" "Layout de Teclado" "$kbd_name"
    echo -e "${CLR_CYAN}╚═════════════════════════════════════════════════════════╝${CLR_RESET}"
    echo ""
}
