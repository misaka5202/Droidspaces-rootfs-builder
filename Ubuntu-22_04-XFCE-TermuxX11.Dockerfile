# Ubuntu-22_04-XFCE-TermuxX11.Dockerfile
# Stage 1: Build and customize the rootfs for development (Ubuntu 22.04 + XFCE, for Termux:X11)
ARG TARGETPLATFORM
FROM ubuntu:22.04 AS customizer

#######################################################
# 构建参数：均带有默认值，可在构建时通过 --build-arg 覆盖
ARG PulseAudio=socket
ARG ENABLE_zh_tz_ARG=false
ARG ENABLE_binfmt_ARG=false
ARG ENABLE_yj_ARG=false
ARG ENABLE_mesa_ARG=true
ARG ENABLE_kfgj_ARG=false
ARG ENABLE_zip_ARG=true
ARG ENABLE_docker_ARG=false
ARG ENABLE_srf_ARG=true
ARG ENABLE_tmoe_ARG=false
ARG ENABLE_nosnap_ARG=true
ARG USERNAME=droid
######################################################

ENV DEBIAN_FRONTEND=noninteractive

# 启用 APT 并行连接、HTTP(S) pipeline 和下载重试
RUN printf '%s\n' \
    'Acquire::Queue-Mode "host";' \
    'Acquire::http::Pipeline-Depth "10";' \
    'Acquire::https::Pipeline-Depth "10";' \
    'Acquire::Retries "3";' \
    > /etc/apt/apt.conf.d/99parallel-downloads

# 优先复制自定义脚本
COPY scripts/download-firmware /usr/local/bin/
COPY scripts/nosnap.sh /usr/local/sbin/nosnap
COPY scripts/xfce-start /usr/local/bin/xfce-start

# 将自定义的 bashrc 脚本复制到根文件系统的 profile 目录
COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh

# 赋予相关脚本可执行权限
RUN chmod +x /usr/local/bin/download-firmware /usr/local/sbin/nosnap \
    /etc/profile.d/ds-aliases.sh /usr/local/bin/xfce-start

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl wget gnupg software-properties-common && \
    if [ "$ENABLE_nosnap_ARG" = "true" ]; then \
        echo "--> [开启] nosnap: 正在预配置并移除 Ubuntu Snap..." && \
        bash /usr/local/sbin/nosnap; \
    else \
        echo "--> [跳过] 未开启 nosnap"; \
    fi && \
    rm -f /usr/local/sbin/nosnap

# 添加 PPA（fastfetch / Firefox ESR），若源不可用则不阻断构建
RUN add-apt-repository -y ppa:zhangsongcui3371/fastfetch || true && \
    add-apt-repository -y ppa:mozillateam/ppa || true && \
    apt-get update

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # 核心工具组件
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates locales bash-completion \
    udev dbus systemd-sysv systemd-resolved \
    # 基础开发/编辑工具
    git nano vim sudo htop \
    # 网络与 SSH 工具
    openssh-server net-tools iptables iputils-ping iproute2 dnsutils usbutils pciutils lsof psmisc iw \
    # 系统监控 & 日志
    procps logrotate \
    # 核心内核模块支持
    kmod tzdata \
    ############################################## XFCE 桌面支持 ################################################
    # 解除底层系统对中文等翻译文件(.mo)的剔除规则，防止安装桌面时丢包
    && sed -i 's|^path-exclude=/usr/share/locale/\*/LC_MESSAGES/\*.mo|#&|' /etc/dpkg/dpkg.cfg.d/excludes 2>/dev/null || true && \
    apt-get install -y --no-install-recommends \
    # 音频（Termux:X11 音频转发依赖 PulseAudio）
    pulseaudio pulseaudio-utils pavucontrol \
    # XFCE 桌面环境及常用组件
    xfce4 desktop-base xfce4-terminal xfce4-session xscreensaver xfce4-goodies \
    xubuntu-wallpapers xfce4-taskmanager mousepad galculator ristretto xfce4-screenshooter \
    catfish xcursor-themes dmz-cursor-theme xfce4-clipman-plugin xinit xorg dbus-x11 at-spi2-core tumbler \
    # 图标 / 主题
    adwaita-icon-theme hicolor-icon-theme gnome-icon-theme tango-icon-theme \
    gtk2-engines-murrine gtk2-engines-pixbuf arc-theme numix-gtk-theme papirus-icon-theme greybird-gtk-theme \
    # 常用字体
    fonts-dejavu-core fonts-liberation fonts-liberation2 fonts-noto-core fonts-ubuntu \
    # 文件管理器 / GUI 工具
    thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin gvfs gvfs-backends gvfs-fuse \
    x11-xserver-utils x11-utils xclip xsel xfwm4 xfconf zenity notification-daemon \
    xdg-user-dirs mesa-utils vulkan-tools \
    # 浏览器（来自 mozillateam PPA，若失败可忽略）
    firefox-esr \
    # PolicyKit
    policykit-1 && \
    ######################################################################################################
    # 输入法 fcitx5 (可选)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-qt5; \
    fi && \
    if [ "$ENABLE_srf_ARG" = "true" ] && [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends fcitx5-chinese-addons; \
    fi && \
    # 中文语言与字体支持 (可选)
    if [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        fonts-noto-cjk fonts-noto-color-emoji language-pack-zh-hans language-pack-gnome-zh-hans; \
    fi && \
    ## 开发工具集成 (可选)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        build-essential gcc g++ gdb make cmake autoconf automake libtool pkg-config \
        clang llvm valgrind strace ltrace python3 python3-pip python3-dev python3-venv python-is-python3; \
    fi && \
    ## 压缩工具扩展 (可选)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        zip unzip p7zip-full bzip2 xz-utils tar gzip; \
    fi && \
    ## docker (可选)
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends docker.io docker-compose-v2; \
    fi && \
    ## 集成 tmoe (可选)
    if [ "$ENABLE_tmoe_ARG" = "true" ]; then \
        git clone --depth=1 https://github.com/2moe/tmoe-linux.git /usr/local/etc/tmoe-linux/git && \
        ln -sf /usr/local/etc/tmoe-linux/git/debian.sh /usr/local/bin/tmoe && \
        chmod -R 755 /usr/local/etc/tmoe-linux; \
    fi && \
    apt-get purge -y gdm3 gnome-session gnome-shell whoopsie || true && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 强制配置使用 iptables-legacy（这是兼容 Android 内核的硬性要求）
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# 配置 locale / 时区 / SSH / 用户
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && \
    if [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        export DEBIAN_FRONTEND=noninteractive && \
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "Asia/Shanghai" > /etc/timezone && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i '/zh_CN.UTF-8/s/^# //' /etc/locale.gen && \
        locale-gen && \
        update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8; \
    else \
        locale-gen && \
        update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    fi && \
    # 配置 SSH 服务（禁用 root 密码登录，但允许常规密码认证）
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # 创建默认用户目录
    xdg-user-dirs-update || true && \
    # 移除默认的 ubuntu 用户（如果存在）
    deluser --remove-home ubuntu || true && \
    useradd -m -s /bin/bash ${USERNAME} && echo "${USERNAME}:1234" | chpasswd && \
    usermod -a -G sudo ${USERNAME} && \
    systemctl enable ssh

# Termux:X11 环境变量：默认 DISPLAY=:5
RUN cat <<'EOF' > /etc/environment
XCURSOR_SIZE=48
DISPLAY=:5
EOF

# PulseAudio 音频转发选择：unix socket / tcp / 关闭
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    else \
        echo "--> [跳过] PulseAudio 音频转发未启用"; \
    fi

# 输入法开机自启动 + Snapdragon GPU 环境变量
RUN <<'EOF_RUN'
if [ "$ENABLE_srf_ARG" = "true" ]; then
    mkdir -p /home/${USERNAME}/.config/autostart
    cat <<'EOF' > /home/${USERNAME}/.config/autostart/fcitx5.desktop
[Desktop Entry]
Name=Fcitx5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5 -d
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
NoDisplay=true
EOF
    cat <<'EOF' >> /etc/environment
XMODIFIERS=@im=fcitx5
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
SDL_IM_MODULE=fcitx5
GLFW_IM_MODULE=fcitx
EOF
fi

if [ "$ENABLE_mesa_ARG" = "true" ]; then
    cat <<'EOF' >> /etc/environment
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TU_DEBUG=noconform
EOF
fi

echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/${USERNAME}/.bashrc
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}
EOF_RUN

# 修复 xfwm4 的 vblank_mode，防止在高通(Turnip) GPU 上合成器卡死
# XML 格式无法用简单 sed 替换 value="auto"，故预置完整的 xfwm4.xml
COPY scripts/xfwm4.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
COPY scripts/xfwm4.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
RUN mkdir -p /home/${USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml && \
    cp /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml \
       /home/${USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config && \
    if [ -f /usr/share/xfwm4/defaults ]; then \
        if grep -q '^vblank_mode=' /usr/share/xfwm4/defaults; then \
            sed -i 's/^vblank_mode=.*/vblank_mode=off/' /usr/share/xfwm4/defaults; \
        else \
            echo 'vblank_mode=off' >> /usr/share/xfwm4/defaults; \
        fi; \
    fi

# XFCE 开机自启动服务：仅在 Termux:X11 (DISPLAY=:5 的 socket) 就绪时启动
RUN cat > /etc/systemd/system/xfce-autostart.service << 'EOF'
[Unit]
Description=XFCE Autostart (Termux:X11)
After=graphical.target

[Service]
Type=simple
User=root
ExecCondition=/bin/sh -c "grep -q 'enable_termux_x11=1' /run/droidspaces/container.config"
ExecCondition=/bin/sh -c "test -S /tmp/.X11-unix/X5"
ExecStart=/usr/local/bin/xfce-start
Restart=on-failure

[Install]
WantedBy=graphical.target
EOF

RUN chmod 644 /etc/systemd/system/xfce-autostart.service && \
    mkdir -p /etc/systemd/system/graphical.target.wants && \
    ln -sf /etc/systemd/system/xfce-autostart.service /etc/systemd/system/graphical.target.wants/xfce-autostart.service

# 更新图标与字体缓存
RUN gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true && \
    gtk-update-icon-cache -f /usr/share/icons/Adwaita 2>/dev/null || true && \
    gtk-update-icon-cache -f /usr/share/icons/Papirus 2>/dev/null || true && \
    gtk-update-icon-cache -f /usr/share/icons/Tango 2>/dev/null || true && \
    fc-cache -fv

# 修复容器内的 DHCP 网络服务配置
RUN mkdir -p /etc/systemd/network && \
    cat <<'EOF' > /etc/systemd/network/10-eth-dhcp.network
[Match]
Name=eth*

[Network]
DHCP=yes
IPv6AcceptRA=yes

[DHCPv4]
UseDNS=yes
UseDomains=yes
RouteMetric=100
EOF

# 应用 Android 运行环境兼容性修复（重点针对 Systemd 和 Udev）
RUN <<'EOF_RUN'

# --- 1. 常规兼容性修复 ---
# 建立 Android 网络权限组
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group  || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

# 检查并创建 droidspaces-gpu 组（Snapdragon GPU 设备节点访问）
getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu

# 为 root 及默认用户赋予访问 Android 硬件、网络与 GPU 的权限组
usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,sudo,droidspaces-gpu ${USERNAME} || true

# 将 _apt 的主用户组改为 aid_inet，确保 apt 包管理器在 Android 环境下可以正常联网
grep -q '^_apt:' /etc/passwd && usermod -g aid_inet _apt || true

# 确保未来通过 adduser 创建的所有新用户，都会被默认加入这些 Android 硬件与网络组
if [ -f /etc/adduser.conf ]; then
    sed -i '/^EXTRA_GROUPS=/d; /^ADD_EXTRA_GROUPS=/d' /etc/adduser.conf
    echo 'ADD_EXTRA_GROUPS=1' >> /etc/adduser.conf
    echo 'EXTRA_GROUPS="aid_inet aid_net_raw input video tty"' >> /etc/adduser.conf
fi

# --- 2. 针对 Systemd 的特定修复 ---
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

cat >> /etc/systemd/journald.conf << 'EOT'
[Journal]
ReadKMsg=no
Audit=no
Storage=volatile
EOT

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/ds-logging.conf << 'EOT'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=200M
MaxRetentionSec=7day
MaxLevelStore=info
EOT

mkdir -p /etc/systemd/system/multi-user.target.wants
GUEST_SYSTEMD_PATH="/lib/systemd/system"

if [ -f "$GUEST_SYSTEMD_PATH/dbus.service" ]; then
    ln -sf "$GUEST_SYSTEMD_PATH/dbus.service" "/etc/systemd/system/multi-user.target.wants/dbus.service"
fi

if [ "$ENABLE_yj_ARG" = "true" ]; then
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        if [ -f "$GUEST_SYSTEMD_PATH/$service" ]; then
            ln -sf "$GUEST_SYSTEMD_PATH/$service" "/etc/systemd/system/multi-user.target.wants/$service"
        fi
    done
else
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        ln -sf /dev/null "/etc/systemd/system/$service"
    done
fi

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

for unit in NetworkManager.service dhcpcd.service systemd-resolved.service systemd-networkd.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-netmode-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -qE 'net_mode=(nat|gateway)' /run/droidspaces/container.config"
EOF
    fi
done

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-hwaccess-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -q 'enable_hw_access=1' /run/droidspaces/container.config"
EOF
    fi
done

if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi

echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN

# Snapdragon GPU 支持：安装来自 mesa-for-android-container 的高通 GPU 驱动/配置 (可选)
COPY scripts/install-mesa /usr/local/bin/install-mesa
RUN chmod +x /usr/local/bin/install-mesa && \
    if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        echo "--> [开启] 正在安装 Snapdragon (Turnip/Mesa) GPU 驱动..." && \
        /usr/local/bin/install-mesa; \
    else \
        echo "--> [跳过] 未开启 Mesa/Snapdragon GPU 驱动安装"; \
    fi && \
    rm -f /usr/local/bin/install-mesa

# 二进制格式支持 (binfmt / QEMU，用于跨架构，可选)
COPY scripts/binfmt/qemu-binfmt-register.sh /usr/local/bin/
COPY scripts/binfmt/qemu-binfmt-register.service /etc/systemd/system/
RUN if [ "$ENABLE_binfmt_ARG" = "true" ]; then \
        chmod +x /usr/local/bin/qemu-binfmt-register.sh && \
        chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
        mkdir -p /etc/systemd/system/multi-user.target.wants && \
        ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service && \
        apt-get purge -y qemu-* binfmt-support || true && \
        apt-get autoremove -y && \
        apt-get autoclean && \
        rm -rf /var/lib/binfmts/* && \
        rm -rf /etc/binfmt.d/* && \
        rm -rf /usr/lib/binfmt.d/qemu-* && \
        apt-get update && \
        apt-get install -y qemu-user-static && \
        apt-get install -y binfmt-support && \
        dpkg --add-architecture amd64 && \
        sed -i 's/^deb /deb [arch=arm64,armhf] /g' /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse" >> /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
        echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list && \
        apt-get update && \
        apt-get install -y libc6:amd64; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

# 最终清理 APT 包管理器缓存
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: 导出到 scratch 空白层，供外部提取打包为 tarfs
FROM scratch AS export

COPY --from=customizer / /
