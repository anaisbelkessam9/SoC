TP Codesign — IP Core PWM pour Moteurs CuteCar

Objectif
Ce TP consiste à créer un composant matériel personnalisé pour générer des signaux PWM (Pulse Width Modulation) permettant de contrôler 2 moteurs DC via le bus Avalon Memory-Mapped dans un système Nios II / Qsys sur carte DE1.
Le composant génère 4 sorties PWM indépendantes pour un contrôle bidirectionnel des moteurs (avant/arrière) via des ponts en H.

Architecture utilisée
Le système est organisé autour d'un processeur Nios II connecté à un Avalon Interconnect.
Les principaux blocs sont :

Nios II processor : exécute le programme de contrôle des moteurs
Avalon Interconnect : relie le processeur aux mémoires et périphériques
SDRAM controller : interface vers la mémoire externe
PIO : ports parallèles pour LEDs, switches
pwm_avalon_interface : composant personnalisé PWM connecté au bus Avalon-MM
Conduit pwm_export : 4 sorties PWM exportées vers les moteurs


Principe du composant
Le composant est constitué de deux modules VHDL :
pwm_core.vhd
Module de base qui génère un signal PWM.
Principe de fonctionnement :

Un compteur cyclique compte de 0 à period-1
Le signal PWM est à '1' quand counter < duty, sinon '0'
Le rapport cyclique (duty cycle) détermine la vitesse du moteur

Entrées :

period : période du signal en cycles d'horloge
duty : durée de l'état haut (0 à period)
enable : activation du PWM

Sortie :

pwm_out : signal PWM généré

pwm_avalon_interface.vhd
Wrapper qui encapsule deux instances de pwm_core et ajoute une interface Avalon-MM slave.
Le processeur Nios II peut ainsi contrôler les moteurs en écrivant dans des registres mémoire.

Interface Avalon Memory-Mapped
L'interface Avalon-MM permet une communication par adresses entre le Nios II et le composant PWM.
Signaux importants :
SignalRôlechipselectsélectionne le composant PWMwritedemande une écriture dans un registrereaddemande une lecture d'un registreaddresssélectionne le registre (2 bits = 4 registres)writedatadonnée envoyée par le Nios II (32 bits)readdatadonnée lue par le Nios II (32 bits)
Dans ce TP, pwm_avalon_interface est un slave Avalon-MM. Le Nios II peut écrire les paramètres PWM (période, duty cycle, enable) dans les registres.

Interface Conduit
Le signal pwm_export[1:0] est un Conduit.
Contrairement à Avalon-MM, ce n'est pas un bus adressé. Ce sont simplement les 2 signaux PWM exportés hors du système Qsys vers le top-level VHDL.
Dans le top-level, ces signaux sont routés vers les broches GPIO connectées aux ponts en H des moteurs.

Modèle de programmation
Carte mémoire
Le composant PWM occupe 16 octets (4 registres de 32 bits) dans l'espace d'adressage du Nios II.
AdresseOffsetNomAccèsDescriptionBase + 0x000x00PERIODR/WPériode PWM commune (en cycles d'horloge)Base + 0x040x04DUTY_LEFTR/WDuty cycle moteur gauche (0 à PERIOD)Base + 0x080x08DUTY_RIGHTR/WDuty cycle moteur droit (0 à PERIOD)Base + 0x0C0x0CCONTROLR/WActivation des moteurs
Description des registres
PERIOD (0x00) :

Définit la période du signal PWM pour les deux moteurs
Valeur par défaut : 0x1388 (5000 décimal)
Calcul de la fréquence : F_pwm = 50 MHz / PERIOD
Exemple : PERIOD = 5000 → F_pwm = 10 kHz

DUTY_LEFT (0x04) / DUTY_RIGHT (0x08) :

Définit le rapport cyclique (temps à l'état haut)
Plage : 0 à PERIOD
Vitesse du moteur : V% = (DUTY / PERIOD) × 100
Exemple : DUTY = 2500, PERIOD = 5000 → vitesse 50%

CONTROL (0x0C) :

Bit 0 : ENABLE_LEFT (1 = moteur gauche activé)
Bit 1 : ENABLE_RIGHT (1 = moteur droit activé)
Bits 31-2 : Réservés



Résultats
Le composant PWM a été intégré avec succès dans le système Nios II. Le processeur peut contrôler la vitesse et le sens de rotation des deux moteurs indépendamment en écrivant simplement dans les registres mémoire.
Fréquence PWM mesurée : 10 kHz (conforme)
Contrôle de vitesse : Fonctionnel de 0% à 100%
Tests effectués : Avancer, reculer, tourner gauche/droite