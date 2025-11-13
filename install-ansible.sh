#!/usr/bin/env bash
set -euo pipefail

# ------- config you can tweak -------
ANSIBLE_VERSION=""   # e.g. "==10.2.0" or leave blank for latest
PROJECT_DIR="${HOME}/ansible"
VENV_DIR="${PROJECT_DIR}/.venv"
INITIAL_INVENTORY="${PROJECT_DIR}/inventory/hosts.ini"
INITIAL_PLAYBOOK="${PROJECT_DIR}/site.yml"
# ------------------------------------

need_sudo() {
  if command -v sudo >/dev/null 2>&1; then
    sudo -v
  fi
}

msg() { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err() { printf "\033[1;31m%s\033[0m\n" "$*" >&2; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID:-}" in
          debian|ubuntu|linuxmint|pop) echo "debian" ;;
          *) err "Unsupported Linux distro: ${ID:-unknown}. Add your package steps." ;;
        esac
      else
        err "Unknown Linux; /etc/os-release missing."
      fi
      ;;
    *) err "Unsupported OS: $(uname -s)" ;;
  esac
}

install_prereqs_macos() {
  msg "Installing prerequisites for macOS..."
  # Xcode CLT (provides git if Homebrew missing)
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    warn "If prompted, complete the Command Line Tools install, then re-run this script."
  fi

  # Homebrew
  if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"
  fi

  brew update
  brew install python git openssh
}

install_prereqs_debian() {
  msg "Installing prerequisites for Debian/Ubuntu..."
  need_sudo
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip git openssh-client
}

ensure_ssh_key() {
  if [ ! -f "${HOME}/.ssh/id_ed25519" ]; then
    msg "Generating SSH key (ed25519)..."
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    ssh-keygen -t ed25519 -q -N "" -f "${HOME}/.ssh/id_ed25519"
    msg "Public key:"
    cat "${HOME}/.ssh/id_ed25519.pub"
    warn "Add this key to GitHub: https://github.com/settings/keys"
  else
    msg "SSH key already exists."
  fi
}

create_project() {
  msg "Creating Ansible project at ${PROJECT_DIR}..."
  mkdir -p "${PROJECT_DIR}/inventory" "${PROJECT_DIR}/group_vars" "${PROJECT_DIR}/host_vars" "${PROJECT_DIR}/roles"
  if [ ! -f "${INITIAL_INVENTORY}" ]; then
    cat > "${INITIAL_INVENTORY}" <<'EOF'
[local]
localhost ansible_connection=local
EOF
  fi
  if [ ! -f "${INITIAL_PLAYBOOK}" ]; then
    cat > "${INITIAL_PLAYBOOK}" <<'YML'
---
- name: Bootstrap check
  hosts: all
  gather_facts: true
  tasks:
    - name: Ping
      ansible.builtin.ping:

    - name: Show Python version on target
      ansible.builtin.debug:
        var: ansible_python.version.full
YML
  fi
}

create_venv_and_install() {
  msg "Creating virtualenv and installing Ansible..."
  python3 -m venv "${VENV_DIR}"
  # shellcheck disable=SC1091
  . "${VENV_DIR}/bin/activate"
  pip install --upgrade pip wheel
  pip install "ansible${ANSIBLE_VERSION}"
  # Optional useful tools:
  # pip install ansible-lint
  ansible --version
}

run_smoke_test() {
  # shellcheck disable=SC1091
  . "${VENV_DIR}/bin/activate"
  msg "Running a quick smoke test..."
  ansible -i "${INITIAL_INVENTORY}" all -m ping
  msg "Now run: source ${VENV_DIR}/bin/activate && ansible-playbook -i ${INITIAL_INVENTORY} ${INITIAL_PLAYBOOK}"
}

main() {
  OS="$(detect_os)"
  case "$OS" in
    macos) install_prereqs_macos ;;
    debian) install_prereqs_debian ;;
  esac
  ensure_ssh_key
  create_project
  create_venv_and_install
  run_smoke_test
  msg "Done ✅"
}

main "$@"
