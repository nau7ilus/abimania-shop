#!/bin/sh

# Inherited https://github.com/josue/docker-caddy-reverse-proxy

# parameters
DOMAIN=${1:-"abimania.local"}
DOMAIN_URL="https://${DOMAIN}"
CERTS_DIR="${PWD}/caddy/certs"
CERT_PEM_FILE="${CERTS_DIR}/local.cert.pem"
KEY_PEM_FILE="${CERTS_DIR}/local.key.pem"

echo "-- Installing mkcert ..."
mkcert -install

mkdir -p ${CERTS_DIR}

echo "-- Creating and installing local SSL certificates for domain: ${DOMAIN} + *.${DOMAIN} ..."
mkcert -cert-file ${CERT_PEM_FILE} -key-file ${KEY_PEM_FILE} "${DOMAIN}" "*.${DOMAIN}"

echo "-- Complete!"
echo
echo "- Now you can run: docker-compose up"
echo "- Open browser to domain: ${DOMAIN_URL}"