#!/bin/bash

# ************************************************
# Trigger certbot to check for certificate renewal
# NOTE1: This script should be in the same directory with etc/ and var/ that are created by certbot
# NOTE2: This script should be executed with root priviledges for the iptables to be configured
# ************************************************


# Get the options
OPTIONS=" "
while [[ $# -gt 0 ]]
do
key=$1

case $key in
--ip-tables)
FW_CHECK=true
shift
;;
--dry-run | --force-renewal)
echo "Added option: ${key}"
sleep 3
OPTIONS="${OPTIONS} ${key}"
shift
;;
*)
printf "Wrong option %s\n--------\n" "${key}"
exit 9999
;;
esac
done

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Configure iptables if necessary
if [[ "${FW_CHECK}" == "true"  ]]; then
echo "Opening FW port 80"
iptables -A INPUT -p tcp --dport http -j ACCEPT
else
echo "No FW Configuration - Make sure port 80 is open"
fi

# Run the certbot docker container
echo "" | docker run -i --rm --name certbot \
    -v "${DIR}/etc/letsencrypt:/etc/letsencrypt" \
    -v "${DIR}/var/lib/letsencrypt:/var/lib/letsencrypt" \
    -v "${DIR}/output:/tmp/output" \
    -p 80:80 certbot/certbot renew ${OPTIONS} --post-hook "echo Certificate renewed: True > /tmp/output/cert_renewed_$(date +\"%Y_%m_%d-%k:%M\")" --no-random-sleep-on-renew

# Configure iptables if necessary

if [[ "${FW_CHECK}" == "true"  ]]; then
RULE=$(iptables -vnL --line-number | grep -E "ACCEPT.*tcp.*0\.0\.0.\0/0.*0\.0\.0.\0/0.*tcp dpt:80" | cut  -d" " -f1)
iptables -D INPUT "${RULE}"
fi

# Check if the certs are renewed
check=$(find "${DIR}"/output/ -maxdepth 1 -mtime -1 -type f)
if [ -z "${check}" ]; then
echo "*** Did not renew Certificates ***"
else
echo "*** Certificate Renewed ***"
echo "*** Managing the certificates ***"
sleep 5

# Remove previous certificates
rm -f "${DIR}"/jenkins/certs/*

# Copy the new certificates to the Jenkins folder and change owner
cp "${DIR}"/etc/letsencrypt/live/jenkins.staminaregistry.site/* "${DIR}/jenkins/certs"
sudo chown -R 1000:1000 jenkins/
# Create the Jenkins JKS Keystore
# Combine certificate and private key to a single file
cat "${DIR}/jenkins/certs/fullchain.pem" "${DIR}/jenkins/certs/privkey.pem" > "${DIR}/jenkins/certs/combined.pem"

# Create PKCS12 certificate
openssl pkcs12 -export -in "${DIR}/jenkins/certs/combined.pem" -out "${DIR}/jenkins/certs/cert.p12" -passout 'pass:1234'

# Create JKS Certificate
docker container run \
    -it --rm --name java_container \
    -v "${DIR}"/jenkins/certs:/jenkins_jks openjdk \
    bash -c 'cd /jenkins_jks && keytool -importkeystore -srckeystore cert.p12 -srcstorepass "1234" -srcstoretype pkcs12 -destkeystore jenkins_keystore.jks -deststorepass "123456" '

# Copy JKS in Jenkins volume
sudo cp "${DIR}/jenkins/certs/jenkins_keystore.jks" "/var/lib/docker/volumes/jenkins_home/_data"

# Restart the Jenkins container
docker container restart jenkins

fi
