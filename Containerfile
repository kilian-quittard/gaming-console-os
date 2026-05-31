# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# --- Export the SPARK Godot front-end to a self-contained Linux binary ---
# Done in a throwaway stage so neither Godot nor the templates land in the image.
FROM registry.fedoraproject.org/fedora:41 AS godot
RUN dnf install -y --setopt=install_weak_deps=False \
        unzip wget \
        mesa-libGL libX11 libXcursor libXrandr libXi libXinerama \
        libxkbcommon fontconfig freetype \
    && dnf clean all
WORKDIR /work
# Godot editor binary (used headless to export)
RUN wget -q "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip" \
    && unzip -q Godot_v4.6-stable_linux.x86_64.zip \
    && mv Godot_v4.6-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot
# Matching export templates
RUN wget -q "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz" \
    && mkdir -p /root/.local/share/godot/export_templates/4.6.stable \
    && unzip -q Godot_v4.6-stable_export_templates.tpz \
    && mv templates/* /root/.local/share/godot/export_templates/4.6.stable/
COPY frontend /work/frontend
RUN mkdir -p /out \
    && cd /work/frontend \
    && (godot --headless --import . || true) \
    && godot --headless --export-release "Linux" /out/spark-frontend.x86_64 \
    && test -f /out/spark-frontend.x86_64

# Base Image
# Gaming console base: bazzite-deck boots straight into Gamescope gaming mode.
FROM ghcr.io/ublue-os/bazzite-deck:stable

# Ship the exported front-end binary into the image.
COPY --from=godot /out/spark-frontend.x86_64 /usr/lib/spark/spark-frontend

### MODIFICATIONS
## Everything else (launcher, desktop entry, marker, packages) is done in build.sh.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
