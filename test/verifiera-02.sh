#!/bin/bash

# Sökväg till inventory-filen som Ansible använder för att hitta noderna
INVENTORY="/vagrant/inventory.ini"

# Räknare för godkända och misslyckade tester
PASS=0
FAIL=0

echo "========================================"
echo "Verifiering 02 - Routing efter reboot"
echo "========================================"
echo ""

# Kontrollera att inventory-filen finns
# Utan den vet inte Ansible vilka noder som ska testas
if [ ! -f "$INVENTORY" ]; then
  echo "FAIL: inventory.ini hittades inte"
  exit 1
fi

# Kontrollera att ansible är installerat på kontrollnoden
if ! command -v ansible >/dev/null 2>&1; then
  echo "FAIL: ansible är inte installerat"
  exit 1
fi

# Funktion som testar en nod i taget
# Den gör tre saker:
# 1. Startar om noden
# 2. Kontrollerar att noden kommer tillbaka och svarar på Ansible ping
# 3. Kontrollerar att de statiska rutterna fortfarande finns kvar efter reboot
check_route() {
  HOSTNAME=$1
  ROUTE1=$2
  ROUTE2=$3

  echo "Startar om $HOSTNAME ..."
  ansible "$HOSTNAME" -i "$INVENTORY" -b -m reboot >/dev/null 2>&1

  echo "Kontrollerar att $HOSTNAME svarar igen ..."
  if ansible "$HOSTNAME" -i "$INVENTORY" -m ping | grep -q "pong"; then
    echo "OK: $HOSTNAME svarar efter reboot"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $HOSTNAME svarar inte efter reboot"
    FAIL=$((FAIL + 1))
    echo ""
    return
  fi

  echo "Kontrollerar routes på $HOSTNAME ..."
  RESULT=$(ansible "$HOSTNAME" -i "$INVENTORY" -m shell -a "ip route" 2>&1)

  # Kontroll av första route
  if echo "$RESULT" | grep -q "$ROUTE1"; then
    echo "OK: $HOSTNAME har route $ROUTE1"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $HOSTNAME saknar route $ROUTE1"
    FAIL=$((FAIL + 1))
  fi

  # Kontroll av andra route
  if echo "$RESULT" | grep -q "$ROUTE2"; then
    echo "OK: $HOSTNAME har route $ROUTE2"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $HOSTNAME saknar route $ROUTE2"
    FAIL=$((FAIL + 1))
  fi

  echo ""
}

# Test av webservern i DMZ
# Efter reboot ska den fortfarande ha routes till frontend och backend via firewall
check_route "webserver" "192.168.10.0/24 via 192.168.20.1" "192.168.30.0/24 via 192.168.20.1"

# Test av vault i backend
# Efter reboot ska den fortfarande ha routes till frontend och service-nätet via firewall
check_route "vault" "192.168.10.0/24 via 192.168.30.1" "192.168.20.0/24 via 192.168.30.1"

echo "========================================"
echo "Resultat: PASS=$PASS FAIL=$FAIL"
echo "========================================"

# Om något test misslyckas avslutas scriptet med felkod 1
# Det gör det tydligt att verifieringen inte blev godkänd
if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi