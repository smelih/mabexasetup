#!/bin/bash
# ==============================================================================
# Kurumsal E-Posta Sunucusu - Otomatik Kurulum ve Markalama Betiği
# ==============================================================================

set -e

echo "[1/5] Sistem güncelleniyor ve bağımlılıklar yükleniyor..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git net-tools unzip jq ca-certificates gnupg

echo "[2/5] Docker ve Docker Compose kuruluyor..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable docker
    sudo systemctl start docker
fi

echo "[3/5] Mailcow dosyaları indiriliyor..."
sudo mkdir -p /opt/mailcow-dockerized
cd /opt/mailcow-dockerized

if [ ! -f "generate_config.sh" ]; then
    git clone https://github.com/mailcow/mailcow-dockerized .
fi

echo "[4/5] Kurumsal Markalama (White-Label) Ayarları Uygulanıyor..."

# A. Özel Panel Değişkenleri ve Logo Ayarları
mkdir -p data/web/inc/vars.local.inc.php
cat << 'PHP' > data/web/inc/vars.local.inc.php
<?php
// Kurumsal Arayüz Özelleştirmeleri
$DEFAULT_THEME = 'flatly';
$SHOW_FOOTER = false; // Footer / Telif yazılarını kaldırır

// Uygulama Başlığı (Tarayıcı Sekmesi)
$DEFAULT_TITLE = "Azra Teknik Bilişim";

// Varsayılan Dil
$DEFAULT_LANG = "tr";
PHP

# B. Custom CSS (Arayüzdeki kalan Mailcow ibarelerini ve dış bağlantıları gizler)
mkdir -p data/web/css/build
cat << 'CSS' > data/web/css/build/00-custom.css
/* Mailcow logolarını ve telif metinlerini tamamen gizleme */
.navbar-brand img[title*="mailcow"],
footer .text-muted a[href*="mailcow"],
.login-footer-links {
    display: none !important;
}

/* Kurumsal Giriş Ekranı Düzenlemeleri */
body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}
CSS

echo "[5/5] Kurulum tamamlandı!"
echo "----------------------------------------------------------------------"
echo "Şimdi yapmanız gerekenler:"
echo "1. cd /opt/mailcow-dockerized"
echo "2. ./generate_config.sh (Domain adınızı girin)"
echo "3. docker compose up -d"
echo "----------------------------------------------------------------------"
