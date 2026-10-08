#!/usr/bin/env bash
# Build a template dir from the repo root, secrets always from $HOME.
# Usage: ./run.sh [-f] <template-dir> [extra packer args...]
set -euo pipefail

FORCE=0
usage() {
    cat <<EOF
Usage: $0 [-f] [-h] <template-dir> [extra packer args...]

Build a template dir from the repo root; secrets always come from
\$HOME/.config/packer/secrets.pkrvars.hcl when present.

  e.g. $0 debian/13/proxmox
       $0 arch/rolling/virtualbox
       $0 -f debian/13/virtualbox

Options:
  -f  remove previous output (output/<template-dir>) and unregister an
      existing VirtualBox VM with the template's vm_name first
  -h, --help  show this help

Artifacts land in output/<template-dir>/, the build log in
output/<template-dir>.log. Always run from the repo root.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -f) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) break ;;
    esac
done

if [ -z "${1:-}" ]; then
    usage >&2
    exit 1
fi

DIR="${1%/}"; shift
if [ ! -d "$DIR" ]; then
    echo "Unknown template dir: $DIR" >&2
    echo "Run from the repo root; see ./run.sh --help." >&2
    exit 1
fi
OUT="output/$DIR"
LOG="output/$DIR.log"
mkdir -p "$(dirname "$LOG")"
VAR_FILE="$HOME/.config/packer/secrets.pkrvars.hcl"
COMMON_VARS="common.pkrvars.hcl"
VAR_ARGS=()
if [ -f "$COMMON_VARS" ]; then
    VAR_ARGS+=(-var-file "$COMMON_VARS")
fi
if [ -f "$VAR_FILE" ]; then
    VAR_ARGS+=(-var-file "$VAR_FILE")
fi

vm_name_from_template() {
    grep -A3 'variable "vm_name"' "$DIR"/*.pkr.hcl 2>/dev/null \
        | grep 'default' \
        | sed -E 's/.*default *= *"([^"]+)".*/\1/' \
        | head -n1
}

if [ "$FORCE" -eq 1 ]; then
    if [ -d "$OUT" ]; then
        echo "Removing previous output in $OUT"
        rm -rf "$OUT"
    fi
    rm -f "$LOG"
    if command -v VBoxManage >/dev/null 2>&1; then
        VM_NAME="$(vm_name_from_template || true)"
        if [ -n "${VM_NAME:-}" ] && VBoxManage list vms | grep -q "\"$VM_NAME\""; then
            if VBoxManage list runningvms | grep -q "\"$VM_NAME\""; then
                echo "Powering off running VirtualBox VM $VM_NAME"
                VBoxManage controlvm "$VM_NAME" poweroff
                sleep 3
            fi
            echo "Unregistering existing VirtualBox VM $VM_NAME"
            VBoxManage unregistervm "$VM_NAME" --delete
        fi
    fi
fi

echo "Logging to $LOG"
if [ "${#VAR_ARGS[@]}" -gt 0 ]; then
    PACKER_LOG=1 packer build "${VAR_ARGS[@]}" "$DIR" "$@" 2>&1 | tee "$LOG"
else
    # Hosts without remote credentials (e.g. VirtualBox on localhost)
    PACKER_LOG=1 packer build "$DIR" "$@" 2>&1 | tee "$LOG"
fi
