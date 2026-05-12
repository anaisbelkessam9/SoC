Objectif

Ce TP a pour but de comprendre l’intégration d’un composant matériel personnalisé dans un système Nios II conçu sous Qsys sur carte DE1.
L’objectif principal est de créer un registre 16 bits accessible depuis le processeur via le bus Avalon Memory-Mapped, puis d’afficher son contenu sur les afficheurs 7 segments.

Architecture du système

L’architecture repose sur un processeur Nios II relié aux différents périphériques grâce à l’Avalon Interconnect.

Les blocs principaux utilisés sont les suivants :

Nios II processor : exécute le programme logiciel.
Avalon Interconnect : assure la communication entre le processeur et les différents composants.
On-chip memory : mémoire interne intégrée dans le FPGA.
SRAM / SDRAM controllers : contrôleurs permettant l’accès aux mémoires externes.
PIO : interfaces parallèles utilisées pour les LEDs, boutons, switches et afficheurs.
reg16_avalon_interface : composant matériel personnalisé connecté au bus Avalon-MM.
Conduit to_hex_export : signal exporté vers le décodeur des afficheurs 7 segments.
Principe de fonctionnement

Le tutoriel montre comment intégrer un composant VHDL personnalisé dans un système Qsys.

Le composant reg16 correspond à un registre 16 bits simple.
Afin qu’il puisse communiquer avec le processeur Nios II, il est encapsulé dans le module reg16_avalon_interface, qui ajoute une interface Avalon-MM slave.

Grâce à cette interface, le processeur peut accéder au registre comme à une adresse mémoire classique, aussi bien en lecture qu’en écriture.

Interface Avalon-MM

L’interface Avalon Memory-Mapped permet les échanges entre le processeur et les périphériques via un système d’adressage mémoire.

Les principaux signaux utilisés sont :

Signal	Fonction
chipselect	sélection du composant
write	demande d’écriture
read	demande de lecture
writedata	donnée envoyée par le Nios II
readdata	donnée retournée au processeur
byteenable	sélection des octets à écrire

Dans ce TP, reg16_avalon_interface agit comme un périphérique esclave Avalon-MM.
Le processeur Nios II peut donc modifier directement la valeur contenue dans le registre.

Interface Conduit

Le signal to_hex_export utilise une interface de type Conduit.

Contrairement à Avalon-MM, il ne s’agit pas d’un bus adressé mais simplement d’un signal transmis directement hors du système Qsys afin d’être connecté aux afficheurs 7 segments.