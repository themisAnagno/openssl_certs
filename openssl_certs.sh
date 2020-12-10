#!/bin/bash

# Get the options
while [[ $# -gt 0 ]]; do
    key=$1

    case $key in
    --ca)
        CA_CHECK="true"
        shift
        ;;
    --ca_name)
        CA_NAME=$2
        shift
        shift
        ;;
    --cn_name)
        CN_NAME=$2
        shift
        shift
        ;;
    *)
        printf "Wrong option %s\n--------\n" "${key}"
        exit 255
        ;;
    esac
done


# *** Create the CA self-signed certificate ***
if [[ "${CA_CHECK}" == "true" ]]; then
echo "**** CRREATING CA PRIVATE KEY ****"
sleep 3
# Create the private key of the CA
openssl genrsa -aes256 -out "${CA_NAME}".key 2048

# Create pem certificate of the CA
echo "**** CRREATING CA PEM CERTIFICATE ****"
sleep 3
openssl req -new -x509 -key "${CA_NAME}".key -sha256 -days 3650 -out "${CA_NAME}".pem
fi

# *** Create the organization certificate ***
echo "**** CRREATING CN PRIVATE KEY ****"
sleep 3
# Create the private key of the CN
openssl genrsa -aes256 -out "${CN_NAME}".key 2048

echo "**** CRREATING CN SIGN REQUEST ****"
sleep 3
# Create the request for a new certificate
openssl req -new -key "${CN_NAME}".key -out "${CN_NAME}".csr

echo "**** CRREATING CN PEM CERTIFICATE ****"
sleep 3
# Sign the request using the CA
if [ -f "otherinfo.ext" ]; then
ext_file_option="-extfile otherinfo.ext"
openssl x509 -req -in "${CN_NAME}".csr -CA "${CA_NAME}".pem -CAkey "${CA_NAME}".key -CAcreateserial -out "${CN_NAME}".pem -days 365 -sha256 "${ext_file_option}"
else
openssl x509 -req -in "${CN_NAME}".csr -CA "${CA_NAME}".pem -CAkey "${CA_NAME}".key -CAcreateserial -out "${CN_NAME}".pem -days 365 -sha256
fi

# Create the fullchain certificate
echo "**** Full Chain CERTIFICATE ****"
sleep 3
cat "${CN_NAME}" "${CA_NAME}" > fullchain.pem