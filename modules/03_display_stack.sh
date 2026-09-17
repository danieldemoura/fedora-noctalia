#!/usr/bin/env bash
# ==============================================================================
# fedora-noctalia: modules/03_display_stack.sh
# Instalação e configuração do Greetd, Noctalia Greeter e PAM Keyring
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

ui_section_header "MÓDULO 03: PILHA DO DISPLAY MANAGER E LOGIN"

# 1. Instalação do Greetd, Greetd-SELinux e Noctalia-Greeter
log_info "Instalando greetd, políticas SELinux e noctalia-greeter..."
sudo dnf install -y greetd greetd-selinux noctalia-greeter

# Permissões de hardware para o usuário do greetd
log_info "Configurando permissões de hardware (video, render, input) para o usuário greetd..."
sudo usermod -aG video,render,input greetd 2>/dev/null || true

# Execução do script oficial de setup do sistema do Noctalia Greeter (se presente)
if [ -f /usr/share/noctalia-greeter/setup_greeter_system.sh ]; then
    log_info "Executando setup do sistema do noctalia-greeter..."
    sudo /usr/share/noctalia-greeter/setup_greeter_system.sh || true
fi

# 2. Configuração do /etc/greetd/config.toml
log_info "Configurando /etc/greetd/config.toml..."
sudo mkdir -p /etc/greetd

SESSION_CMD="/usr/bin/noctalia-greeter-session"
if [[ "${IS_VM:-false}" == true ]]; then
    SESSION_CMD="env LIBGL_ALWAYS_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 /usr/bin/noctalia-greeter-session"
    log_info "Modo Máquina Virtual: aplicando flags de renderização por software no greeter."
fi

# Backup se já existir
backup_file "/etc/greetd/config.toml" true

# Escreve o arquivo de configuração com user = "greetd" (obrigatório no Fedora)
sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "${SESSION_CMD}"
user = "greetd"
EOF

log_success "Arquivo /etc/greetd/config.toml gerado com sucesso (user: greetd)."

# 3. Configuração do PAM (/etc/pam.d/greetd) para Desbloqueio do Gnome Keyring
log_info "Configurando integração PAM para desbloqueio automático do cofre de senhas..."
PAM_GREETD="/etc/pam.d/greetd"

if [[ -f "$PAM_GREETD" ]]; then
    backup_file "$PAM_GREETD" true
    
    # Injeta 'auth optional pam_gnome_keyring.so' se não presente
    if ! sudo grep -q "pam_gnome_keyring.so" "$PAM_GREETD"; then
        sudo awk '
            BEGIN { auth_added=0; sess_added=0 }
            /^auth/ && !auth_added {
                print
                print "auth       optional    pam_gnome_keyring.so"
                auth_added=1
                next
            }
            /^session/ && !sess_added {
                print
                print "session    optional    pam_gnome_keyring.so auto_start"
                sess_added=1
                next
            }
            { print }
        ' "${PAM_GREETD}.bak" | sudo tee "$PAM_GREETD" >/dev/null
        log_success "Diretivas do pam_gnome_keyring.so injetadas em ${PAM_GREETD}."
    else
        log_info "pam_gnome_keyring.so já configurado em ${PAM_GREETD}."
    fi
else
    # Se o arquivo não existir, cria o arquivo com configuração padrão completa
    sudo tee "$PAM_GREETD" >/dev/null <<'EOF'
#%PAM-1.0
auth     [success=done ignore=ignore default=bad] pam_selinux_permit.so
auth     substack     password-auth
auth     optional     pam_gnome_keyring.so
-auth    optional     pam_kwallet5.so

account  include      password-auth

password include      password-auth

session  required     pam_selinux.so close
session  required     pam_loginuid.so
session  required     pam_selinux.so open
session  optional     pam_keyinit.so force revoke
session  include      password-auth
session  optional     pam_gnome_keyring.so auto_start
-session optional     pam_kwallet5.so auto_start
EOF
    log_success "Arquivo ${PAM_GREETD} criado com suporte ao pam_gnome_keyring."
fi

log_success "Módulo 03 (Display Stack) concluído com sucesso."
