README - IP Core Capteurs de Sol

Objectif
Ce TP consiste à créer et intégrer un composant matériel d'acquisition de capteurs de sol dans un système Nios II / Qsys sur carte DE1. L'objectif est de lire 7 capteurs analogiques via une interface SPI, d'appliquer un seuillage configurable, et de rendre les données accessibles au processeur via le bus Avalon Memory-Mapped.

Architecture du système
L'architecture repose sur un processeur Nios II relié aux différents périphériques grâce à l'Avalon Interconnect.
Les blocs principaux utilisés sont les suivants :

Nios II processor : exécute le programme de contrôle du robot
Avalon Interconnect : assure la communication entre le processeur et les composants
SDRAM controller : contrôleur d'accès à la mémoire externe
PIO : interfaces parallèles pour LEDs et switches
PWM controller : génération des signaux PWM pour les moteurs
capteurs_sol_seuil_avalon_interface : composant personnalisé d'acquisition des capteurs connecté au bus Avalon-MM
Conduit ADC_SPI : interface SPI exportée vers l'ADC externe LTC2308
PLL 2 fréquences : génère une horloge 40 MHz pour l'ADC et une horloge 2 kHz pour le déclenchement périodique


Principe de fonctionnement

Le composant est constitué de deux modules VHDL travaillant conjointement.
Le module capteurs_sol_seuil gère l'acquisition SPI des 7 capteurs analogiques. Il implémente une machine à états qui pilote l'ADC LTC2308 via le protocole SPI, récupère les valeurs sur 12 bits, puis les compare à un seuil configurable pour produire un vecteur binaire.
Pour rendre ce module accessible au processeur Nios II, il est encapsulé dans capteurs_sol_seuil_avalon_interface, qui ajoute une interface Avalon-MM slave 8 bits. Cette interface expose des registres permettant au processeur de configurer le seuil et de lire les valeurs des capteurs.
Grâce à cette architecture, le Nios II peut accéder aux capteurs comme à des adresses mémoire classiques, aussi bien en lecture qu'en écriture.

Interface Avalon Memory-Mapped

L'interface Avalon-MM permet les échanges entre le processeur et le composant capteurs via un système d'adressage mémoire sur 8 bits.
Les principaux signaux utilisés sont :
SignalFonctionchipselectsélection du composant capteurswritedemande d'écriture dans un registrereaddemande de lecture d'un registreaddressadresse du registre (4 bits = 16 registres)writedatadonnée envoyée par le Nios II (8 bits)readdatadonnée retournée au processeur (8 bits)byteenablesélection de l'octet à écrire
Dans ce TP, capteurs_sol_seuil_avalon_interface agit comme un périphérique esclave Avalon-MM. Le processeur Nios II peut donc configurer le seuil de détection et lire les valeurs brutes ou seuillées des capteurs.

Interface Conduit

Le signal ADC_SPI utilise une interface de type Conduit.
Contrairement à Avalon-MM, il ne s'agit pas d'un bus adressé mais de signaux transmis directement hors du système Qsys pour être connectés à l'ADC externe LTC2308.
Le conduit transporte 3 signaux SPI :

ADC_SPI[2] : ADC_CONVST (déclenchement conversion)
ADC_SPI[1] : ADC_SCK (horloge SPI)
ADC_SPI[0] : ADC_SDI (données FPGA → ADC)

Un quatrième signal ADC_SDO (données ADC → FPGA) est en sens inverse.

Génération d'horloges (PLL)
Le composant utilise une PLL pour générer deux horloges à partir de l'horloge système 50 MHz :

clk_40mhz : horloge pour le module capteurs_sol_seuil (fréquence maximale de l'ADC)
clk_2khz : horloge de déclenchement périodique de l'acquisition (500 µs entre chaque lecture)

Cette architecture permet une acquisition automatique et continue des capteurs sans intervention du processeur.

Modèle de programmation
Carte mémoire
Le composant capteurs occupe 9 registres de 8 bits dans l'espace d'adressage du Nios II.
AdresseOffsetNomAccèsDescriptionBase + 0x000x00READY_VECTRObit[7]=data_ready, bits[6:0]=vecteur seuilléBase + 0x010x01NIVEAUR/WSeuil de comparaison (8 bits)Base + 0x020x02DATA0ROValeur brute capteur 0 (8 bits)Base + 0x030x03DATA1ROValeur brute capteur 1 (8 bits)Base + 0x040x04DATA2ROValeur brute capteur 2 (8 bits)Base + 0x050x05DATA3ROValeur brute capteur 3 (8 bits)Base + 0x060x06DATA4ROValeur brute capteur 4 (8 bits)Base + 0x070x07DATA5ROValeur brute capteur 5 (8 bits)Base + 0x080x08DATA6ROValeur brute capteur 6 (8 bits)
RO = Read Only, R/W = Read/Write

Description des registres
READY_VECT (0x00)
Registre de statut et vecteur seuillé.

Bit 7 : data_ready - Indique que de nouvelles données sont disponibles
Bits 6:0 : vect_capt - Vecteur binaire seuillé (1 bit par capteur)

Fonctionnement du vecteur :

Bit = 1 si valeur capteur > NIVEAU (ligne noire détectée)
Bit = 0 si valeur capteur ≤ NIVEAU (fond blanc)

Exemple :
READY_VECT = 0x8E = 1000 1110
→ data_ready = 1 (données valides)
→ vect_capt = 000 1110
→ Capteurs 1, 2, 3 détectent la ligne

NIVEAU (0x01)
Seuil de comparaison pour le seuillage.

Valeur par défaut : 0x6C (108 décimal)
Plage : 0 à 255

Principe :

Capteur analogique donne une valeur 0-255
Si valeur > NIVEAU → ligne détectée
Si valeur ≤ NIVEAU → pas de ligne

Réglage optimal : Dépend de l'éclairage et du contraste ligne/fond. Typiquement entre 80 et 150.

DATA0 à DATA6 (0x02 à 0x08)
Valeurs brutes des 7 capteurs (8 bits).

0 : Fond très clair (blanc)
255 : Surface très foncée (ligne noire)
Valeurs intermédiaires : Gris

Ces registres permettent de calibrer le seuil NIVEAU en observant les valeurs réelles retournées par les capteurs.

Synchronisation des données
Les données sont acquises dans le domaine d'horloge 40 MHz, puis synchronisées vers le domaine Avalon 50 MHz via des flip-flops de métastabilité.
Un snapshot des 7 capteurs est mémorisé à chaque front montant de data_ready, garantissant une lecture cohérente par le Nios II même si l'acquisition est en cours.