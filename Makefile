SHELL = /bin/bash  # Force Make to use Bash
machine:= $(shell uname -m)
ifeq ($(machine),aarch64)
arch:=arm64
else
arch:=amd64
endif
kompose_download_link=https://github.com/kubernetes/kompose/releases/download/v1.35.0/kompose-linux-$(arch)
.PHONY: kubernetes kompose docker minikube kubeadm open_ports vscode_extention zerotier zerotier_vpn webmin nginx certbot certbot_cloudflare certbot_nginx node_exporter

kubernetes: docker
	if kubectl; \
	then \
		echo -e "\e[32mKubernetes already installed\e[0m"; \
	else \
		sudo apt-get update; \
		sudo apt-get install -y apt-transport-https ca-certificates curl gnupg; \
		curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; \
		sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list; \
		sudo apt-get update; \
		sudo apt-get install -y kubectl; \
	fi

kompose:
	if kompose version;\
	then \
		echo -e "\e[32mKompose already installed\e[0m"; \
	else \
		curl -L "$(kompose_download_link)" -o kompose; \
		chmod +x kompose; \
		sudo mv ./kompose /usr/local/bin/kompose; \
	fi

docker:
	@if command -v docker >/dev/null 2>&1; \
	then \
		echo -e "\e[32mDocker already installed\e[0m"; \
	else \
		for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $$pkg -y; done; \
		# Add Docker's official GPG key: \
		sudo apt-get update -y; \
		sudo apt-get install ca-certificates curl -y; \
		sudo install -m 0755 -d /etc/apt/keyrings; \
		sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
		sudo chmod a+r /etc/apt/keyrings/docker.asc; \
		# Add the repository to Apt sources: \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo "$$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; \
		sudo apt-get update -y; \
		sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y --fix-missing; \
		sudo groupadd docker || true; \
		sudo usermod -aG docker $$USER && newgrp docker; \
		sudo chown "$$USER":"$$USER" /home/"$$USER"/.docker -R || true; \
		sudo chmod g+rwx "$$HOME/.docker" -R || true; \
		sudo systemctl enable docker.service; \
		sudo systemctl enable containerd.service; \
		echo -e "\e[32mFor vscode extentions reboot is needed\e[0m"; \
		sudo iptables -I FORWARD -p tcp -j ACCEPT -i docker0; \
	fi

open_ports:	# make open_ports port=80
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport $(PORT)

zerotier:
	curl -s https://install.zerotier.com/ | sudo bash
	sudo zerotier-cli join $(ZEROTIER_NETWORK_ID)

zerotier_vpn:
	sudo sysctl -w net.ipv4.ip_forward=1
	sudo sysctl -p
	sudo sysctl net.ipv4.ip_forward
	# ip link show
	sudo iptables -t nat -I POSTROUTING -o "$(PHY_IFACE)" -j MASQUERADE
	sudo iptables -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -I FORWARD -i "$(PHY_IFACE)" -o "$(ZT_IFACE)" -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -I FORWARD -i "$(ZT_IFACE)" -o "$(PHY_IFACE)" -j ACCEPT
	sudo apt install iptables-persistent
	sudo bash -c iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
	sudo netfilter-persistent save

webmin:
	curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
	sudo sh webmin-setup-repo.sh
	sudo apt-get install webmin --install-recommends
	echo -e "\e[32mSetting root password to be able to login\e[0m"
	sudo passwd root

nginx:
	if nginx -v; then \
		echo -e "\e[32mNginx already installed\e[0m"; \
	else \
		sudo apt update; \
		sudo apt install -y nginx; \
	fi

certbot:
	sudo snap install core; sudo snap refresh core
	sudo snap install --classic certbot
	sudo ln -s /snap/bin/certbot /usr/bin/certbot || true
	sudo snap set certbot trust-plugin-with-root=ok

certbot_cloudflare: certbot
	if [ -f $(HOME)/.cloudflare/credentials.ini ]; then \
		echo -e "\e[32mCloudflare credentials already exist\e[0m"; \
	else \
	echo -e "\e[32mCreating .cloudflare folder\e[0m"; \
	mkdir $(HOME)/.cloudflare || true; \
	echo -e "\e[32mCreating credentials.ini file\e[0m"; \
	touch $(HOME)/.cloudflare/credentials.ini; \
	echo -e "\e[32mpasting token in file\e[0m"; \
	echo "dns_cloudflare_api_token = $(CLOUDFLARE_API_TOKEN)" > $(HOME)/.cloudflare/credentials.ini; \
	chmod 600 $(HOME)/.cloudflare/credentials.ini; \
	sudo snap install certbot-dns-cloudflare; \
	fi

certbot_nginx: certbot_cloudflare nginx
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 80
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 443
	sudo certbot certonly --dns-cloudflare --agree-tos --no-eff-email --dns-cloudflare --dns-cloudflare-credentials $(HOME)/.cloudflare/credentials.ini -d $(DOMAIN)
	sudo certbot renew --dry-run

node_exporter:
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 9100
	sudo wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-$(arch).tar.gz
	sudo tar xvfz node_exporter-1.9.0.linux-$(arch).tar.gz
	./node_exporter-1.9.0.linux-$(arch)/node_exporter
