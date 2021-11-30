;*******************************************************
;** VI : mini editeur de texte
;** le programme est un modele .COM
;**
;** Les lignes sont limitees a 79 caracteres ( le 80e etant le Next Line )
;** les 2 lignes du bas de l'ecran sont pour l'affichage des positions
;**     et du mode en cours, ainsi que pour une ligne de delimitation
;**
;** Par manque de temps , il manque une fonction de saisie de nom de fichier
;**     -> les chargement et sauvegarde se font dans un fichier de nom
;**        FICHIER.TXT
;** Compilation :
;**     MASM 6.0B : ml vi.asm /AT
;**     MASM 5.1  : masm vi.asm,,,,
;**                 link vi.obj,,,,
;**                 exe2bin vi.exe vi.com
;**
;** NE PAS UTILISER TASM ( BUG lors de l'initialisation du pointeur de pile )


.186    ; activation des instructions 80186 ( Pusha, Popa )

include macro.inc       ; on inclut les macros

;************************************************ DEFINITION DE CONSTANTE
TAILLE_TEXTE    equ 512 ; taille du buffer de texte
MODE_ECRASE     equ 1
MODE_INSERE     equ 2
MODE_COMMANDE   equ 3
FIN_BUFFER      equ 26  ; code indiquant la fin du texte ds le buffer
NEW_LINE        equ 10  ; code indiquant une nouvelle ligne ds le buffer




code SEGMENT
        ASSUME cs:code,ds:code,es:code,ss:code
        ORG 100h
begin:        
        jmp debut_prog
;**************************************************************** DONNEE
debut_donnee:
include pres.dta
include aide.dta
txt_commande    db "MODE COMMANDE  $"
txt_ecrase      db "MODE ECRASEMENT$"
txt_insere      db "MODE INSERTION $"
txt_code_aide   db "[ESC]+h = Ecran d'aide$"

;-- 
mode    db MODE_COMMANDE        ; le mode est initialise en commande

;-- variable concernant la gestion de l'affichage
pos_lig db 0    ; position ligne a l'ecran : evite d'appeler l'interruption
pos_col db 0    ; position collone a l'ecran

;-- variable concernant la gestion du buffer de texte
pos_txt dw 0    ; offset dans le buffer de texte
nb_lig dw 0     ; nb de ligne dans le texte
lng_txt dw 0    ; longueur du texte ( code de fin non inclu, new_line inclu)

;-- variable concernant la ligne en cours d'edition
;num_lig dw 1    ; ligne en cours ds le texte ( de 1 a ... )
lng_lig db 0    ; longueur de la ligne en cours ( <79 )
ofs_lig dw 0    ; offset de depart de la ligne dans le buffer

;-- divers
nomfic  db "FICHIER.TXT",0
;-- zone memoire ou sera stocke le texte !
texte db TAILLE_TEXTE dup(0)    ; buffer de texte



align 4         ; alignement sur le mot 32 bit pour accelerer les acces mem
pile      db 256 dup (?)        ; reservation espace pile
finpile   equ $
;************************************************************* PROCEDURE
aff_chiffre PROC near   ; ds AX le nombre a ecrire
; pour le moment limite a 2 caracta ( nb de 00 a 99 ! )
        mov bl,10
        div bl          ; ax=ax/bl -> ah=reste,al=quot
        push ax
        add al,'0'
        ecrit_car al
        pop bx
        mov al,bh       ; on recupere le reste
        add al,'0'
        ecrit_car al
        ret
aff_chiffre ENDP


maj_pos_ecr PROC near   ; ecris a l'ecran la position ds le fichier
; cette fonction affiche a l'ecran les coordonnee du curseur dans le 
; texte qui a ete saisi
        gotoxy 2,24
        mov al,[pos_col]
        mov ah,0
        call aff_chiffre
        ecrit_car ':'
        mov al,byte ptr [pos_lig]
        xor ah,ah
        call aff_chiffre
        gotoxy [pos_col],[pos_lig]
        ret
maj_pos_ecr ENDP

aff_mode PROC near
; cette procedure affiche le mode courant 
        gotoxy 60,24 
        mov al,[mode]
        cmp al,MODE_COMMANDE
        jne pascom
        affiche txt_commande
        jmp finaffmode
pascom: 
        cmp al,MODE_ECRASE
        jne pasecrase
        affiche txt_ecrase
        jmp finaffmode
pasecrase:
        affiche txt_insere

finaffmode:
        gotoxy [pos_col],[pos_lig]
        ret
aff_mode ENDP

aff_info PROC near      
; cette fonction affiche la ligne d'info en bas de l'ecran
        gotoxy 0,23     
        mov ah,0ah      ; fonction ecriture d'un car n fois
        mov bh,0        ; page ecr 0
        mov bl,7        ; couleur grise
        mov cx,80       ; 80 fois 
        mov al,'-'      
        int 10h
        call maj_pos_ecr ; en reecrit la position dans le curseur
        call aff_mode   ; on affiche le mode
        gotoxy 10,24
        affiche txt_code_aide
        gotoxy [pos_col],[pos_lig]
        ret
aff_info ENDP

init_var_lig PROC near
; cette procedure permet de remplir les variable concernant la ligne courante
; ( longueur, offset de depart , ... )
        mov bx,0        ; ofset 0 pour commencer
        mov cx,word ptr [pos_lig]
        inc cx
b_ivl1:
        dec cx
        jz ligne_trouve
b_ivl2:         ; boucle de parcours de la ligne 
                mov al,byte ptr [texte+bx]
                cmp al,NEW_LINE
                je s_ivl1       ; si NEW_LINE -> s_ivl1
                cmp al,FIN_BUFFER ; si fin buffer -> s_ivl1
                je s_ivl1
                inc bx          ; on avance d'un cran dans le buffer
                jmp b_ivl2
s_ivl1:         
                inc bx  ; on avance pour sauter le NEW_LINE
                jmp b_ivl1
ligne_trouve:
        mov word ptr [pos_txt],bx       ; on se positionne au debut de la ligne
        mov word ptr [ofs_lig],bx
        mov cl,0        ; maintenant on calcule la longueur de la ligne
b_ivl3:
                mov al,byte ptr [texte+bx]
                cmp al,NEW_LINE
                je fin_lig_cour
                cmp al,FIN_BUFFER 
                je fin_lig_cour
                inc cl  ; la lng est incremente
                inc bx  ; l'ofs est augmente
                jmp b_ivl3
fin_lig_cour:
        mov byte ptr [lng_lig],cl
        ret
init_var_lig ENDP


init_var PROC near
local boucle
; cette procedure scan le buffer pour determiner la longueur, le nb de ligne
; afin d'initialiser les variables
        mov bx,0        ; bx correspond a l'index
        mov [nb_lig],1  ; une ligne par defaut : la premiere
b_iv1:  ; = boucle_init_var1
        mov al,byte ptr [texte+bx]
        cmp al,FIN_BUFFER
        je fin_init_var
        cmp al,NEW_LINE
        jne s_iv1
        inc word ptr [nb_lig]
s_iv1:
        inc bx
        jmp b_iv1
fin_init_var:
        mov word ptr [lng_txt],bx       ; on initialise la longueur du fichier
        mov word ptr [pos_lig],0        ; on debute sur la premiere ligne
        mov word ptr [pos_col],0        ; on debute sur la premiere collonne
        mov word ptr [pos_txt],0        ; on debute a l'offset 0
        call init_var_lig               ; on initialise les infos sur la ligne courante
        ret
init_var ENDP

init_vi PROC near        ; init les variables
        mov word ptr [pos_lig],0
        mov word ptr [pos_col],0
;        mov word ptr [pos_txt],0        ; offset ds le buffer
;        mov word ptr [pos_lig],1        ; premiere ligne du fichier
        mov byte ptr [texte],FIN_BUFFER ; on positionne la fin de texte au debut du buffer
        call init_var   ; on initialise les variable
        ret
init_vi ENDP


sup_carac PROC near
; cette fonction supprime le caractere courant et decale le reste du texte
; et ce jusq'au carac FIN_BUFFER. Cette fonction ne gere pas les info 
; concernant la ligne courante et le buffer
        mov bx,word ptr [pos_txt]
        
b_sc1:
        mov al,byte ptr [texte+bx+1]
        mov byte ptr [texte+bx],al
        cmp al,FIN_BUFFER
        je fin_sup_carac
        inc bx
        jmp b_sc1
fin_sup_carac:
        ret
sup_carac ENDP

ins_carac PROC near
; cette fonction decale le texte a partir de la position pos_txt courante et
; ce jusqu'a la fin du texte. Elle n'effectue aucune verification quand a la
; taille du buffer
        inc word ptr [lng_txt]  ; on incremente la longueur du texte
        mov bx,word ptr [pos_txt]
        inc bx
        mov al,byte ptr [texte+bx-1]    ; on recupere le carac a deplace
b_ic1:
        mov ah,byte ptr [texte+bx]      ; on sauvegarde le caract de la nouvelle pos
        mov byte ptr [texte+bx],al      ; on ecrit le carac a deplace
        cmp al,FIN_BUFFER               ; a t on deplacer le carac fin de buf?
        je fin_ins_carac                ; si oui on stop
        xchg al,ah                      ; al=ah ( nouveau carac a deplacer )
        inc bx
        jmp b_ic1
fin_ins_carac:
        ret
ins_carac ENDP

update_screen PROC near
        gotoxy 0,0
        mov bx,0
b_us1:
        mov al,byte ptr [texte+bx]
        cmp al,FIN_BUFFER
        je fin_us
        ecrit_car al    ; on ecrit le carac a l'ecran
        inc bx          ; on avance le ptr du buffer
        cmp al,NEW_LINE ; si le carac affiche n'est pas NEW_LINE
        jne b_us1       ; on passe au suivant 
        ecrit_car CR    ; on retour au debut de la collone
        jmp b_us1
fin_us:
        gotoxy [pos_col],[pos_lig]
        ret
update_screen ENDP

update_line PROC near
        gotoxy 0,[pos_lig]
        mov cx,80
b_ul1:
                ecrit_car ' '
        loop b_ul1
        gotoxy 0,[pos_lig]
        mov bx,word ptr [ofs_lig]
b_ul2:
        mov al,byte ptr [texte+bx]
        cmp al,NEW_LINE
        je fin_ul
        cmp al,FIN_BUFFER
        je fin_ul
        ecrit_car al
        inc bx
        jmp b_ul2
fin_ul:
        ret
update_line ENDP

sauver_fichier PROC near
; cette fonction sauve le fichier sous le nom NOMFIC
        mov ah,3ch      ; CREATION avec Handle
        mov cx,0
        mov dx,offset nomfic
        int 21h
        jc err_sf       ; si erreur on BIP et sort
        mov bx,ax       ; bx=handle du fichier
        mov ah,40h      ; ECRITURE avec Handle
        mov cx,word ptr [lng_txt]
        mov dx,offset texte
        int 21h
        mov ah,3eh      ; FERMETURE avec handle
        int 21h
        jmp fin_sf
err_sf:
        ecrit_car BELL
fin_sf:        
        ret
sauver_fichier ENDP

charger_fichier PROC near
; cette fonction charge le fichier de nom NOMFIC
        mov ah,3dh      ; OUVERTURE avec Handle
        mov al,0        ; en lecture
        mov cx,0
        mov dx,offset nomfic
        int 21h
        jc err_cf       ; si erreur on BIP et sort
        mov bx,ax       ; bx=handle du fichier
        mov ah,3fh      ; LECTURE avec Handle
        mov cx,TAILLE_TEXTE
        mov dx,offset texte
        int 21h
        jc err_cf
        mov word ptr [lng_txt],ax       ; on recopie la longueur du fichier
        push ax
        mov ah,3eh      ; FERMETURE avec handle
        int 21h
        pop bx
        mov byte ptr [texte+bx],FIN_BUFFER
        call init_var   ; on init les var du fichier
        mode_ecran MODE80x25
        call update_screen
        call aff_info
        jmp fin_cf
err_cf:
        ecrit_car BELL
fin_cf:        
        ret
charger_fichier ENDP


;******** gestion du dispatching en fonction des modes

dispatch_mode_insertion PROC near
        cmp word ptr [lng_txt],TAILLE_TEXTE-1
        je dmi_beep     ; si le texte a sa longueur maxi -> BIP !
        cmp al,CR
        je traite_NL
        cmp al,32
        jb dmi_beep    ; si al<32 -> BIP !
        cmp byte ptr [lng_lig],78
        ja dmi_beep     ; si la ligne a 78 carac -> BIP
        push ax
        call ins_carac  ; on decale le buffer de texte
        mov bx,word ptr [pos_txt]
        pop ax  ; on recupere ax
        mov byte ptr [texte+bx],al      ; on ecrit le carac dans le buffer
        inc byte ptr [pos_col]          ; on avance d'une colone
        inc byte ptr [lng_lig]          ; la longueur de la ligne est augmente
        inc word ptr [pos_txt]          ; on avance d'un cran dans le buffer
        call update_line
        gotoxy [pos_col],[pos_lig]
        jmp fin_dmi
traite_NL:
        cmp word ptr [nb_lig],23
        je dmi_beep     ; on a deja 23 lignes -> BIP !
        call ins_carac  ; on decale le buffer de texte
        mov bx,[pos_txt]
        mov byte ptr [texte+bx],NEW_LINE ; on insere la nouvelle ligne
        inc word ptr [nb_lig]   ; on incremente le nb de ligne du texte
        inc byte ptr [pos_lig]  ; on passe a la ligne suivante
        mov byte ptr [pos_col],0; on passe en debut de ligne
        call init_var_lig
        mode_ecran MODE80x25
        call update_screen
        call aff_info
        jmp fin_dmi
dmi_beep:
        ecrit_car BELL
fin_dmi:
        ret
dispatch_mode_insertion ENDP

dispatch_mode_ecrase PROC near
        cmp al,32
        jb dme_beep    ; si al<32 -> BIP !
        mov bx,word ptr [pos_txt]
        mov ah,byte ptr [texte+bx]
        cmp ah,NEW_LINE
        je dme_beep
        cmp ah,FIN_BUFFER
        je dme_beep
        mov [texte+bx],al
        inc byte ptr [pos_col]
        inc word ptr [pos_txt]
        call update_line
        gotoxy [pos_col],[pos_lig]
        jmp fin_dme
dme_beep:        
        ecrit_car BELL
fin_dme:        
        ret
dispatch_mode_ecrase ENDP

dispatch_mode_commande PROC near
        cmp al,'Q'
        jne sc1
                mov ax,4C00h    ; return code = 0
                int 21h
                jmp fin_disp_cmd
sc1:
        cmp al,'i'
        jne sc3
                mov byte ptr [mode],MODE_INSERE
                call aff_mode
                jmp fin_disp_cmd
sc3:                 
        cmp al,'e'
        jne sc4
                mov byte ptr [mode],MODE_ECRASE
                call aff_mode
                jmp fin_disp_cmd
sc4:
        cmp al,'h'
        jne sc5
                mode_ecran MODE80x25
                affiche aide_dta
                attendre_CR
                mode_ecran MODE80x25
                call aff_info
                call update_screen
                gotoxy [pos_col],[pos_lig]
                jmp fin_disp_cmd
sc5:
        cmp al,'s'
        jne sc6
                call sauver_fichier
                ecrit_car BELL
                jmp fin_disp_cmd
sc6:
        cmp al,'c'
        jne sc7
                call charger_fichier
                ecrit_car BELL
                jmp fin_disp_cmd
sc7:
        cmp al,'x'      ; supprimer carac courant ne marche pas pour NL
        jne sc8
                mov bx,word ptr [pos_txt]
                mov al,[texte+bx]
                cmp al,NEW_LINE
                je fsc8_err
                cmp al,FIN_BUFFER
                je fsc8_err
                call sup_carac
                dec word ptr [lng_txt]
                dec byte ptr [lng_lig]
                call update_line
                gotoxy [pos_col],[pos_lig]
                jmp fin_disp_cmd
fsc8_err:       
                ecrit_car BELL
fsc8:
                jmp fin_disp_cmd
sc8:
fin_disp_cmd:
        ret
dispatch_mode_commande ENDP

dispatch_key PROC near
; cette procedure permet d'appeler les procedure de traitement
; ( pour les fleches et ESC directement, pour les autres appelle d'une autre
; procedure ). Le code du caractere a traiter est contenu dans le registre AL
debut_dispatch_key:
        lit_car_SE al
        cmp al,0        ; pour eviter le code precedent les code etendus
        je code_etendu
        mov bx,word ptr [pos_txt]       ; ca evite de la remettre a chaque fois !
        cmp al,KEY_ESC
        jne s0
                mov byte ptr [mode],MODE_COMMANDE
                call aff_mode
                jmp fin_dispatch_key
s0:
        jmp s5
code_etendu:        
        lit_car_SE al
s1:
        cmp al,KEY_UP
        jne s2
                ; traitement de UP
                cmp byte ptr [pos_lig],0
                je fin_ku       ; utilisation d'un double saut car les saut
                                ; conditionel n'admettent qu'un offset -127 -> 128
                dec byte ptr [pos_lig]  ; on passe a la ligne prec
                mov byte ptr [pos_col],0; colonne 0
                call init_var_lig       ; on init les var pour la nouvelle ligne
                call maj_pos_ecr
fin_ku:
                jmp fin_dispatch_key
s2:
        cmp al,KEY_DOWN
        jne s3
                ; traitement de DOWN
                mov al,byte ptr [nb_lig]
                dec al
                cmp byte ptr [pos_lig],al 
                je fin_kd       ; on est sur la derniere ligne
                inc byte ptr [pos_lig]  ; on passe a la ligne suivante
                mov byte ptr [pos_col],0;colonne 0
                call init_var_lig       ; on init les var de la ligne
                call maj_pos_ecr        ; on affiche la position
fin_kd:
                jmp fin_dispatch_key
s3:
        cmp al,KEY_LEFT
        jne s4
                ; traitement de LEFT
                ;cmp byte ptr [pos_col],0
                ;je fin_dispatch_key
                cmp bx,0        ; bx = 0?
                je fin_kl       ; oui -> on est au debut du texte
                cmp byte ptr [texte+bx-1],NEW_LINE ; carac prec=FIN ligne prec?
                je fin_kl       ; oui -> on stop
                dec byte ptr [pos_col]  ; on recule d'une collone
                dec word ptr [pos_txt]  ; on recule d'un carac dans le buffer
                call maj_pos_ecr
fin_kl:
                jmp fin_dispatch_key
s4:
        cmp al,KEY_RIGHT
        jne s5
                ; traitement de RIGHT
                ;cmp byte ptr [pos_col],79
                ;je fin_kr
                mov ah,byte ptr [texte+bx]
                cmp ah,FIN_BUFFER
                je fin_kr       ; si fin de buffer -> on peut pas avancer
                cmp ah,NEW_LINE
                jne s_non_nl    ; au saute au traitement d'un carac norm
                jmp fin_kr ; on ne passe pas a la ligne suivante auto
s_nl:  ; traitement du NEW_LINE
                cmp byte ptr [pos_lig],22
                je fin_kr       ; si on est sur la derniere ligne -> RIEN
                inc word ptr [pos_txt]   ; on avance ds le buffer
                inc byte ptr [pos_lig]  ; on avance d'une ligne
                mov byte ptr [pos_col],0; on se place au debut de la ligne
                call init_var_lig       ; on initialise les var pour la nvl ligne

                jmp fin_kr
s_non_nl:
                inc byte ptr [pos_col]
                inc word ptr [pos_txt]
                call maj_pos_ecr
fin_kr:
                jmp fin_dispatch_key
s5:
        cmp byte ptr[mode],MODE_INSERE
        jne s6
                call dispatch_mode_insertion
                jmp fin_dispatch_key
s6:
        cmp byte ptr [mode],MODE_ECRASE
        jne s7
                call dispatch_mode_ecrase
                jmp fin_dispatch_key
s7:
        cmp byte ptr [mode],MODE_COMMANDE
        jne s8
                call dispatch_mode_commande
                jmp fin_dispatch_key
s8:
fin_dispatch_key:
        jmp debut_dispatch_key
dispatch_key ENDP

;*************************************************** PROGRAMME PRINCIPAL
debut_prog:
        mov ax,cs
        mov ds,ax
        mov es,ax
        mov ss,ax       ; segment de pile = segment courant
        mov sp,finpile  ; on place le ptr de pile a la fin de la zone
                        ; pile
bprogprinc:
        mode_ecran MODE80x25
        affiche pres_dta
        attendre_CR
        mode_ecran MODE80x25
finprog:
        mode_ecran MODE80x25
        call init_vi
        call aff_info
        gotoxy [pos_lig],[pos_col]
        call dispatch_key       ; on entre dans une procedure sans fin
        mov ax,4C00h    ; return code = 0       ; inutile ici ! ( cf ci dessus )
        int 21h
code ENDS
END begin
