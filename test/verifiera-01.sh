#!/bin/bash

# Sökväg till inventory-filen
INVENTORY="/vagrant/inventory.ini"

# Lista med noder som ska testas
HOSTS="firewall keycloak webserver vault database"

# Räknare för godkända och misslyckade tester
PASS=0
FAIL=0

echo "========================================"
echo "Verifiering 01 - Kontrollnodens åtkomst"
echo "========================================"
echo ""

# Kontrollera att inventory-filen finns
if [ ! -f "$INVENTORY" ]; then
  echo "FAIL: inventory.ini hittades inte på $INVENTORY"
  exit 1
fi

# Kontrollera att ansible är installerat
if ! command -v ansible >/dev/null 2>&1; then
  echo "FAIL: ansible är inte installerat på kontrollnoden"
  exit 1
fi

echo "--- Ansible ping mot alla noder ---"

# Loopa igenom alla noder och testa en i taget
for host in $HOSTS
do
  echo "Testar $host ..."

  RESULT=$(ANSIBLE_HOST_KEY_CHECKING=False ansible "$host" -i "$INVENTORY" -m ping 2>&1)

  # Om svaret innehåller ordet pong räknas testet som godkänt
  if echo "$RESULT" | grep -q "pong"; then
    echo "OK: Ansible når $host"
    PASS=$((PASS + 1))
  else
    echo "FAIL: Ansible når inte $host"
    echo "$RESULT"
    FAIL=$((FAIL + 1))
  fi

  echo ""
done

echo "========================================"
echo "Resultat: PASS=$PASS FAIL=$FAIL"
echo "========================================"

# Avsluta med felkod 1 om något test misslyckades
if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi