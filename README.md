# Scripts to create and manage certificates with openssl and let's encrypt

## 1. Setup Jenkins with HTTPS and Let's Encrypt certificates

### Introduction

Let's Encrypt is a non-profit Certificate Authority (CA) run by Internet Security Research Group that provides X.509 certificates for TLS encryption at no charge. The certificates are trusted by most common browsers/tools and will allow to enable HTTPS on a website/service.

Let's encrypt requires a domain and shell access to the hosting server, in order to run a software that demonstrates control over the domain. The software is an agent that implements ACME protocol. Certbot is the recommended ACME client.

We will use Certbot to get a new certificate. Let's Encrypt certificates are valid for 3 months and they can be updated again using Certbot. Certbot will check and renew the certificates that are within one month from expiry date. We will create a Cron job that will periodically run Certbot for checking and renewing certificates. Finally, we will use the new certificates to create a JKS certificate which will be used for a Jenkins deployment over HTTPS.

### Certbot

Certbot has many plugins that will help to automate the whole procedure of getting and renewing certificates from Let's Encrypt. For example, running certbot --nginx will create a new certificate, include it in the NGINX configuration and create a Cron job for automatic renewal. You can also manually request for a certificate and renew it. You can either install Certbot along with your web-server (using snapd or distro packages) or run it in a Docker container. In the manual procedure, Certbot will temporarily create a custom web service listening to port 80 for validating the domain, so make sure that firewall won't block HTTP traffic and that nothing else is running on port 80. Check the `letsencrypt` script for the respective commands.

```bash
docker run -it --rm --name certbot -v "${PWD}/etc/letsencrypt:/etc/letsencrypt" -v "${PWD}/var/lib/letsencrypt:/var/lib/letsencrypt" -p 80:80 certbot/certbot certonly --standalone
```

You will be prompted to enter some info about the domain. At the end you have to enter the Common Name (CN) of the domain. You can enter the main domain followed by subdomains, which will be added as alternative domain names to the certificate.

When finished, the container will create and attach two directories as volumes, `etc/letsencrypt` where the certificates are stored and `var/lib/letsencrypt` where the logs are stored. The new certificates are stored in the path `etc/letsencrypt/live/DOMAIN_NAME/`. The content of this directory is listed below

``` bash
This directory contains your keys and certificates.
`privkey.pem`  : the private key for your certificate.
`fullchain.pem`: the certificate file used in most server software.
`chain.pem`    : used for OCSP stapling in Nginx >=1.3.7.
`cert.pem`     : will break many server configurations, and should not be used
                 without reading further documentation.
WARNING: DO NOT MOVE OR RENAME THESE FILES!
         Certbot expects these files to remain in this location in order
         to function properly!
```

### Renew

You can run Certbot again to check and perform certificate renewals. Note that Certbot should run on the same directory that was used for the certificate creation, and attach again the directories `etc/letsencrypt` and `var/lib/letsencrypt`

``` bash
docker run -it --rm --name certbot -v "${PWD}/etc/letsencrypt:/etc/letsencrypt" -v "${PWD}/var/lib/letsencrypt:/var/lib/letsencrypt" -p 80:80 certbot/certbot renew
```

Useful options:

- --dry-run:  Test "renew" or "certonly" without saving any certificates to disk
- --pre-hook COMMAND: Command to be run in a shell before obtaining/renewing any certificates
- --post-hook COMMAND: Command to be run in a shell after obtaining/renewing any certificates

> Note that --pre-hook and --post-hook commands will run inside the Certbot container.

### Jenkins Integration

Follow the instructions in the `letsencrypt` script to convert the new PEM certificates to Keystore format and add it in a Jenkins container.

### Cron Job to renew certificates

Add the following entry in crontab to make certbot check and update certificates every N days:

```bash
0 0 */N * * /<ABSOLUTE_PATH_TO_SCRIPT_DIR>/check_renew.sh --iptables
```

You can use the script `CronScriptLetsEncrypt` for this

## Use openssl to create a self-signed CA and sign CN Certificates

Run the script `openssl_certs` to optionally create a self-signed CA and sign a certificate.

Usage:

```bash
openssl --cn_name <DOMAIN_NAME> --ca_name <CA_NAME> [--ca]
```

- --ca: Optional - Create a new self-signed CA. It will create a pem certificate and a private key
- --ca_name: The name of the CA which will sign the certificate
- --cn_name: The domain which will be assigned to the certificate
