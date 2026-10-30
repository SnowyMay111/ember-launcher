#!/usr/bin/env bash
# Один раз создаёт самоподписанный сертификат "Ember Signing" в связке ключей.
# С ним build-app.sh подписывает Ember.app одинаково при каждой сборке, и macOS
# не спрашивает пароль связки ключей после каждой пересборки (с ad-hoc подписью спрашивает).
set -euo pipefail
NAME="Ember Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "Сертификат \"$NAME\" уже есть."
    exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/openssl.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/openssl.cnf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS="ember-$$"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/ember.p12" -passout "pass:$PASS" 2>/dev/null
security import "$TMP/ember.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASS" -T /usr/bin/codesign
echo "Готово: сертификат \"$NAME\" создан."
