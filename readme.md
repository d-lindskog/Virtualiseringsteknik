Här beskriver vi vår arbets- och tankegång:
Vi började med att sätta upp en ritning och planerade för hur vårt projekt ska fungera visuelt, för att kunna diskutera kring lösningen och få alla att tänka lika.
Sedan satte vi upp själva skelettet genom att strukturera vår vagrantfil för att skapa våra VM, samt sätta strukturen för vårt nätverk och den statiska routningen. Ett problem som dök upp var att vi hade börjat projektet utan att ha med en.gitignore-fil vuilket gjorde det svårt att rensa bort sådana filer som Git redan hade indexerat. Samt så var det lite utmanande att förstå att försat routningen måste ske statiskt innan ssh-nycklarna fanns på plats, kolla med Almir om detta stämmer.. 
Föklara hur vagrantfilrn är uppyggd och trukturerad
Förklara strukturen kring mappar, roller och tasks för ansible.
Förklara de olika Vm:arnas roller
Gör ett testscript
Kontrollera kopplingar och trafik för VM med script.

# Virtualiseringsteknik – Segmenterad labbmiljö med Vagrant och Ansible

> En segmenterad labbmiljö byggd i VirtualBox med Vagrant och Ansible. Miljön består av en tre-bent brandvägg mellan frontend, DMZ och backend, där Ansible används för att konfigurera noderna och tillämpa grundläggande säkerhetsåtgärder.

---

## Innehållsförteckning

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
