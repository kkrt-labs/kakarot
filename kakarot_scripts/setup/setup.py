#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys


def run_command(command, error_message):
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError:
        print(f"Error: {error_message}")
        sys.exit(1)


def is_command_available(command):
    return shutil.which(command) is not None


def install_dependency(name, install_command, check_command):
    if is_command_available(check_command):
        print(f"{name} is already installed.")
    else:
        print(f"Installing {name}...")
        run_command(install_command, f"Failed to install {name}")


def get_shell_config_file():
    shell = os.environ.get("SHELL", "").split("/")[-1]
    home = os.path.expanduser("~")

    config_files = {
        "bash": [".bashrc", ".bash_profile"],
        "zsh": [".zshrc"],
        "fish": [".config/fish/config.fish"],
    }

    for file in config_files.get(shell, []):
        full_path = os.path.join(home, file)
        if os.path.exists(full_path):
            return full_path

    return None


def main():
    # Check Python version
    if sys.version_info < (3, 10):
        print("❌ Error: Python 3.10 or higher is required.")
        sys.exit(1)

    # Install jq
    install_dependency(
        "jq",
        "brew install jq" if sys.platform == "darwin" else "sudo apt-get install -y jq",
        "jq",
    )

    # Install cargo
    install_dependency("cargo", "curl https://sh.rustup.rs -sSf | sh -s -- -y", "cargo")
    # source $HOME/.cargo/env
    run_command(". $HOME/.cargo/env", "Failed to source cargo environment")

    # Install docker
    if not is_command_available("docker"):
        print(
            "❌ Please install Docker manually from https://docs.docker.com/get-docker/"
        )
    else:
        print("Docker is already installed.")

    # Install foundry
    install_dependency(
        "foundry", "curl -L https://foundry.paradigm.xyz | bash && foundryup", "forge"
    )

    # Install scarb using asdf
    if not is_command_available("asdf"):
        print("Installing asdf...")
        run_command(
            "git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1",
            "Failed to install asdf",
        )
        shell_config = get_shell_config_file()
        run_command(
            f"echo '. $HOME/.asdf/asdf.sh' >> {shell_config}",
            "Failed to source asdf environment",
        )
        print(
            "Please add asdf to your shell configuration and restart your terminal by following the instructions at https://asdf-vm.com/guide/getting-started.html"
        )
    else:
        print("asdf is already installed.")

    if is_command_available("asdf"):
        run_command(
            "asdf plugin add scarb || true", "Failed to add scarb plugin to asdf"
        )
        run_command("asdf install scarb 0.7.0 || true", "Failed to install scarb 0.7.0")
        run_command("asdf install scarb 2.6.5 || true", "Failed to install scarb 2.6.5")

    # Install Go
    install_dependency(
        "go",
        (
            "brew install go"
            if sys.platform == "darwin"
            else "sudo apt-get install -y golang-go"
        ),
        "go",
    )

    print("All dependencies have been installed or were already available!")


if __name__ == "__main__":
    main()
