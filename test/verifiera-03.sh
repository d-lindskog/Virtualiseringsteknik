#!/usr/bin/env bash

# Verifiering 03 - DMZ
# Testar att webserver och Keycloak fungerar.

INVENTORY="/vagrant/inventory.ini"

PASS=0
FAIL=0

kolla() {
  BESKRIVNING="$1"
  KOMMANDO="$2"
  FORVANTAT="$3"

  RESULTAT=$(eval "$KOMMANDO" 2>&1)

  if echo "$RESULTAT" | grep -q "$FORVANTAT"; then
    echo "[OK] $BESKRIVNING"
    PASS=$((PASS+1))
  else
    echo "[FEL] $BESKRIVNING"
    echo "Förväntade: $FORVANTAT"
    echo "$RESULTAT"
    FAIL=$((FAIL+1))
  fi
}

echo "=============================="
echo "Verifiering 03 - DMZ"
echo "=============================="

echo ""
echo "Webserver"
kolla "webapp är aktiv" \
  "ansible webserver -i $INVENTORY -m shell -a 'systemctl is-active webapp'" \
  "active"

kolla "nginx är aktiv" \
  "ansible webserver -i $INVENTORY -m shell -a 'systemctl is-active nginx'" \
  "active"

kolla "webbsidan fungerar lokalt på webservern" \
  "ansible webserver -i $INVENTORY -m shell -a 'curl -s http://127.0.0.1'" \
  "Webserver i DMZ"

kolla "webbsidan nås från ansible-control" \
  "ansible ansible-control -i $INVENTORY -m shell -a 'curl -s http://192.168.20.30'" \
  "Webserver i DMZ"

echo ""
echo "Keycloak"
kolla "keycloak är aktiv" \
  "ansible keycloak -i $INVENTORY -m shell -a 'systemctl is-active keycloak'" \
  "active"

kolla "Keycloak svarar lokalt" \
  "ansible keycloak -i $INVENTORY -m shell -a 'curl -I -s http://127.0.0.1:8080'" \
  "302 Found"

kolla "Keycloak nås från ansible-control" \
  "ansible ansible-control -i $INVENTORY -m shell -a 'curl -I -s http://192.168.20.10:8080'" \
  "302 Found"

echo ""
echo "Login"
kolla "login redirectar till Keycloak" \
  "curl -I -s http://192.168.20.30/login" \
  "/realms/lab/protocol/openid-connect/auth"

echo ""
echo "=============================="
echo "Godkända tester: $PASS"
echo "Misslyckade tester: $FAIL"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi