#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

# --- SPARK OS marker ---
# Verify after rebase with: cat /usr/share/gaming-console-os-release
mkdir -p /usr/share
cat > /usr/share/gaming-console-os-release <<'EOF'
GAMING_CONSOLE_OS=1
BRAND=SPARK
BASE=bazzite-deck
PHASE=3-frontend-in-image
EOF

# --- SPARK front-end (binary copied to /usr/lib/spark by the Containerfile) ---
chmod 0755 /usr/lib/spark/spark-frontend

# Launcher on PATH
cat > /usr/bin/spark-frontend <<'EOF'
#!/bin/bash
exec /usr/lib/spark/spark-frontend "$@"
EOF
chmod 0755 /usr/bin/spark-frontend

# Desktop entry so it shows up in desktop mode (launch/test before the
# Gamescope kiosk session is wired in a later phase)
cat > /usr/share/applications/spark-frontend.desktop <<'EOF'
[Desktop Entry]
Name=SPARK
Comment=SPARK console front-end
Exec=/usr/bin/spark-frontend
Icon=applications-games
Terminal=false
Type=Application
Categories=Game;
EOF

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
