#!/bin/bash

installApps()
{
    clear
    echo "We can install Docker-CE, Docker-Compose, NGinX Proxy Manager, and Portainer-CE."
    echo "Please select 'y' for each item you would like to install."
    echo "NOTE: Without Docker you cannot use Docker-Compose, NGinx Proxy Manager, or Portainer-CE."
    echo "      You also must have Docker-Compose for NGinX Proxy Manager to be installed."
    echo ""
    
    ISACT=$( (sudo systemctl is-active docker ) 2>&1 )
    ISCOMP=$( (docker compose version ) 2>&1 )

    #### Check whether Docker is installed and running
    if [[ "$ISACT" != "active" ]]; then
        read -rp "Docker-CE (y/n): " DOCK
    else
        echo "Docker appears to be installed and running."
        echo ""
    fi

    if [[ "$ISCOMP" == *"command not found"* ]]; then
        read -rp "Docker-Compose (y/n): " DCOMP
    else
        echo "Docker Compose appears to be installed."
        echo ""
    fi

    read -rp "NGinX Proxy Manager (y/n): " NPM
    read -rp "Portainer-CE (y/n): " PTAIN

    if [[ "$PTAIN" == [yY] ]]; then
        echo ""
        echo ""
        PS3="Please choose either Portainer-CE or just Portainer Agent: "
        select _ in \
            " Full Portainer-CE (Web GUI for Docker, Swarm, and Kubernetes)" \
            " Portainer Agent - Remote Agent to Connect from Portainer-CE" \
            " Nevermind -- I don't need Portainer after all."
        do
            PORT="$REPLY"
            case $REPLY in
                1) startInstall ;;
                2) startInstall ;;
                3) startInstall ;;
                *) echo "Invalid selection, please try again..." ;;
            esac
        done
    fi
    
    startInstall
}

startInstall() 
{
    clear
    echo "#######################################################"
    echo "###         Preparing for Installation              ###"
    echo "#######################################################"
    echo ""
    sleep 3s

    echo "    1. Installing System Updates... this may take a while...be patient."
    (sudo apt update && sudo apt upgrade -y) > ~/docker-script-install.log 2>&1 &
    ## Show a spinner for activity progress
    pid=$! # Process Id of the previous running command
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null
    do
        i=$(( (i+1) %4 ))
        printf "\r${spin:$i:1}"
        sleep .1
    done
    printf "\r"

    echo "    2. Install Prerequisite Packages..."
    sleep 2s

    sudo apt install -y curl wget git ca-certificates lsb-release gnupg >> ~/docker-script-install.log 2>&1

    echo "    3. Installing Docker-CE (Community Edition)..."
    sleep 2s

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io >> ~/docker-script-install.log 2>&1

    echo "      - Docker-CE version is now:"
    DOCKERV=$(docker -v)
    echo "          ${DOCKERV}"
    sleep 3s

    if [[ "$DOCK" == [yY] ]]; then
        echo ""
        echo "  - Adding the currently logged in user to the docker group..."
        sleep 2s
        sudo usermod -aG docker "${USER}" >> ~/docker-script-install.log 2>&1
        echo "  - You'll need to log out and back in to finalize the addition of your user to the docker group."
        echo ""
        sleep 3s
    fi

    if [[ "$DCOMP" == [yY] ]]; then
        echo "############################################"
        echo "######     Install Docker-Compose     ######"
        echo "############################################"
        echo ""
        echo "    1. Installing Docker Compose..."
        echo ""
        echo ""
        sleep 2s

        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K[0-9.]+')
        sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> ~/docker-script-install.log 2>&1
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

        echo "      - Docker Compose Version is now: " 
        DOCKCOMPV=$(docker-compose --version)
        echo "        ${DOCKCOMPV}"
        echo ""
        sleep 3s
    fi

    if [[ "$NPM" == [yY] ]]; then
        echo "##########################################"
        echo "###     Install NGinX Proxy Manager    ###"
        echo "##########################################"
    
        echo "    1. Pulling a default NGinX Proxy Manager docker-compose.yml file."

        mkdir -p ~/docker/nginx-proxy-manager
        cd ~/docker/nginx-proxy-manager

        cat <<EOF > docker-compose.yml
version: '3'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    environment:
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "npm"
      DB_MYSQL_NAME: "npm"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
  db:
    image: 'mariadb:latest'
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: 'npm'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm'
    volumes:
      - ./data/mysql:/var/lib/mysql
EOF

        sudo docker-compose up -d
        echo ""
        echo ""
        echo "    Navigate to your server hostname / IP address on port 81 to setup"
        echo "    NGinX Proxy Manager admin account."
        echo ""
        echo "    The default login credentials for NGinX Proxy Manager are:"
        echo "        username: admin@example.com"
        echo "        password: changeme"
        echo ""       
        sleep 3s
        cd
    fi

    if [[ "$PORT" == "1" ]]; then
        echo "########################################"
        echo "###      Installing Portainer-CE     ###"
        echo "########################################"
        echo ""
        echo "    1. Preparing to Install Portainer-CE"
        echo ""
        echo ""

        sudo docker volume create portainer_data
        sudo docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
        echo ""
        echo ""
        echo "    Navigate to your server hostname / IP address on port 9000 and create your admin account for Portainer-CE"
        echo ""
        echo ""
        echo ""
        sleep 3s
    fi

    if [[ "$PORT" == "2" ]]; then
        echo "###########################################"
        echo "###      Installing Portainer Agent     ###"
        echo "###########################################"
        echo ""
        echo "    1. Preparing to install Portainer Agent"

        sudo docker volume create portainer_data
        sudo docker run -d -p 9001:9001 --name portainer_agent --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker/volumes:/var/lib/docker/volumes portainer/agent
        echo ""
        echo ""
        echo "    From Portainer or Portainer-CE add this Agent instance via the 'Endpoints' option in the left menu."
        echo "       ####     Use the IP address of this server and port 9001"
        echo ""
        echo ""
        echo ""
        sleep 3s
    fi

    exit 1
}

echo ""
echo ""

clear

echo "Let's figure out which OS / Distro you are running."
echo ""
echo ""
echo "    From some basic information on your system, you appear to be running: "
echo "
