# vi
a mini vi editor ... fully in x86 assembler .. 
i wrote it in 1995 ... school time :)

```asm
        db "**************************************************************************",13,10
        db "**                                                                      **",13,10
        db "**                Mini Editeur (c) Nicolas CLERC 1995                   **",13,10
        db "**       Loic CHARDON    Isabelle BREZIAT    Stephanie LOTTAZ           **",13,10
        db "**   Realise en Assembleur dans le cadre d'un TP ... d'assembleur !     **",13,10
        db "**                aj2g30                       aj2g29                   **",13,10
        db "**************************************************************************",13,10
        db 10,10,"Caracteristique du programme :",13,10
        db "    - mode EDITION / mode COMMANDE",13,10
        db "    - buffer de texte de 512 octets",13,10
        db " ___________________________________ ___________________________________",13,10
        db "|Mode EDITION :                     |   mode Commande :                 |",13,10
        db "|   Insertion/Ecrasement            |        Chargement/Sauvegarde      |",13,10
        db "|  (Selection  )                    |       (Recherche)                 |",13,10
        db "|  (Suppression)                    |                                   |",13,10
        db "|___________________________________|___________________________________|",13,10
        
        db "____________________________________________________________________________",13,10
        db "___________COMMANDE__________________|________________EDITION_______________",13,10
        db "                                     |                                      ",13,10
        db "[c] charger un fichier               | [->] deplacement a gauche            ",13,10
        db "[s] sauver un fichier                | [<-] deplacement a droite            ",13,10
        db "[x] efface le caractere courant      | [/\] une ligne plus haut             ",13,10
        db "[d] debut de la ligne courante       | [\/] une ligne plus bas              ",13,10
        db "[f] fin de la ligne courante         | [ESC] mode commande                  ",13,10
        db "[i] Mode edition/Insertion           |                                      ",13,10
        db "[e] Mode edition/Ecrasement          |                                      ",13,10
        db "[u] raffraichissement d'ecran        |                                      ",13,10
        db "[t] debut d'ecran                    |                                      ",13,10
        db "[b] fin d'ecran                      |                                      ",13,10
        db "[h] aide                             |                                      ",13,10
        db "[Q] quitter                          |                                      ",13,10
        db "_____________________________________|______________________________________",13,10
```
