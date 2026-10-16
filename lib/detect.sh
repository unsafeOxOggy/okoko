# shellcheck shell=bash
# okoko — environment detection (distro, hypervisor, renderer).

detect_distro() {
    # shellcheck disable=SC1091
    [[ -r /etc/os-release ]] && . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
}

is_debian_like() {
    [[ "$DISTRO_ID" == debian || "$DISTRO_LIKE" == *debian* ]]
}

# kvm | qemu | vmware | oracle | microsoft | none ...
detect_virt() {
    if has systemd-detect-virt; then
        VIRT="$(systemd-detect-virt --vm 2>/dev/null || true)"
    fi
    VIRT="${VIRT:-none}"
}

# Choose a picom backend: GLX only when a real (non-software) OpenGL renderer exists.
detect_picom_backend() {
    local renderer=""
    if has glxinfo && [[ -n "${DISPLAY:-}" ]]; then
        renderer="$(timeout 3 glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer/{print $2}')"
    fi
    case "$renderer" in
        ""|*llvmpipe*|*softpipe*|*SVGA3D*|*virgl*) PICOM_BACKEND=xrender ;;
        *) PICOM_BACKEND=glx ;;
    esac
}

detect_all() {
    detect_distro
    detect_virt
}
