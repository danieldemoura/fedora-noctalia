# 🌌 Fedora Noctalia: Pure Wayland Workstation

Instalador modular, limpo e automatizado para transformar uma instalação mínima do **Fedora (Netinstall / Everything)** em uma workstation gráfica moderna baseada em:

* **Compositor Wayland:** [Umbriel](https://github.com/fyralabs/umbriel) (`umbriel-nightly` via Fyra Labs / Terra)
* **Desktop Shell:** [Noctalia Shell](https://github.com/noctalia-dev/noctalia) (`noctalia` nativo C++/QtQuick)
* **Gerenciador de Login:** [Greetd](https://git.sr.ht/~kennylevinsen/greetd) + [Noctalia Greeter](https://github.com/noctalia-dev/noctalia-greeter)
* **Compatibilidade X11:** `xwayland-satellite` (rootless isolado)
* **Navegador Web:** Brave Origin (sem telemetria, IA ou criptomoedas)
* **Loja de Apps:** Flathub Store WebApp (0 MB de consumo de memória em segundo plano)

---

## 🏗️ Arquitetura Modular do Projeto

O instalador foi projetado seguindo as diretrizes de **Separação de Preocupações (SoC)** e **Idempotência**. Você pode customizar os pacotes instalados apenas editando os arquivos de texto na pasta `config/`, sem alterar nenhuma linha de código dos scripts:

```text
fedora-noctalia/
├── setup.sh                         # Ponto de entrada: validações, menu e orquestração
├── config/
│   ├── packages-base.conf           # Infraestrutura do sistema (Firmware, Áudio, Portais, XDG)
│   ├── packages-apps.conf           # Aplicações de uso diário, codecs multimídia e fontes
│   ├── packages-nvidia.conf         # Pilha proprietária de drivers e módulos NVIDIA
│   └── settings.conf                # Variáveis globais, repositórios e flags padrão
├── lib/
│   ├── ui.sh                        # Renderização do menu ANSI, banners e caixas visuais
│   ├── logger.sh                    # Registro em /tmp/fedora-noctalia-installer.log e traps de erro
│   └── utils.sh                     # Sudo keepalive, validação de não-root e permissões
├── modules/
│   ├── 00_repos.sh                  # Repositórios (Terra, RPM Fusion, Brave, Flathub)
│   ├── 01_system_hardware.sh        # Firmware, microcódigo de CPU, som e energia
│   ├── 02_gpu_drivers.sh            # Drivers Mesa abertos ou NVIDIA com akmods
│   ├── 03_display_stack.sh          # Greetd, Noctalia Greeter e integração PAM
│   ├── 04_compositor_shell.sh       # Umbriel, Noctalia Shell e Portais XDG
│   ├── 05_desktop_apps.sh           # Apps de usuário, Brave Origin e Flathub WebApp
│   └── 06_post_install.sh           # Configuração do Umbriel, atalhos, ABNT2 e validações
└── templates/
    ├── greetd.toml.template         # Modelo de configuração do Greetd
    ├── pam_greetd.template          # Configuração do Gnome Keyring no PAM
    └── flathub.desktop              # Lançador do Flathub como WebApp
```

---

## 🚀 Guia de Instalação Passo a Passo

### 1. Preparação da Mídia (Fedora Netinstall)
1. Baixe a imagem ISO do **Fedora Everything (Netinstall)** no site oficial do Fedora.
2. Grave a imagem em um pendrive com o Fedora Media Writer, Rufus ou `dd`.
3. Inicie o instalador Anaconda:
   - Defina idioma e layout do teclado.
   - Configure o particionamento do disco.
   - Na tela de **Seleção de Programas (Software Selection)**:
     - Selecione **Minimal Install** (Instalação Mínima) ou **Fedora Custom Operating System**.
     - Se estiver em **Máquina Virtual**, veja a nota abaixo sobre os *Guest Agents*.
     - Se estiver em **Máquina Física**, desmarque todos os grupos opcionais para garantir uma instalação 100% limpa.
   - Crie o seu usuário comum e marque a opção para **torná-lo administrador (`wheel`)**.

> ### 📌 Nota para Instalação em Máquinas Virtuais (VMware / VirtualBox)
> Se você optar por testar esta instalação a partir da mídia **Fedora Everything Netinstall** dentro de uma Máquina Virtual:
> * Na tela de seleção de pacotes do Anaconda, **marque a opção `Guest Agents`**.
> * **Por que isso é necessário?** O pacote instala o `open-vm-tools` (para VMware) ou módulos de integração do VirtualBox, garantindo:
>   1. Redimensionamento automático da resolução ao maximizar a janela.
>   2. Compartilhamento fluido da área de transferência (Copiar e Colar entre o hospedeiro e a VM).
>   3. Captura e liberação perfeita do ponteiro do mouse sem travamentos na janela.
> *(Em instalações físicas em notebooks ou desktops reais, mantenha `Guest Agents` desmarcado).*

---

### 2. Executando o Instalador

Após concluir a instalação básica e reiniciar no console tty com seu usuário comum:

```bash
# 1. Instale o git para clonar o repositório (ou use curl se preferir)
sudo dnf install -y git

# 2. Clone o instalador
git clone https://github.com/seu-usuario/fedora-noctalia.git
cd fedora-noctalia

# 3. Dê permissão de execução
chmod +x setup.sh modules/*.sh

# 4. Inicie o instalador como USUÁRIO COMUM (NÃO execute com sudo!)
./setup.sh
```

---

## ⚙️ Funcionalidades e Proteções Integradas

1. **Sudo Keepalive Automático:**
   O instalador valida suas credenciais uma única vez no início (`sudo -v`) e mantém um loop em segundo plano para renovar o timestamp do sudo enquanto os pacotes são baixados. Você não precisará ficar digitando senha no meio do download.

2. **Permissões Estritas no `$HOME`:**
   Todos os arquivos de configuração do usuário (`~/.config/umbriel/config.toml`, pastas XDG, etc.) são criados e atribuídos exclusivamente ao seu usuário comum (`$USER:$USER`), impedindo que pastas fiquem bloqueadas por permissões de `root`.

3. **Injeção Segura no TOML:**
   A configuração do Umbriel é manipulada através de rotinas seguras em Python, preservando comentários e backups automáticos (`.bak`), sem corromper a sintaxe do compositor.

4. **Tratamento de Secure Boot (NVIDIA):**
   Se você escolher instalar os drivers proprietários da NVIDIA, o script pausará e exibirá com destaque o alerta sobre a compilação via `akmods` e a necessidade de desativar o Secure Boot na BIOS/UEFI para evitar telas pretas.

5. **Suporte Transparente para Máquinas Virtuais:**
   Em máquinas virtuais, o script desativa automaticamente os drivers proprietários NVIDIA, ativa renderização por software (`LIBGL_ALWAYS_SOFTWARE=1`) e desativa o cursor por hardware (`hardware_cursor = false`), garantindo boot suave e mouse responsivo no VirtualBox e VMware.

---

## ⌨️ Atalhos de Teclado Padrão (Umbriel)

| Combinação de Teclas | Ação |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Abre o Terminal GPU (`kitty`) |
| <kbd>Super</kbd> + <kbd>L</kbd> | Bloqueia a tela (`swaylock`) |
| <kbd>PrintScreen</kbd> | Captura de área selecionada para a área de transferência (`grim + slurp`) |
| <kbd>XF86AudioRaiseVolume</kbd> | Aumenta o volume do áudio em 5% (`wpctl`) |
| <kbd>XF86AudioLowerVolume</kbd> | Diminui o volume do áudio em 5% (`wpctl`) |
| <kbd>XF86AudioMute</kbd> | Alterna mudo do áudio (`wpctl`) |
| <kbd>XF86MonBrightnessUp</kbd> | Aumenta o brilho da tela em 5% (`brightnessctl`) |
| <kbd>XF86MonBrightnessDown</kbd> | Diminui o brilho da tela em 5% (`brightnessctl`) |

---

## 🗓️ Compatibilidade de Versão do Fedora

> [!IMPORTANT]
> **Fedora 44 ou superior é obrigatório.** O pacote `noctalia` (e o `umbriel-nightly`) foram publicados nos repositórios oficiais do Fedora a partir da versão 44. Versões anteriores (Fedora 43 ou mais antigas) **não possuem os pacotes necessários e a instalação irá falhar**.

O instalador foi projetado para acompanhar automaticamente o ciclo de lançamentos do Fedora sem precisar de atualizações manuais:

- O endereço dos espelhos do **RPM Fusion** usa `$(rpm -E %fedora)`, que resolve para o número da versão atual em tempo de execução.
- O repositório **Terra** usa `$releasever`, resolvido nativamente pelo DNF5.
- Ambos funcionam corretamente em **Fedora 44, 45, 46…** sem qualquer alteração no código.

---

## 🔑 Gerenciamento de Credenciais (Chaveiro / Keyring)

O instalador configura automaticamente o subsistema de credenciais para que o **cofre de senhas não seja solicitado no primeiro login** (problema do diálogo *"Choose password for new keyring"*).

### O que é feito automaticamente

* O diretório `~/.local/share/keyrings/` é criado com permissão `700`.
* Um ponteiro padrão é gerado, vinculando o chaveiro ao **PAM** (login automático e integrado à senha de sessão).
* O `gnome-keyring-daemon` é inicializado via `pam_gnome_keyring.so` no arquivo PAM do `greetd`.

### Roadmap futuro (`oo7`)

Atualmente a base do Fedora 44 usa o `gnome-keyring` como provedor padrão do protocolo **Secrets Service (D-Bus)**. Uma futura migração para o `oo7` (implementação moderna em Rust) é prevista nos repositórios Fyra Labs. Quando disponível, o instalador será atualizado para substituir o provedor — **nenhuma ação é necessária por parte do usuário**.

---

## 🔍 Solução de Problemas e Auditoria

* **Log Detalhado:** O histórico completo de execução com timestamps é gravado em:
  ```bash
  cat /tmp/fedora-noctalia-installer.log
  ```
* **Reexecução de Módulos Individuais:**
  Cada módulo em `modules/` pode ser executado individualmente para manutenção ou testes:
  ```bash
  ./modules/03_display_stack.sh
  ```
* **Verificação do Display Manager:**
  ```bash
  sudo systemctl status greetd.service
  ```
