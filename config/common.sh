#!/bin/bash

set -xe

with_retry() {
	local max_attempts="$1"
	local delay="$2"
	local count=0
	local rc
	shift 2

	while true; do
		set +e
		"$@"
		rc="$?"
		set -e

		count="$((count+1))"

		if [[ "${rc}" -eq 0 ]]; then
			return 0
		fi

		if [[ "${max_attempts}" -le 0 ]] || [[ "${count}" -lt "${max_attempts}" ]]; then
			sleep "${delay}"
		else
			break
		fi
	done

	return 1
}

# Detect architecture
architecture=$(uname -m)
if [[ $architecture == "x86_64" || $architecture == "amd64" ]]; then
    ARCH="amd64"
elif [[ $architecture == "aarch64" || $architecture == "arm64" ]]; then
    ARCH="arm64"
else
    echo "Unknown architecture: $architecture"
    exit 1
fi

# Check if the operating system is Ubuntu
if [ -f "/etc/os-release" ]; then
    source "/etc/os-release"

    # Format the OS version string
    os_version="${NAME}_${VERSION_ID}"
    # if NAME is Ubuntu, then prefix with x
    if [ "${NAME}" == "Ubuntu" ]; then
        os_version="x${os_version}"
    fi

    # Set the environment variable
    OS="$os_version"
else
    # Set a default value if we can't read /etc/os-release
	echo "Unknown OS: can't read /etc/os-release"
    exit 1
fi
