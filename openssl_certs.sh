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
    --san)
        SAN=$2
        shift
        shift
        ;;
    --client_auth)
        CLIENT_AUTH_CHECK="true"
        shift
        ;;
    --server_auth)
        SERVER_AUTH_CHECK="true"
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
echo "**** CREATING CA PRIVATE KEY ****"
sleep 2
# Create the private key of the CA
openssl genrsa -aes256 -out "${CA_NAME}".key 2048

# Create pem certificate of the CA
echo "**** CREATING CA PEM CERTIFICATE ****"
sleep 2
openssl req -new -x509 -key "${CA_NAME}".key -sha256 -days 7300 -out "${CA_NAME}".pem -subj "/C=LU/ST=./L=./O=INTRA/CN=${CA_NAME}"
fi

# *** Create the organization certificate ***
echo "**** CREATING SERVER PRIVATE KEY ****"
sleep 2
# Create the private key of the server
openssl genrsa -out "${CN_NAME}".key 2048

echo "**** CREATING SERVER CERTIFICATE SIGN REQUEST ****"
sleep 2
# Create the request for a new server certificate
openssl req -new -key "${CN_NAME}".key -out "${CN_NAME}".csr -subj "/CN=${CN_NAME}"

if [[ ! -z ${SAN+x} ]]; then
echo "subjectAltName = ${SAN}" >> otherinfo.ext
if [[ "${SERVER_AUTH_CHECK}" == "true" ]]; then
echo "extendedKeyUsage = serverAuth" >> otherinfo.ext
fi
fi

echo "**** CREATING SERVER PEM CERTIFICATE ****"
sleep 2
# Sign the server request using the CA
if [ -f "otherinfo.ext" ]; then
openssl x509 -req -in "${CN_NAME}".csr -CA "${CA_NAME}".pem -CAkey "${CA_NAME}".key -CAcreateserial -out "${CN_NAME}".pem -days 3650 -sha256 -extfile otherinfo.ext
else
openssl x509 -req -in "${CN_NAME}".csr -CA "${CA_NAME}".pem -CAkey "${CA_NAME}".key -CAcreateserial -out "${CN_NAME}".pem -days 3650 -sha256
fi

if [[ "${CLIENT_AUTH_CHECK}" == "true" ]]; then
echo "**** CREATING CLIENT PRIVATE KEY ****"
sleep 2
# Create the request for new client certificate
openssl genrsa -out client.key 4096 -out client.key
echo "**** CREATING CLIENT CERTIFICATE SIGN REQUEST ****"
sleep 2
openssl req -new -key client.key -out client.csr -subj '/CN=client'
echo "**** CREATING CLIENT PEM CERTIFICATE ****"
sleep 2
echo "extendedKeyUsage = clientAuth" > otherinfo.ext
openssl x509 -req -in client.csr -CA "${CA_NAME}".pem -CAkey "${CA_NAME}".key -CAcreateserial -out client.pem -days 3650 -sha256 -extfile "otherinfo.ext"
fi

# Create the fullchain certificate
echo "**** Full Chain CERTIFICATE ****"
sleep 2
cat "${CN_NAME}.pem" "${CA_NAME}.pem" > fullchain.pem

# Remove extra files
rm ./*.csr ./*.ext ./*.srl 2&> /dev/null
