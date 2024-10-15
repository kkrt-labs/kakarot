#!/usr/bin/env python3

import logging
import os
import shutil
import subprocess
import sys
from typing import Optional

KATANA_VERSION = "v1.0.0-alpha.14"
PYTHON_MIN_VERSION = (3, 10)
ASDF_VERSION = "v0.14.1"

SHELL_CONFIG_FILES = {
    "bash": [".bashrc", ".bash_profile"],
    "zsh": [".zshrc"],
    "fish": [".config/fish/config.fish"],
}


class SetupError(Exception):
    """Custom exception for setup errors."""

    pass


def run_command(command: str, error_message: str) -> None:
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as e:
        raise SetupError(f"{error_message}: {e}") from e


def is_command_available(command: str) -> bool:
    return shutil.which(command) is not None


def get_version(command: str) -> Optional[str]:
    try:
        result = subprocess.run([command, "--version"], capture_output=True, text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_shell_config_file() -> Optional[str]:
    shell = os.environ.get("SHELL", "").split("/")[-1]
    home = os.path.expanduser("~")

    for file in SHELL_CONFIG_FILES.get(shell, []):
        full_path = os.path.join(home, file)
        if os.path.exists(full_path):
            return full_path

    return None


def install_dependency(
    name: str, install_command: str, check_command: str, version: Optional[str] = None
) -> None:
    if is_command_available(check_command):
        if version:
            current_version = get_version(check_command)
            if current_version == version:
                logger.info(f"{name} version {version} is already installed.")
                return
            logger.info(f"Updating {name} to version {version}...")
        else:
            logger.info(f"{name} is already installed.")
            return
    else:
        logger.info(f"Installing {name}...")

    run_command(install_command, f"Failed to install/update {name}")


def setup_katana() -> None:
    install_dependency(
        "katana",
        f'cargo install --git https://github.com/dojoengine/dojo --locked --tag "{KATANA_VERSION}" katana',
        "katana",
        version=KATANA_VERSION,
    )


def setup_local() -> None:
    # Install dependencies
    install_dependency(
        "jq",
        "brew install jq" if sys.platform == "darwin" else "sudo apt-get install -y jq",
        "jq",
    )
    install_dependency("cargo", "curl https://sh.rustup.rs -sSf | sh -s -- -y", "cargo")
    run_command(". $HOME/.cargo/env", "Failed to source cargo environment")

    install_dependency("uv", "curl -LsSf https://astral.sh/uv/install.sh | sh", "uv")

    if not is_command_available("docker"):
        logger.warning(
            "❌ Please install Docker manually from https://docs.docker.com/get-docker/"
        )
    else:
        logger.info("Docker is already installed.")

    install_dependency(
        "foundry", "curl -L https://foundry.paradigm.xyz | bash && foundryup", "forge"
    )

    # Install asdf and related tools
    if not is_command_available("asdf"):
        logger.info("Installing asdf...")
        run_command(
            f"git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch {ASDF_VERSION}",
            "Failed to install asdf",
            version=ASDF_VERSION,
        )
        shell_config = get_shell_config_file()
        if shell_config:
            run_command(
                f"echo '. $HOME/.asdf/asdf.sh' >> {shell_config}",
                "Failed to source asdf environment",
            )
            logger.info("Please restart your terminal to use asdf.")
        else:
            logger.warning("Please add asdf to your shell configuration manually.")
    else:
        logger.info("asdf is already installed.")

    run_command(
        "asdf plugin add scarb && asdf plugin add starknet-foundry || true",
        "Failed to add asdf plugins",
    )
    run_command("asdf install", "Failed to install asdf tools")

    install_dependency(
        "go",
        (
            "brew install go"
            if sys.platform == "darwin"
            else "sudo apt-get install -y golang-go"
        ),
        "go",
    )
    setup_katana()

    logger.info("All dependencies have been installed or were already available!")


def main() -> None:
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "katana":
            setup_katana()
        else:
            setup_local()
    except SetupError as e:
        logger.error(f"❌ Error: {e}")
        sys.exit(1)


# Set up logging
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

if __name__ == "__main__":
    main()
