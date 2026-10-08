#!/usr/bin/env bash
# Clone a packer-* template into a working VM and manage its lifecycle.
# Usage: ./vm.sh [-n name] [-p port] <list|up|shutdown|destroy|status|ssh> [-- ssh args...]
set -euo pipefail

NAME="${VM_NAME:-dev}"
PORT="${SSH_PORT:-2222}"

usage() {
    cat <<EOF
Usage: $0 [-n name] [-p port] <list|up|shutdown|destroy|status|ssh> [-- ssh args...]

Manage a working copy of a packer-* template VM (VirtualBox, localhost).

  list      show all VMs with running state (no -n needed)
  up        start the VM; if it does not exist yet, pick a packer-*
            template, clone it, wire SSH port forwarding, then start it
  shutdown  ACPI shutdown (falls back to power off after 60s)
  destroy   power off (if running) and delete the VM including its disk
  status    show VM state and the SSH port forward
  ssh       ssh as linux@localhost on the forwarded port

Options:
  -n name   VM name (default: "dev"; env VM_NAME also works)
  -p port   host SSH port (default: 2222; env SSH_PORT also works)
  -h        show this help

  e.g. $0 up
       $0 -n dnstest up
       $0 -n dntest -p 2223 up && $0 -n dntest ssh
       $0 -n dntest shutdown
       $0 -n dntest destroy
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -n) NAME="${2:?missing VM name}"; shift 2 ;;
        -p) PORT="${2:?missing SSH port}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) break ;;
    esac
done

CMD="${1:-}"; shift || true
case "$CMD" in
    list|up|shutdown|destroy|status|ssh) ;;
    *) usage >&2; exit 1 ;;
esac

cmd_list() {
    VBoxManage list vms | sed -E 's/^"([^"]+)" \{[^}]+\}$/\1/' | while IFS= read -r VM; do
        if VBoxManage list runningvms | grep -q "\"$VM\""; then
            printf '%-24s running\n' "$VM"
        else
            printf '%-24s powered off\n' "$VM"
        fi
    done
}

vm_exists() {
    VBoxManage list vms | grep -q "\"$1\""
}

vm_running() {
    VBoxManage list runningvms | grep -q "\"$1\""
}

ensure_forward() {
    VBoxManage modifyvm "$NAME" --natpf1 delete ssh >/dev/null 2>&1 || true
    VBoxManage modifyvm "$NAME" --natpf1 "ssh,tcp,127.0.0.1,$PORT,,22"
    echo "SSH forwarded: localhost:$PORT -> $NAME:22 (user linux)"
}

pick_template() {
    mapfile -t TEMPLATES < <(VBoxManage list vms \
        | grep -o '"packer-[^"]*"' | tr -d '"' || true)
    if [ "${#TEMPLATES[@]}" -eq 0 ]; then
        echo "No packer-* template VMs found. Build one first (see ./run.sh --help)." >&2
        exit 1
    fi
    if [ "${#TEMPLATES[@]}" -eq 1 ]; then
        echo "${TEMPLATES[0]}"
        return
    fi
    echo "Pick a template to clone:" >&2
    select SRC in "${TEMPLATES[@]}"; do
        if [ -n "${SRC:-}" ]; then
            echo "$SRC"
            return
        fi
    done
}

cmd_up() {
    if vm_exists "$NAME"; then
        echo "VM $NAME exists."
    else
        SRC="$(pick_template)"
        echo "Cloning $SRC -> $NAME ..."
        VBoxManage clonevm "$SRC" --name "$NAME" --register
    fi
    ensure_forward
    if vm_running "$NAME"; then
        echo "VM $NAME is already running."
    else
        echo "Starting $NAME ..."
        VBoxManage startvm "$NAME" --type headless
    fi
}

cmd_shutdown() {
    if ! vm_exists "$NAME"; then
        echo "No such VM: $NAME" >&2
        exit 1
    fi
    if ! vm_running "$NAME"; then
        echo "VM $NAME is not running."
        return
    fi
    echo "ACPI shutdown for $NAME ..."
    VBoxManage controlvm "$NAME" acpipowerbutton
    for _ in $(seq 1 60); do
        vm_running "$NAME" || { echo "VM $NAME is off."; return; }
        sleep 1
    done
    echo "Still running after 60s; powering off."
    VBoxManage controlvm "$NAME" poweroff
}

cmd_destroy() {
    if ! vm_exists "$NAME"; then
        echo "No such VM: $NAME" >&2
        exit 1
    fi
    if vm_running "$NAME"; then
        echo "Powering off $NAME ..."
        VBoxManage controlvm "$NAME" poweroff
        sleep 3
    fi
    echo "Deleting $NAME (including disk) ..."
    VBoxManage unregistervm "$NAME" --delete
}

cmd_status() {
    if ! vm_exists "$NAME"; then
        echo "No such VM: $NAME"
        exit 1
    fi
    if vm_running "$NAME"; then
        echo "VM $NAME: running"
    else
        echo "VM $NAME: powered off"
    fi
    VBoxManage showvminfo "$NAME" --machinereadable \
        | grep -i 'natpf1.*"ssh' || echo "(no ssh port forward configured)"
}

cmd_ssh() {
    exec ssh -p "$PORT" "linux@127.0.0.1" "$@"
}

case "$CMD" in
    list) cmd_list ;;
    up) cmd_up ;;
    shutdown) cmd_shutdown ;;
    destroy) cmd_destroy ;;
    status) cmd_status ;;
    ssh) cmd_ssh "$@" ;;
esac
