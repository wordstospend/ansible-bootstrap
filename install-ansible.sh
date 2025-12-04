#!/usr/bin/env bash
set -euo pipefail


# ------- config you can tweak -------
ANSIBLE_VERSION=""   # e.g. "==10.2.0" or leave blank for latest
PROJECT_DIR="${HOME}/ansible"
VENV_DIR="${PROJECT_DIR}/.venv"
INITIAL_INVENTORY="${PROJECT_DIR}/inventory/hosts.ini"
INITIAL_PLAYBOOK="${PROJECT_DIR}/site.yml"
# ------------------------------------


msg() { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err() { printf "\033[1;31m%s\033[0m\n" "$*" >&2; exit 1; }


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
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
      source ~/.zprofile
  fi

  brew update
  brew install python git openssh
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
        var: ansible_python.version
YML
  fi
}

clone_project() {
  msg "Cloning ansible-bootstrap project..."
  mkdir -p "${HOME}/bin"
  if [ ! -d "${HOME}/bin/ansible-bootstrap" ]; then
    (cd "${HOME}/bin" && git clone git@github.com:wordstospend/ansible-bootstrap.git)
  else
    msg "Project directory ${HOME}/bin/ansible-bootstrap already exists."
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
  install_prereqs_macos
  ensure_ssh_key
  clone_project
  msg "Done ✅"
}

main "$@"
