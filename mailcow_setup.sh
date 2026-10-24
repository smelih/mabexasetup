#!/bin/bash

# Hata durumunda betiği durdurunuz
set -e

echo "=================================================="
echo "    Mailcow Otomatik Kurulum ve Yapılandırma     "
echo "=================================================="

# 1. Kullanıcıdan Gerekli Bilgileri Al
read -p "Mail Subdomain (Örn: mail.domain.com.tr): " MAIL_DOMAIN
read -p "Ana Domain (Örn: domain.com.tr): " BASE_DOMAIN
read -p "Cloudflare API Token: " CF_TOKEN

if [ -z "$MAIL_DOMAIN" ] || [ -z "$BASE_DOMAIN" ] || [ -z "$CF_TOKEN" ]; then
    echo "[!] HATA: Tüm alanları doldurmanız gerekmektedir. İşlem iptal edildi."
    exit 1
fi

echo -e "\n[1/5] Sistem Güncelleniyor ve Docker Kuruluyor..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git certbot python3-certbot-dns-cloudflare apt-transport-https ca-certificates gnupg lsb-release

# Docker Keyring ve Repo Ekleme
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl start docker
sudo systemctl enable docker

echo -e "\n[2/5] Cloudflare DNS-01 ile SSL Sertifikası Alınıyor..."
mkdir -p ~/.secrets/certbot
cat <<EOF > ~/.secrets/certbot/cloudflare.ini
dns_cloudflare_api_token = $CF_TOKEN
EOF

chmod 600 ~/.secrets/certbot/cloudflare.ini

# Certbot ile SSL Alma (DNS yayılması için bekleme süresi 30sn yapıldı)
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d "$MAIL_DOMAIN" \
  -d "$BASE_DOMAIN" \
  --preferred-challenges dns \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email || true

echo -e "\n[3/5] Mailcow Reposu Çekiliyor..."
sudo mkdir -p /opt/mailcow-dockerized
if [ -d "/opt/mailcow-dockerized/.git" ]; then
    echo "Dizin zaten mevcut, güncelleniyor..."
    cd /opt/mailcow-dockerized && sudo git pull
else
    sudo git clone https://github.com/smelih/azramail-dockerized.git /opt/mailcow-dockerized
    cd /opt/mailcow-dockerized
fi

echo -e "\n[4/5] Mailcow Config Oluşturuluyor..."
./generate_config.sh

echo -e "\n[5/5] Sertifikalar Mailcow'a Giydiriliyor ve Konteynerlar Başlatılıyor..."
if [ -f "/etc/letsencrypt/live/$MAIL_DOMAIN/fullchain.pem" ]; then
    sudo cp /etc/letsencrypt/live/"$MAIL_DOMAIN"/fullchain.pem /opt/mailcow-dockerized/data/assets/ssl/cert.pem
    sudo cp /etc/letsencrypt/live/"$MAIL_DOMAIN"/privkey.pem /opt/mailcow-dockerized/data/assets/ssl/key.pem

    sudo chmod 644 /opt/mailcow-dockerized/data/assets/ssl/cert.pem
    sudo chmod 600 /opt/mailcow-dockerized/data/assets/ssl/key.pem

    # mailcow.conf içinde SKIP_LETS_ENCRYPT ayarını 'y' yap
    if grep -q "SKIP_LETS_ENCRYPT=" /opt/mailcow-dockerized/mailcow.conf; then
        sudo sed -i 's/SKIP_LETS_ENCRYPT=.*/SKIP_LETS_ENCRYPT=y/' /opt/mailcow-dockerized/mailcow.conf
    else
        echo "SKIP_LETS_ENCRYPT=y" | sudo tee -a /opt/mailcow-dockerized/mailcow.conf
    fi
else
    echo "[!] UYARI: SSL Sertifikası alınamadı, varsayılan Mailcow SSL ayarlarıyla devam ediliyor."
fi

sudo docker compose pull
sudo docker compose up -d

echo "=================================================="
echo "          KURULUM BAŞARIYLA TAMAMLANDI!           "
echo "=================================================="
