# Virtualiseringsteknik – Segmenterad labbmiljö med Vagrant och Ansible

> En segmenterad labbmiljö byggd i VirtualBox med Vagrant och Ansible. Projektet simulerar ett inloggningsflöde där en användare går till en webserver, autentiseras via Keycloak, varefter webservern hämtar databasuppgifter från Vault och ansluter till databasen. Trafiken separeras mellan frontend, DMZ och backend via en central tre-bent brandvägg.

---

## Syfte

Syftet med labben är att simulera ett säkert applikationsflöde i en segmenterad virtualiserad miljö. En användare ska nå en webserver i DMZ, logga in via Keycloak och därefter få åtkomst till data från en backend-databas. Webservern ska inte ha hårdkodade databasuppgifter, utan i stället hämta dessa från Vault. Samtidigt ska brandväggen kontrollera att endast nödvändig trafik tillåts mellan frontend, DMZ och backend.

Projektet är uppbyggt för att visa flera säkerhetsprinciper i samma lösning:

- nätsegmentering
- central trafikstyrning
- autentisering via separat identitetstjänst
- secrets-hantering via Vault
- åtkomst till backend endast genom kontrollerade flöden

### Övergripande flöde

Projektet är utformat för att simulera följande händelsekedja:

1. Användaren går till webservern i DMZ.
2. Webservern kräver inloggning och skickar användaren vidare till Keycloak.
3. Keycloak autentiserar användaren och returnerar användaren till webservern.
4. Webservern hämtar databasuppgifter från Vault.
5. Webservern ansluter till databasen i backend.
6. Webservern visar data för den inloggade användaren.

Detta gör att projektet visar både autentisering, secrets-hantering, databaskoppling och nätsegmentering i samma labbmiljö.

---

## Innehållsförteckning

- [Syfte](#syfte)
- [Arkitektur](#arkitektur)
- [Miljöer och IP-adresser](#miljöer-och-ip-adresser)
- [Mappstruktur](#mappstruktur)
- [Komponenter](#komponenter)
  - [Vagrantfile](#vagrantfile)
  - [inventory.ini](#inventoryini)
  - [site.yml](#siteyml)
  - [Rollen common](#rollen-common)
  - [Rollen firewall](#rollen-firewall)
- [Krav och förutsättningar](#krav-och-förutsättningar)
- [Kom igång](#kom-igång)
- [Secrets](#secrets)
- [Säkerhetsåtgärder](#säkerhetsåtgärder)
- [Säkerhetsanalys](#säkerhetsanalys)
- [Verifiering](#verifiering)
- [Designval och motivering](#designval-och-motivering)

---

## Arkitektur

![Arkitekturdiagram](docs/architecture.png)

Miljön består av tre nätsegment och en central tre-bent brandvägg:

- **Frontend-net**: `192.168.10.0/24`
- **Service-net / DMZ**: `192.168.20.0/24`
- **Backend-net**: `192.168.30.0/24`

Brandväggen routar och filtrerar trafik mellan näten. Ansible-control ligger i frontend-nätet och används för administration via SSH. Webserver och Keycloak ligger i DMZ. Vault och databas ligger i backend.

---

## Miljöer och IP-adresser

| VM | Roll | IP-adress | Port forwarding | Beskrivning |
|---|---|---|---|---|
| `ansible-control` | Kontrollnod | 192.168.10.100 | Vagrant SSH via NAT | Kör Ansible och hanterar övriga noder |
| `firewall` | Gateway / brandvägg | 192.168.10.1 / 192.168.20.1 / 192.168.30.1 | Vagrant SSH via NAT | Routar och filtrerar trafik mellan frontend, DMZ och backend |
| `webserver` | Applikationsserver | 192.168.20.30 | — | Ska senare exponera webbapplikationen i DMZ |
| `keycloak` | Identitet och token | 192.168.20.10 | — | Ska senare hantera autentisering |
| `vault` | Secrets manager | 192.168.30.10 | — | Ska senare lagra och lämna ut applikationshemligheter |
| `database` | Databasserver | 192.168.30.20 | — | Ska senare innehålla applikationsdata |

---

## Mappstruktur

```text
repo/
├── roles/
│   ├── common/
│   │   └── tasks/
│   │       └── main.yml
│   ├── firewall/
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── handlers/
│   │   │   └── main.yml
│   │   └── templates/
│   │       └── nftables.conf.j2
│   ├── keycloak/
│   ├── vault/
│   ├── database/
│   └── webserver/
├── docs/
│   └── architecture.png
├── inventory.ini
├── site.yml
├── Vagrantfile
├── .gitignore
└── README.md

```


## Komponenter


### Vagrantfile

`Vagrantfile` är projektets infrastrukturdefinition och ansvarar för att bygga upp hela labbtopologin i VirtualBox. Den definierar sex Ubuntu 22.04-baserade virtuella maskiner med fasta IP-adresser och tydliga roller:

- `ansible-control` (`192.168.10.100`) – kontrollnod för Ansible
- `firewall` (`192.168.10.1`, `192.168.20.1`, `192.168.30.1`) – tre-bent brandvägg/router
- `keycloak` (`192.168.20.10`) – identitetstjänst i DMZ
- `webserver` (`192.168.20.30`) – applikationsserver i DMZ
- `vault` (`192.168.30.10`) – secrets manager i backend
- `database` (`192.168.30.20`) – databasserver i backend

Topologin är uppdelad i tre separata interna nät: frontend, service/DMZ och backend. Alla noder behåller samtidigt Vagrants vanliga NAT-adapter för management, paketinstallationer och bootstrap.

Vagrantfilen har också en viktig bootstrap-funktion. Förutom att skapa maskinerna konfigurerar den initial SSH-åtkomst genom att låta `ansible-control` generera en SSH-nyckel, som sedan delas till övriga noder via en synkad katalog. Detta gör att Ansible senare kan administrera noderna över de interna adresserna.

För att kommunikationen mellan zonerna ska fungera provisioneras även statiska routingregler. `firewall` får tre nätkort och IP forwarding aktiveras permanent, vilket gör att den fungerar som central gateway mellan frontend, DMZ och backend. På så sätt används Vagrantfilen både för att skapa infrastrukturen och för att ge miljön en första fungerande nätverks- och administrationskonfiguration.

--- 

### inventory.ini

`inventory.ini` beskriver vilka noder Ansible ska hantera och hur de är grupperade. I projektet används fasta interna IP-adresser, vilket gör inventory-filen enkel att läsa och lätt att felsöka.

Noderna är uppdelade i logiska grupper:

- `control` – innehåller `ansible-control`
- `gateway` – innehåller `firewall`
- `dmz` – innehåller `keycloak` och `webserver`
- `backend` – innehåller `vault` och `database`

Den här indelningen gör det möjligt att rikta olika roller till rätt maskiner. Exempelvis kan brandväggsrollen köras bara mot `gateway`, medan framtida roller för `keycloak`, `vault`, `database` och `webserver` körs mot sina respektive grupper.

I `all:vars` definieras gemensamma anslutningsinställningar för alla noder, till exempel:

- `ansible_user=vagrant`
- sökvägen till den privata SSH-nyckeln
- att host key checking stängs av i labbmiljön

Syftet med inventory-filen är att fungera som kopplingen mellan infrastrukturen som skapas i Vagrant och konfigurationen som hanteras i Ansible.

---

### site.yml

`site.yml` är projektets centrala playbook och fungerar som startpunkt för Ansible-konfigurationen. Den bestämmer vilka roller som ska köras, på vilka grupper och i vilken ordning.

I nuläget används den för att köra två roller:

1. `common` på alla noder
2. `firewall` på gruppen `gateway`

Rollen `common` installerar grundläggande verktyg som behövs för administration och felsökning, till exempel `curl`, `git`, `vim` och `jq`.

Rollen `firewall` konfigurerar brandväggsnoden genom att:
- installera `nftables`
- aktivera IP forwarding
- lägga ut en brandväggskonfiguration
- starta och aktivera tjänsten

Tanken med `site.yml` är att vara en gemensam körpunkt för hela projektet. När fler delar byggs färdigt kan nya roller läggas till, till exempel för `webserver`, `keycloak`, `vault` och `database`, utan att strukturen behöver göras om.

---

### Rollen common

Rollen `common` används för att skapa en gemensam bas på alla noder i labbmiljön. Syftet är att göra maskinerna enklare att administrera, felsöka och bygga vidare på med fler roller.

I den nuvarande versionen installerar rollen grundläggande verktyg som:

- `curl`
- `vim`
- `git`
- `jq`

Dessa paket används främst för administration och testning. `curl` är användbart för att testa webbtjänster och API:er, `jq` för att läsa JSON-svar, `git` för versionshantering och `vim` för redigering direkt i terminalen.

Rollen körs på alla noder via `site.yml` och fungerar som projektets gemensamma grundkonfiguration.

---

### Rollen firewall

Rollen `firewall` används för att konfigurera den centrala brandväggs- och gateway-noden i labbmiljön. Den körs endast på `firewall` och är ansvarig för att möjliggöra och kontrollera trafik mellan frontend, DMZ och backend.

Rollen gör följande:

- installerar `nftables`
- aktiverar IP forwarding permanent
- lägger ut en brandväggskonfiguration
- startar och aktiverar tjänsten `nftables`

Brandväggskonfigurationen bygger på principen *default deny*, vilket innebär att trafik blockeras som standard och att endast uttryckligt tillåtna flöden släpps igenom.

I den nuvarande versionen tillåts bland annat:

- SSH från `ansible-control` till övriga noder
- trafik från frontend till `webserver`
- trafik från frontend till `keycloak`
- trafik från `webserver` till `keycloak`
- trafik från `webserver` till `vault`
- trafik från `webserver` till `database`

Det gör att brandväggen både fungerar som router mellan näten och som säkerhetskontroll för vilka anslutningar som ska tillåtas.

---

### Rollen vault

Rollen `vault` används för att installera och konfigurera HashiCorp Vault på backend-noden `vault` (`192.168.30.10`). Vault fungerar som projektets secrets manager och ansvarar för att lagra och lämna ut känsliga uppgifter, till exempel databasuppgifter, på ett säkert och kontrollerat sätt.

Rollen gör följande:

- lägger till HashiCorps GPG-nyckel för att verifiera paketet
- lägger till HashiCorps officiella apt-repository
- installerar Vault via apt
- skapar dedikerade mappar för konfiguration och data
- lägger ut en Vault-konfigurationsfil via Jinja2-template
- startar och aktiverar Vault-tjänsten

Vault körs som en egen systemanvändare och inte som root, vilket är ett medvetet säkerhetsbeslut för att begränsa behörigheter på servern.

Konfigurationsfilen genereras från en Jinja2-template (`vault.hcl.j2`) där variabler som IP-adress, port och sökvägar hämtas från `defaults/main.yml`. Detta gör rollen återanvändbar och enkel att anpassa utan att ändra i själva konfigurationsfilen.

I labbmiljön är TLS inaktiverat för enkelhetens skull. I en produktionsmiljö ska TLS alltid vara aktiverat för krypterad kommunikation.

Vault exponerar sitt API och webbgränssnitt på port `8200` och kan nås på 
`http://192.168.30.10:8200/ui` inifrån labbmiljön.

I labbmiljön används filbaserad storage (`file`) för att lagra data på disk 
under `/opt/vault/data`. Detta kräver ingen extern databas och passar 
utmärkt i vår labbmiljö.