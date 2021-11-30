;********************************************************
;** Fichier contenant les macro definies en cours
;** ainsi que les constantes
;**

CR      equ 13
KEY_DOWN    equ 80
KEY_UP      equ 72
KEY_LEFT    equ 75
KEY_RIGHT   equ 77
DEL     equ 08
KEY_ESC equ 27
BELL    equ 07
SPACE   equ 32

MODE80x25       equ 03

gotoxy MACRO x,y
        mov ah,2
        mov bh,0        ; page 0
        mov dl,x
        mov dh,y
        int 10h
ENDM

screen MACRO car,attr
        mov ah,08h
        mov bh,0
        int 10h
        mov car,al
        mov attr,ah
ENDM

init_rs232 MACRO config,etat
        mov ah,0
        mov al,config
        int 14h
        mov etat,ax
ENDM

lit_rs232 MACRO car,etat
        mov ah,02
        int 14h
        mov car,al
        mov etat,ah
ENDM

ecrit_rs232 MACRO car,etat
        mov ah,1
        mov al,car
        int 14h
        mov etat,ah
ENDM

lit_car_AE MACRO car    ; lit_car Avec Echo !
        mov ah,01h
        int 21h
        mov car,al
ENDM

lit_car_SE MACRO car    ; lit_car Sans Echo !
        mov ah,08h
        int 21h
        mov car,al
ENDM

getkey MACRO            ; le caractere lu se retrouve dans AL
;        mov ah,08h
;        int 21h
        lit_car_SE al
ENDM


ecrit_car MACRO car
        mov ah,02h
        mov dl,car
        int 21h
ENDM

attendre_CR MACRO
local boucle
boucle:
        lit_car_SE ah
        cmp ah,CR
        jne boucle
ENDM

saisie_chaine_SE MACRO chaine,lng
local fin,boucle,do_bell,do_del
        mov bx,0
        lea si,chaine
boucle:
        mov ah,08h      ; saisie sans echo
        int 21h
        cmp al,DEL      ; on verifie si la touche DEL a ete presser
        je do_del       ; on traite l'effacement
        cmp al,CR       ; on a presser ENTREE ?
        je fin          ; -> on va a la fin
        cmp bx,lng-1    ; longueur maximale ?
        je do_bell      ; -> on beep
        mov byte ptr [si][bx],al        ; on stocke le carac
        ecrit_car '*'   ; on affiche une etoile
        inc bx          ; on incremente la taille
        jmp boucle      ; on retourne au debut
do_bell:
        ecrit_car BELL  ; on envoie le caractere BELL ( bip )
        jmp boucle      ; on retourne au debut
do_del:
        cmp bx,0        ; pas de carac saisie
        je do_bell      ;  -> on bip
        ecrit_car DEL   ; on recule d'un cran
        ecrit_car SPACE ; on efface le caractere
        ecrit_car DEL   ; on recule
        dec bx          ; on decremente la longueur
        jmp boucle      ; on retourne au debut
fin:
        mov byte ptr [si][bx],'$'       ; caractere fin de chaine !
ENDM

saisie_chaine_AE MACRO chaine,lng
local fin,boucle,plus_de_place,del_prem_pos,do_bell,do_del
        mov bx,0
        lea si,chaine
boucle:
        mov ah,01h      ; saisie avec echo
        int 21h
        cmp al,DEL      ; on verifie si la touche DEL a ete presser
        je do_del       ; on traite l'effacement
        cmp al,CR       ; on a presser ENTREE ?
        je fin          ; -> on va a la fin
        cmp bx,lng-1    ; longueur maximale ?
        je plus_de_place; -> on efface le carac et on bip
        mov byte ptr [si][bx],al        ; on stocke le carac
        inc bx          ; on incremente la taille
        jmp boucle      ; on retourne au debut
plus_de_place:
        ecrit_car DEL
        ecrit_car SPACE
        ecrit_car DEL
        jmp do_bell
del_prem_pos:
        ecrit_car SPACE
do_bell:
        ecrit_car BELL  ; on envoie le caractere BELL ( bip )
        jmp boucle      ; on retourne au debut
do_del:
        cmp bx,0        ; pas de carac saisie
        je del_prem_pos ;  -> on affiche un espace et on bip
        ecrit_car SPACE ; on efface le caractere car le carac DEL a deja ete 
                        ; affiche
        ecrit_car DEL   ; on recule
        dec bx          ; on decremente la longueur
        jmp boucle      ; on retourne au debut
fin:
        mov byte ptr [si][bx],'$'       ; caractere fin de chaine !
ENDM



affiche MACRO chaine
        mov ah,09h
        lea dx,chaine
        int 21h
ENDM


mode_ecran MACRO mode
        mov ah,0
        mov al,mode
        int 10h
ENDM
