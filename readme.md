Här beskriver vi vår arbets- och tankegång:
Vi började med att sätta upp en ritning och planerade för hur vårt projekt ska fungera visuelt, för att kunna diskutera kring lösningen och få alla att tänka lika.
Sedan satte vi upp själva skelettet genom att strukturera vår vagrantfil för att skapa våra VM, samt sätta strukturen för vårt nätverk och den statiska routningen. Ett problem som dök upp var att vi hade börjat projektet utan att ha med en.gitignore-fil vuilket gjorde det svårt att rensa bort sådana filer som Git redan hade indexerat. Samt så var det lite utmanande att förstå att försat routningen måste ske statiskt innan ssh-nycklarna fanns på plats, kolla med Almir om detta stämmer.. 
Föklara hur vagrantfilrn är uppyggd och trukturerad
Förklara strukturen kring mappar, roller och tasks för ansible.
Förklara de olika Vm:arnas roller
Gör ett testscript
Kontrollera kopplingar och trafik för VM med script.



Keycloak-kontrakt:
URL
realm-namn
client_id
redirect URI
testuser + lösenord

Vault-kontrakt:
URL
auth-metod
secret path
vilka nycklar som finns där, till exempel:
    db_user
    db_password

Databaskontrakt:
host
port
databasnamn
tabellnamn

Webapp-kontrakt:
    vilken callback-path som används
    vilken Vault-path appen läser från
    vilken SQL-fråga som ska köras

Firewall-vm fungerar som central gateway mellan frontend, DMZ och backend.
Den routar trafiken mellan näten och filtrerar vilka anslutningar som tillåts.
Frontend får nå webservern, webservern får nå Keycloak, Vault och databasen, men frontend får inte nå backend direkt.
På så sätt visar lösningen nätsegmentering och principen om minst privilegium.

Regler för brandväggen:
Tillåt
frontend → webserver på HTTP/HTTPS
frontend → keycloak på HTTP/HTTPS om inloggningsflödet kräver direkt åtkomst
webserver → keycloak
webserver → vault på port 8200
webserver → database på port 5432
ansible-control → alla noder på SSH
Blockera
frontend → vault
frontend → database
keycloak → database, om ni inte behöver det
backend → frontend som standard
allt annat som inte uttryckligen behövs