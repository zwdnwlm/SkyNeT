#!/bin/bash

# SkyNeT Linux One-Click Installation Script (Improved)
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/etc/SkyNeT"
DEFAULT_PORT=8383
GITHUB_REPO="HE3ndrixx/SkyNeT"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

echo -e "${CYAN}===== 🚀 SkyNeT Installer =====${NC}"

# ------------------------
# Root Check
# ------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with sudo or as root${NC}"
    exit 1
fi

# ------------------------
# Dependency Check
# ------------------------
for cmd in curl tar gzip; do
    if ! command -v $cmd &>/dev/null; then
        echo -e "${RED}Missing dependency: $cmd${NC}"
        exit 1
    fi
done

# ------------------------
# Detect Architecture
# ------------------------
case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo -e "${RED}Unsupported architecture: $(uname -m)${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Architecture: ${ARCH}${NC}"

# ------------------------
# Get Latest Version
# ------------------------
echo -e "${BLUE}Fetching latest release...${NC}"

VERSION=$(curl -s "$GITHUB_API" | grep '"tag_name"' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
VERSION=${VERSION#v}

if [ -z "$VERSION" ]; then
    echo -e "${RED}Failed to detect version${NC}"
    exit 1
fi

echo -e "${GREEN}Latest Version: v${VERSION}${NC}"

FILENAME="SkyNeT-${VERSION}-linux-${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${FILENAME}"

# ------------------------
# Download
# ------------------------
TEMP_DIR=$(mktemp -d)
TEMP_FILE="${TEMP_DIR}/${FILENAME}"

echo -e "${BLUE}Downloading...${NC}"

if ! curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
    echo -e "${RED}Download failed${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# ------------------------
# Install
# ------------------------
echo -e "${BLUE}Installing to ${INSTALL_DIR}${NC}"

pkill -f "/etc/SkyNeT/SkyNeT" 2>/dev/null || true

mkdir -p "$INSTALL_DIR"
tar -xzf "$TEMP_FILE" -C "$TEMP_DIR"

EXTRACTED_DIR=$(find "$TEMP_DIR" -type f -name "SkyNeT" -exec dirname {} \; | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}Extraction failed${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

cp -r "$EXTRACTED_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/SkyNeT"

rm -rf "$TEMP_DIR"

# ------------------------
# Create systemd Service
# ------------------------
cat > /etc/systemd/system/SkyNeT.service <<EOF
[Unit]
Description=SkyNeT Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/SkyNeT
Restart=always
WorkingDirectory=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable SkyNeT
systemctl restart SkyNeT

# ------------------------
# Status Check
# ------------------------
sleep 2
if systemctl is-active --quiet SkyNeT; then
    STATUS="${GREEN}Running${NC}"
else
    STATUS="${RED}Failed${NC}"
fi

IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$IP_ADDR" ] && IP_ADDR="localhost"

echo ""
echo -e "${CYAN}===== ✅ Installation Complete =====${NC}"
echo -e "Install Path: ${GREEN}${INSTALL_DIR}${NC}"
echo -e "Web Panel: ${GREEN}http://${IP_ADDR}:${DEFAULT_PORT}${NC}"
echo -e "Service Status: ${STATUS}"
echo -e ""
echo -e "${YELLOW}Commands:${NC}"
echo -e "Start:   systemctl start SkyNeT"
echo -e "Stop:    systemctl stop SkyNeT"
echo -e "Restart: systemctl restart SkyNeT"
echo -e "Status:  systemctl status SkyNeT"
echo ""
