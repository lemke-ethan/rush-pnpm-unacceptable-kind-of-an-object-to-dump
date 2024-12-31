ARG D2_VERSION=0.6.3
ARG NPM_VERSION=10.8.2
ARG NVM_VERSION=0.40.0
ARG NODE_LTS_NAME=iron
ARG GCF_VERSION=1.1.1
ARG GCF_PORT=38272
ARG PWSH_VERSION=7.4.4
ARG DOCKER_COMPOSE_VERSION=2.29.1
ARG DOCKER_SWITCH_VERSION=1.0.5

FROM mcr.microsoft.com/playwright:v1.45.3-noble AS base 
ARG DEBIAN_FRONTEND=noninteractive
ARG D2_VERSION
ARG GCF_VERSION
ARG GCF_PORT
ARG PWSH_VERSION
ARG DOCKER_COMPOSE_VERSION
ARG DOCKER_SWITCH_VERSION
RUN yes | unminimize
RUN apt-get update
# cairo, pango, and graphics libraries needed to support node-canvas building
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3 python3-setuptools ssh sqlite3 sudo locales ca-certificates gnupg lsb-release libnss3-tools upower uuid-runtime build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev  
# Install docker cli
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get -y install docker-ce-cli
# Make buildx the default builder
RUN docker buildx install
# Give container user access to docker socket (which will be bound at container run time)
RUN touch /var/run/docker.sock
RUN chgrp sudo /var/run/docker.sock
# Install docker compose v2
RUN curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
RUN chmod +x /usr/libexec/docker/cli-plugins/docker-compose
RUN curl -fL https://github.com/docker/compose-switch/releases/download/v${DOCKER_SWITCH_VERSION}/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch
RUN chmod +x /usr/local/bin/compose-switch
RUN update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99
# install packer for image building
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt update && apt install packer
# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
# install azure cli
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# install powershell
RUN mkdir -p /opt/microsoft/powershell/7
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/) && \
    curl -sSL "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${arch}.tar.gz" -o /opt/microsoft/powershell.tar.gz
RUN tar zxf /opt/microsoft/powershell.tar.gz -C /opt/microsoft/powershell/7
RUN chmod +x /opt/microsoft/powershell/7/pwsh
RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
COPY InstallPSMods.ps1 /opt/microsoft/powershell/InstallPSMods.ps1
#setup dev user
RUN useradd -ms /bin/bash -u 1002 -G sudo devuser
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /home/devuser
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
COPY .gitconfig .gitconfig
# Package to allow easy tmux/vim navigation
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN chown -R devuser /home/devuser
# used by dbus/chrome
RUN mkdir /run/user/1002
RUN sudo chmod 700 /run/user/1002
RUN sudo chown devuser /run/user/1002
USER devuser
# install D2 (https://d2lang.com/)
RUN curl -fsSL https://d2lang.com/install.sh | sh -s -- --version v${D2_VERSION} 
ENV PATH=/home/devuser/.local/lib/d2/d2-v${D2_VERSION}/bin:$PATH
RUN d2 --help
# install powershell modules
RUN pwsh /opt/microsoft/powershell/InstallPSMods.ps1
## add mfb crt to chromium
COPY /mfb-root-certificate.crt /home/devuser/server.crt
RUN mkdir -p /home/devuser/.pki/nssdb
RUN certutil -N --empty-password -d sql:/home/devuser/.pki/nssdb 
RUN certutil -A -d sql:/home/devuser/.pki/nssdb -t "C,," -n server -i server.crt
# Add public keys for well known repos
RUN mkdir -p -m 0700 ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts
COPY dotfiles/sshconfig .ssh/config
RUN az extension add --name azure-devops
RUN curl -LO https://github.com/sam-mfb/git-credential-forwarder/releases/download/v${GCF_VERSION}/git-credential-forwarder.zip
RUN unzip git-credential-forwarder.zip
COPY setup-gcf-client.sh ./setup-gcf-client.sh
RUN sudo chmod 755 ./setup-gcf-client.sh
RUN ./setup-gcf-client.sh
ENV GIT_CREDENTIAL_FORWARDER_SERVER=host.docker.internal:${GCF_PORT}
ENTRYPOINT ["bash"]

# Coc Development Image

FROM base AS coc-dev
SHELL ["/bin/bash", "--login", "-c"]
ARG NVM_VERSION
ARG NPM_VERSION
ARG NODE_LTS_NAME
# install nvm with a specified version of node; could use a node base image, but this is
# more flexible
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash \
    && . ~/.nvm/nvm.sh \
    && nvm install lts/${NODE_LTS_NAME}
RUN . ~/.nvm/nvm.sh && npm install -g npm@${NPM_VERSION}
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-tsserver coc-yaml coc-snippets coc-powershell' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.json .vim/coc-settings.json
RUN sudo chown devuser .vim/coc-settings.json
COPY dotfiles/popup_scroll.vim .vim/autoload/popup_scroll.vim
WORKDIR /home/devuser

FROM coc-dev AS ts-dev
# deps for webkit browser
RUN sudo apt-get update && sudo apt-get install -y gstreamer1.0-gl gstreamer1.0-plugins-ugly
RUN . ~/.nvm/nvm.sh && npm install -g @microsoft/rush
WORKDIR /home/devuser/git
