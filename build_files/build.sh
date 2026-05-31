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
PHASE=3-gaming-session
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

# --- SPARK gaming session: Gamescope wrapping the front-end + relaunch loop ---
# Console behaviour: if the front-end (or a launched game) exits, relaunch it.
# Nested test (from desktop): SPARK_GAMESCOPE_ARGS="-w 1280 -h 720" spark-session
# System session (physical, real GPU): default "-f" fullscreen, selectable at login.
cat > /usr/bin/spark-session <<'EOF'
#!/bin/bash
set -u
GS_ARGS="${SPARK_GAMESCOPE_ARGS:- -f}"
while true; do
    gamescope ${GS_ARGS} -- /usr/bin/spark-frontend || true
    sleep 1
done
EOF
chmod 0755 /usr/bin/spark-session

# Selectable Wayland session (NOT default — avoids black-screen on GPU-less VMs).
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/spark-gaming.desktop <<'EOF'
[Desktop Entry]
Name=SPARK Gaming
Comment=SPARK gaming session (Gamescope)
Exec=/usr/bin/spark-session
Type=Application
DesktopNames=spark-gaming
EOF

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
