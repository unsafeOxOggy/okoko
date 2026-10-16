# shellcheck shell=bash
# okoko - kvm-autofit integration: the guest screen follows the KVM viewer window
# (boot, greeter, login, fullscreen). Two interchangeable editions:
#   bash  vendored in extras/kvm-autofit (no build needed)
#   rs    prebuilt static binary from a kvm-autofit-rs checkout (dir/dist/bin/kvm-autofit)

AUTOFIT_BASH_DIR="$OKOKO_ROOT/extras/kvm-autofit"
AUTOFIT_RS_DIR="${KVM_AUTOFIT_RS_DIR:-$HOME/kvm-autofit-rs}"

autofit_wanted() { [[ "$VIRT" == kvm || "$VIRT" == qemu ]]; }

# autofit_install bash|rs  - needs sudo; falls back to bash if the rust build is missing.
autofit_install() {
    local mode="${1:-bash}" dir args=()
    [[ "$DRY_RUN" == 1 ]] && args+=(--dry-run)
    if [[ "$mode" == rs ]]; then
        if [[ -x "$AUTOFIT_RS_DIR/dist/bin/kvm-autofit" && -f "$AUTOFIT_RS_DIR/install.sh" ]]; then
            dir="$AUTOFIT_RS_DIR"
        else
            warn "kvm-autofit-rs build not found in $AUTOFIT_RS_DIR (set KVM_AUTOFIT_RS_DIR) - using the bash edition"
            mode=bash
        fi
    fi
    [[ "$mode" == bash ]] && dir="$AUTOFIT_BASH_DIR"
    run sudo "$dir/install.sh" "${args[@]}" || { warn "kvm-autofit ($mode) install failed - see $OKOKO_LOG"; return 1; }
    ok "kvm-autofit ($mode) installed"
}

# For `okoko doctor`: which edition is active, if any.
autofit_status() {
    local unit=/etc/systemd/system/kvm-autofit.service
    if [[ ! -f $unit ]]; then
        autofit_wanted && warn "kvm-autofit not installed - screen may not follow the VM window (./install.sh --autofit=bash)"
        return 0
    fi
    if grep -q "kvm-autofit watch" "$unit"; then
        systemctl is-active -q kvm-autofit.service && ok "kvm-autofit (rust daemon) active" || warn "kvm-autofit (rust) installed but daemon not running"
    else
        [[ -f /etc/udev/rules.d/90-kvm-autofit.rules ]] && ok "kvm-autofit (bash, udev) installed" || warn "kvm-autofit unit present but udev rule missing"
    fi
}
