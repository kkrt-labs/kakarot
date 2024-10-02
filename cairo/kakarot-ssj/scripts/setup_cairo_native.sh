#!/bin/bash

install_essential_deps_linux() {
	apt-get update -y
	apt-get install -y \
		curl \
		jq \
		ripgrep \
		wget \
		ca-certificates \
		gnupg \
		git
}

setup_llvm_deps() {
	case "$(uname)" in
	Darwin)
		brew update
		brew install llvm@19

		LIBRARY_PATH=/opt/homebrew/lib
		MLIR_SYS_190_PREFIX="$(brew --prefix llvm@19)"
		LLVM_SYS_191_PREFIX="${MLIR_SYS_190_PREFIX}"
		TABLEGEN_190_PREFIX="${MLIR_SYS_190_PREFIX}"

		export LIBRARY_PATH
		export MLIR_SYS_190_PREFIX
		export LLVM_SYS_191_PREFIX
		export TABLEGEN_190_PREFIX
		;;
	Linux)
		export DEBIAN_FRONTEND=noninteractive
		export TZ=America/New_York

		# shellcheck disable=SC2312
		CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
		if [[ -z ${CODENAME} ]]; then
			echo "Error: Unable to determine OS codename"
			exit 1
		fi

		# shellcheck disable=SC2312
		echo "deb http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-19 main" >/etc/apt/sources.list.d/llvm-19.list
		echo "deb-src http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-19 main" >>/etc/apt/sources.list.d/llvm-19.list
		# shellcheck disable=SC2312
		if ! wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -; then
			echo "Error: Failed to add LLVM GPG key"
			exit 1
		fi

		if ! apt-get update && apt-get upgrade -y; then
			echo "Error: Failed to update and upgrade packages"
			exit 1
		fi
		if ! apt-get install -y llvm-19 llvm-19-dev llvm-19-runtime clang-19 clang-tools-19 lld-19 libpolly-19-dev libmlir-19-dev mlir-19-tools; then
			echo "Error: Failed to install LLVM packages"
			exit 1
		fi

		MLIR_SYS_190_PREFIX=/usr/lib/llvm-19/
		LLVM_SYS_191_PREFIX=/usr/lib/llvm-19/
		TABLEGEN_190_PREFIX=/usr/lib/llvm-19/

		export MLIR_SYS_190_PREFIX
		export LLVM_SYS_191_PREFIX
		export TABLEGEN_190_PREFIX

		{
			echo "MLIR_SYS_190_PREFIX=${MLIR_SYS_190_PREFIX}"
			echo "LLVM_SYS_191_PREFIX=${LLVM_SYS_191_PREFIX}"
			echo "TABLEGEN_190_PREFIX=${TABLEGEN_190_PREFIX}"
		} >>"${GITHUB_ENV}"
		;;
	*)
		echo "Error: Unsupported operating system"
		exit 1
		;;
	esac

	# GitHub Actions specific
	[[ -n ${GITHUB_ACTIONS} ]] && {
		{
			echo "MLIR_SYS_190_PREFIX=${MLIR_SYS_190_PREFIX}"
			echo "LLVM_SYS_191_PREFIX=${LLVM_SYS_191_PREFIX}"
			echo "TABLEGEN_190_PREFIX=${TABLEGEN_190_PREFIX}"
		} >>"${GITHUB_ENV}"
	}
}

install_rust() {
	if command -v cargo >/dev/null 2>&1; then
		echo "Rust is already installed with cargo available in PATH."
		return 0
	fi

	echo "cargo not found. Installing Rust..."
	# shellcheck disable=SC2312
	if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.81.0 --no-modify-path; then
		echo >&2 "Failed to install Rust. Aborting."
		return 1
	fi

	# shellcheck disable=SC1091
	if [[ -f "${HOME}/.cargo/env" ]]; then
		. "${HOME}/.cargo/env"
	else
		echo >&2 "Failed to find Rust environment file. Aborting."
		return 1
	fi

	echo "Rust installed successfully."
}

install_cairo_native_runtime() {
	install_rust || {
		echo "Error: Failed to install Rust"
		exit 1
	}

	git clone https://github.com/lambdaclass/cairo_native.git
	pushd ./cairo_native || exit 1
	git fetch
	make deps
	make runtime
	cp libcairo_native_runtime.a ../libcairo_native_runtime.a
	popd || exit 1

	rm -rf ./cairo_native

	CAIRO_NATIVE_RUNTIME_LIBRARY=$(pwd)/libcairo_native_runtime.a
	if [[ -z ${CAIRO_NATIVE_RUNTIME_LIBRARY} ]]; then
		echo "Error: Failed to set CAIRO_NATIVE_RUNTIME_LIBRARY"
		exit 1
	fi
	export CAIRO_NATIVE_RUNTIME_LIBRARY

	echo "CAIRO_NATIVE_RUNTIME_LIBRARY=${CAIRO_NATIVE_RUNTIME_LIBRARY}"

	[[ -n ${GITHUB_ACTIONS} ]] && echo "CAIRO_NATIVE_RUNTIME_LIBRARY=${CAIRO_NATIVE_RUNTIME_LIBRARY}" >>"${GITHUB_ENV}"
}

main() {
	# New argument parsing
	SKIP_RUNTIME=false
	while getopts ":s" opt; do
		case ${opt} in
		s)
			SKIP_RUNTIME=true
			;;
		\?)
			echo "Invalid option: ${OPTARG}" 1>&2
			exit 1
			;;
		*)
			echo "Error: Unhandled option" 1>&2
			exit 1
			;;
		esac
	done
	shift $((OPTIND - 1))

	# shellcheck disable=SC2312
	[[ "$(uname)" == "Linux" ]] && install_essential_deps_linux

	setup_llvm_deps

	if [[ ${SKIP_RUNTIME} == false ]]; then
		install_cairo_native_runtime
	else
		echo "Skipping Cairo native runtime installation"
		# Set the environment variable if the library file exists
		# shellcheck disable=SC2312
		if [[ -f "$(pwd)/libcairo_native_runtime.a" ]]; then
			CAIRO_NATIVE_RUNTIME_LIBRARY=$(pwd)/libcairo_native_runtime.a
			export CAIRO_NATIVE_RUNTIME_LIBRARY
			echo "CAIRO_NATIVE_RUNTIME_LIBRARY=${CAIRO_NATIVE_RUNTIME_LIBRARY}"
			[[ -n ${GITHUB_ACTIONS} ]] && echo "CAIRO_NATIVE_RUNTIME_LIBRARY=${CAIRO_NATIVE_RUNTIME_LIBRARY}" >>"${GITHUB_ENV}"
		else
			echo "Warning: libcairo_native_runtime.a not found. CAIRO_NATIVE_RUNTIME_LIBRARY not set."
		fi
	fi

	echo "LLVM and Cairo native runtime dependencies setup completed."
}

main "$@"
