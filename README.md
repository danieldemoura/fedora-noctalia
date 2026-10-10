# 🌌 Fedora Noctalia: Pure Wayland Workstation

Instalador modular, limpo e automatizado para transformar uma instalação mínima do **Fedora (Netinstall / Everything)** em uma workstation gráfica moderna baseada em:

* **Compositor Wayland:** [Umbriel](https://github.com/fyralabs/umbriel) (`umbriel-nightly` via Fyra Labs / Terra)
* **Desktop Shell:** [Noctalia Shell](https://github.com/noctalia-dev/noctalia) (`noctalia` nativo C++/QtQuick)
* **Gerenciador de Login:** [Greetd](https://git.sr.ht/~kennylevinsen/greetd) + [Noctalia Greeter](https://github.com/noctalia-dev/noctalia-greeter)
* **Emulador de Terminal & CLI:** [Kitty](https://sw.kovidgoyal.net/kitty/) (acelerado por GPU) + `fastfetch` (informações de sistema)
* **Compatibilidade X11:** `xwayland-satellite` (rootless isolado)
* **Navegador Web:** Brave Origin (sem telemetria, IA ou criptomoedas)
* **Loja de Apps:** GNOME Software (Loja gráfica nativa com integração ao Flathub e atualizações do sistema)
* **Reprodutor de Vídeo:** Cine (`io.github.diegopvlk.Cine` via Flatpak)

---

## 🏗️ Arquitetura Modular do Projeto

O instalador foi projetado seguindo as diretrizes de **Separação de Preocupações (SoC)** e **Idempotência**. Você pode customizar os pacotes instalados apenas editando os arquivos de texto na pasta `config/`, sem alterar nenhuma linha de código dos scripts:

```text
fedora-noctalia/
├── setup.sh                         # Ponto de entrada: validações, menu e orquestração
├── config/
│   ├── packages-base.conf           # Infraestrutura do sistema (Firmware, Áudio, Portais, XDG)
│   ├── packages-apps.conf           # Aplicações de uso diário, codecs multimídia e fontes
│   ├── packages-flatpak.conf        # Lista declarativa de aplicativos Flatpak do Flathub
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
│   ├── 05_desktop_apps.sh           # Apps de usuário, Brave Origin e Loja GNOME Software
│   └── 06_post_install.sh           # Configuração do Umbriel, atalhos, ABNT2 e validações
└── templates/
    ├── greetd.toml.template         # Modelo de configuração do Greetd
    └── pam_greetd.template          # Configuração do Gnome Keyring no PAM
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

6. **Gerenciamento de Armazenamento e Montagem Automática (NTFS / USB / Discos Internos):**
   Suporte nativo e automático a discos rígidos internos, partições do Windows (NTFS) e dispositivos de armazenamento USB removíveis via `udisks2` e `ntfs-3g`, funcionando diretamente pelo gerenciador de arquivos (Nautilus) e GNOME Discos sem necessidade de montagem manual no terminal via `mount`.

---

## 📦 Modularidade de Aplicativos Flatpak

O projeto segue rigorosamente o princípio de **Separação de Preocupações (SoC)** e arquitetura declarativa. Nenhuma aplicação de usuário em sandbox fica hardcoded nos scripts shell:
* **Lista Declarativa Dedicada:** Todos os aplicativos Flatpak são gerenciados através do arquivo `config/packages-flatpak.conf`.
* **Facilidade de Expansão:** Para adicionar novos aplicativos Flatpak (por exemplo: Spotify, Discord, OBS Studio, Steam), basta inserir o ID do pacote (ex: `com.spotify.Client`, `com.discordapp.Discord`) em uma nova linha desse arquivo.
* **Zero Alteração em Código:** O instalador detecta e instala dinamicamente todas as entradas listadas via Flathub, sem que você precise mexer em nenhum script do repositório.

---

## 🖨️ Suporte Universal de Hardware e Impressão

### Suporte Universal de Hardware (Wi-Fi e Bluetooth)
Em instalações mínimas (Netinstall), o Fedora fraciona os pacotes de firmware por fabricante. O instalador adota o metagrupo oficial **`@hardware-support`** em conjunto com o daemon **`wpa_supplicant`**, garantindo:
* Reconhecimento imediato de qualquer adaptador Wi-Fi e Bluetooth (Intel, AMD, Realtek, Broadcom, MediaTek, Atheros).
* Negociação transparente de redes Wi-Fi com segurança WPA/WPA2/WPA3 sem necessidade de depuração de drivers proprietários.

### Suporte Universal de Impressão (Plug-and-Play e Wi-Fi)
O sistema vem totalmente preparado para operar com qualquer fabricante de impressora (HP, Epson, Brother, Canon) em ambiente Wayland puro:
* **Detecção Automática na Rede:** Configura o metagrupo `@printing`, `cups-browsed` e `avahi-daemon`, liberando automaticamente as portas mDNS e IPP no firewall (`firewalld`). Dispositivos Wi-Fi modernos que utilizam os protocolos IPP Everywhere e Mopria são detectados na rede local de forma instantânea em navegadores e caixas de diálogo do sistema, sem necessidade de drivers manuais.
* **Plug-and-Play Instantâneo via USB:** Através do `system-config-printer-udev`, plugar o cabo USB de uma impressora gera automaticamente a fila correspondente no CUPS.
* **Compatibilidade Estendida:** Inclui suporte nativo para impressoras HP via `hplip` e impressoras Brother legadas via `printer-driver-brlaser`.

---

## ⌨️ Atalhos de Teclado Nativos e Controle (Umbriel & Noctalia)

O Umbriel vem com um conjunto completo de atalhos nativos de fábrica para gerenciamento de janelas e navegação, enquanto o controle de volume, brilho e rede é integrado visualmente no Noctalia Shell:

| Combinação de Teclas | Ação |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Abre o Terminal GPU (`kitty`) |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Fecha a janela em foco |
| <kbd>Super</kbd> + <kbd>1</kbd> a <kbd>9</kbd> | Alterna entre as áreas de trabalho |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> a <kbd>9</kbd> | Move a janela para a área de trabalho selecionada |
| <kbd>Super</kbd> + <kbd>Espaço</kbd> / Botão Superior | Abre o Lançador de Aplicativos (Noctalia Shell) |
| *Painel Noctalia Shell* | Controle visual de Volume, Brilho, Wi-Fi, Bluetooth e Bateria |

---

## 🗓️ Compatibilidade de Versão do Fedora

> [!IMPORTANT]
> **Fedora 44 ou superior é obrigatório.** O pacote `noctalia` (e o `umbriel-nightly`) foram publicados nos repositórios oficiais do Fedora a partir da versão 44. Versões anteriores (Fedora 43 ou mais antigas) **não possuem os pacotes necessários e a instalação irá falhar**.

O instalador foi projetado para acompanhar automaticamente o ciclo de lançamentos do Fedora sem precisar de atualizações manuais:

- O endereço dos espelhos do **RPM Fusion** usa `$(rpm -E %fedora)`, que resolve para o número da versão atual em tempo de execução.
- O repositório **Terra** usa `$releasever`, resolvido nativamente pelo DNF5.
- Ambos funcionam corretamente em **Fedora 44, 45, 46…** sem qualquer alteração no código.

---

## 🔐 Autenticação Gráfica (Agente Polkit no Noctalia Shell)

### O que é e para que serve
O **Agente Polkit** é o componente responsável por desenhar a janela na tela solicitando a senha de administrador quando aplicativos gráficos realizam ações privilegiadas (como formatar pendrives no GNOME Discos, gerenciar partições ou modificar configurações avançadas do sistema).

### Por que o instalador não inclui o KDE Polkit
O instalador removeu o pacote `polkit-kde` para manter o sistema limpo, leve e sem dependências pesadas do KDE Frameworks 6 (KF6). O Noctalia Shell possui um agente Polkit nativo perfeitamente integrado à sua interface Wayland em QML/QtQuick.

### Como ativar nativamente pela interface gráfica do Noctalia (Passo a Passo Oficial)

> ⚠️ **Recomendação Pós-Instalação:** Para que aplicativos gráficos solicitem sua senha com a interface nativa do sistema:
> 1. Abra a **Central de Configurações do Noctalia** (pelo lançador de aplicativos ou atalho no painel).
> 2. No menu lateral esquerdo, clique em **Segurança** 🛡️.
> 3. Na seção/aba **Autenticação**, localize a opção **Agente Polkit** (*"Habilitar o agente de autenticação integrado"*).
> 4. Ative a chave seletora para **Ligado (ON)**.
> 
> Pronto! A partir desse momento, qualquer aplicativo gráfico que exigir privilégios de root abrirá a janela de autenticação nativa, elegante e com o mesmo tema do seu desktop.

---

## 🔑 Gerenciamento de Credenciais (Chaveiro / Keyring)

O instalador configura automaticamente o subsistema de credenciais para garantir uma experiência de autenticação transparente, silenciosa e segura — eliminando por completo diálogos intrusivos como *"An application wants access to the keyring 'Default Keyring', but it is locked"*, de forma idêntica à de distribuições desktop completas (GNOME/KDE).

### Como a integração funciona

* **Módulo PAM (`gnome-keyring-pam`):** No Fedora, o módulo `pam_gnome_keyring.so` reside em um pacote separado do daemon. Ele é instalado obrigatoriamente para interceptar as credenciais digitadas no Greetd e desbloquear silenciosamente o cofre canônico `login.keyring` no início da sessão gráfica.
* **Ponteiro Canônico (`default` -> `login`):** Aplicações (como Brave, navegadores Chromium, Git Credential Manager e Wi-Fi) solicitam via D-Bus (`org.freedesktop.Secrets`) o chaveiro configurado como `default`. Sem o arquivo ponteiro, o daemon assume ausência de padrão e tenta criar `Default_Keyring.keyring`, gerando pedidos incessantes de senha a cada boot. Com `~/.local/share/keyrings/default` pré-configurado contendo `login` (permissão `600`, diretório `700`), todas as aplicações são direcionadas ao chaveiro que o PAM já destrancou na inicialização.
* **Limpeza Defensiva e Idempotência:** Arquivos órfãos ou corrompidos gerados fora do PAM são removidos preventivamente, garantindo total estabilidade mesmo em reexecuções do instalador.

### Roadmap futuro (`oo7`)

Atualmente a base do Fedora 44 usa o `gnome-keyring` como provedor padrão do protocolo **Secrets Service (D-Bus)**. Uma futura migração para o `oo7` (implementação moderna em Rust) é prevista nos repositórios Fyra Labs. Quando disponível, o instalador será atualizado para substituir o provedor — **nenhuma ação é necessária por parte do usuário**.

---

## 🛡️ Opcional: Firewall Gráfico de Aplicações (Portmaster)

Se você deseja um firewall com interface gráfica moderna e simples para monitorar e definir regras de conexão por aplicativo:

1. Instale as dependências da interface gráfica:
   ```bash
   sudo dnf install -y libayatana-appindicator-gtk3 webkit2gtk4.1
   ```

2. Baixe o pacote RPM oficial e mais recente no site:
   Acesse [https://safing.io/](https://safing.io/) e faça o download do instalador `.rpm` para Linux.

3. Abra o terminal na pasta onde o arquivo foi baixado (por padrão, Downloads) e faça a instalação local:
   ```bash
   cd ~/Downloads
   sudo dnf install -y ./Portmaster*.rpm
   ```

4. Habilite e inicie o serviço em segundo plano do firewall:
   ```bash
   sudo systemctl enable --now portmaster.service
   ```

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
* **Validação do Compositor Umbriel:**
  Verifique a sintaxe e a integridade do arquivo `~/.config/umbriel/config.toml` executando o validador oficial:
  ```bash
  umbriel config validate
  ```


