CERT_DIR="../.cert"

echo "Creating a self-signed SSL certificate."

if [ ! -d "$CERT_DIR" ]; then
  mkdir -p "$CERT_DIR"
fi

openssl req -x509 -newkey rsa:2048 -keyout "${CERT_DIR}/private.key" \
    -out "${CERT_DIR}/certificate.crt" -days 365 -nodes -subj "/CN=placeholder.com"
