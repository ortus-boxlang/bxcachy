# Real Arch Linux test image. Non-root user with passwordless sudo, mirroring a
# CachyOS workstation account. Nothing is mocked here.
FROM archlinux:latest
# Optional: extra CA (for TLS-intercepting proxies). run.sh copies EXTRA_CA_BUNDLE
# to extra-ca.crt; the bracket glob keeps COPY valid when the file is absent.
COPY extra-ca.cr[t] /tmp/
RUN if [ -f /tmp/extra-ca.crt ]; then cp /tmp/extra-ca.crt /etc/ca-certificates/trust-source/anchors/ && update-ca-trust; fi
RUN pacman -Syu --noconfirm --needed sudo base-devel git curl unzip bash jdk21-openjdk rustup \
 && useradd -m -G wheel dev \
 && echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel \
 && chmod 0440 /etc/sudoers.d/wheel
USER dev
ENV HOME=/home/dev
WORKDIR /home/dev
