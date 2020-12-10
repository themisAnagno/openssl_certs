#!/bin/bash

# ************************************************
# Trigger Certbot to check for certificate renewal
# Usage: check_renew.sh [--iptables]
# NOTE 1: This script should be in the same directory with etc/ and var/ that were created by Certbot
# NOTE 2: This script should be executed with root privileges for the iptables to be configured
# ************************************************

# Get the options
while [[ $# -gt 0 ]]; do
    key=$1

    case $key in
    --iptables)
        FW_CHECK=true
        shift
        ;;
    *)
        printf "Wrong option %s\n--------\n" "${key}"
        exit 255
        ;;
    esac
done

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Configure iptables if necessary
if [[ "${FW_CHECK}" == "true" ]]; then
    echo "Opening FW port 80"
    iptables -A INPUT -p tcp --dport http -j ACCEPT
else
    echo "No FW Configuration - Make sure port 80 is open"
fi

# Run the certbot docker container
docker run -i --rm --name certbot \
    -v "${DIR}/etc/letsencrypt:/etc/letsencrypt" \
    -v "${DIR}/var/lib/letsencrypt:/var/lib/letsencrypt" \
    -v "${DIR}/output:/tmp/output" \
    -p 80:80 certbot/certbot renew --post-hook "echo Certificate renewed: True > /tmp/output/cert_renewed_$(date +\"%Y_%m_%d-%k:%M\")" --no-random-sleep-on-renew -q

# Configure iptables if necessary
if [[ "${FW_CHECK}" == "true" ]]; then
    RULE=$(iptables -vnL --line-number | grep -E "ACCEPT.*tcp.*0\.0\.0.\0/0.*0\.0\.0.\0/0.*tcp dpt:80" | cut -d" " -f1)
    iptables -D INPUT "${RULE}"
fi

# Check if the certs are renewed
renew_check=$(find "${DIR}"/output/ -maxdepth 1 -mtime -1 -type f)
if [ -z "${renew_check}" ]; then
    echo "*** Did not renew Certificates ***"
else
    echo "*** Certificate Renewed ***"
# NOTE: Enter code to manage new certificates
fi
