;-----------------------------------------------------------------------------------------------------------
; Proyecto: Led Cambia Color con ADC
; Autor: Inventable
; Fecha: 01/06/2011
; Micro: PIC12F629
; Clock: oscilador interno 4MHz
;-----------------------------------------------------------------------------------------------------------
	ERRORLEVEL -302	   	
	LIST 	P = 12F629, r=DEC, n=66
    INCLUDE         "P12F629.INC"

;-----------------------------------------------------------------------------------------------------------
; Pin del circuito
; ===============================
;-----------------------------------------------------------------------------------------------------------

#define		p_rojo	GPIO,0				; pin del canal rojo 
#define		p_verde	GPIO,1				; pin del canal verde 
#define		p_azul	GPIO,2				; pin del canal azul
#define 	p_adc	GPIO,5				; pinde del ADC

#define 	IOMap_normal	B'011000'	; mapa de los pin del micro: los tres primeros como salidas
#define 	IOMap_adc		B'111000'	; mapa de los pin del micro: los tres primeros como salidas

;-----------------------------------------------------------------------------------------------------------
; Otras constantes
; ===============================
;-----------------------------------------------------------------------------------------------------------
#define		tiempo_rojo	 30				; tiempos distintos de los canales
#define		tiempo_verde 37				; para obtener todas 
#define		tiempo_azul  45				; las combinaciones posibles

;-----------------------------------------------------------------------------------------------------------
; Registros en RAM
; ================
;-----------------------------------------------------------------------------------------------------------

	cblock     20H     ; Dummy Origin

		intensidad_verde				; registro intensidad canal verde		 
		intensidad_rojo				 	; registro intensidad canal rojo		 
		intensidad_azul					; registro intensidad canal azul		 

		divisor_verde					; divisor canal verde
		divisor_rojo					; divisor canal rojo
		divisor_azul					; divisor canal azul

		divisor_general					; divisor general

		CountAdcL						; Contador ADC Low
		CountAdcH						; Contador ADC High

		RegPwm							; registro PWM para regular la intensidad de los tres canales
			 
		RegFlags						; registro de uso general
	endc

#define	aumenta_verde	RegFlags,0		; flag que indica si el canal verde está aumentando su intensidad 
#define	aumenta_rojo	RegFlags,1		; flag que indica si el canal rojo está aumentando su intensidad
#define	aumenta_azul	RegFlags,2		; flag que indica si el canal azul está aumentando su intensidad

;-----------------------------------------------------------------------------------------------------------
; MACRO cambio pagina de la RAM
; ================================
;-----------------------------------------------------------------------------------------------------------

PAG_RAM0	MACRO
			bcf	STATUS,RP0
			ENDM

PAG_RAM1	MACRO
			bsf	STATUS,RP0
			ENDM

;-----------------------------------------------------------------------------------------------------------
;					Vector de arranque del micro
;-----------------------------------------------------------------------------------------------------------

    		ORG     0
			PAG_RAM1
			call 	3FFh 			; Ajusta el oscilador a 4MHz
			movwf 	OSCCAL 			; usando el valor que se encuentra en 3FFh
			PAG_RAM0
			goto	main

;-----------------------------------------------------------------------------------------------------------
;					SUBRUTINAS
;-----------------------------------------------------------------------------------------------------------

			ORG	10h					; beginning of program Eprom

;-----------------------------------------------------------------------------------------------------------
;					Aumenta o disminuye la intensidad del canal verde
;-----------------------------------------------------------------------------------------------------------

OnOffVerde
			decfsz	divisor_verde,f		; divisor para disminuir la velocidad de cambio		
			retlw	0					; Vuelve al ciclo principal

			movlw	tiempo_verde		; el divisor se actualiza 
			movwf	divisor_verde		; con la constante tiempo_verde

			btfss	aumenta_verde		; canal en fase di aumento de la intensidad?
			goto	DisminuyeVerde		; No, entonces salta a disminuye			
			incfsz	intensidad_verde,f	; Si, entonces aumenta la intensidad
			retlw	0					; Vuelve al ciclo principal
			bcf		aumenta_verde		; La intensidad llegó al máximo, entonces
			decf	intensidad_verde,f	; cambia al modo de disminución
			retlw	0					; Vuelve al ciclo principal

DisminuyeVerde	
			movf	intensidad_verde,f	; Modo de disminución
			btfsc	STATUS,Z			; Controla si no llegó al mínimo
			goto	DisminuyeVerdeCambia; Si si, salta para cambiar el modo
			decf	intensidad_verde,f	; Disminuye la intensidad
			retlw	0					; Vuelve al ciclo principal
DisminuyeVerdeCambia
			bsf		aumenta_verde		; Cambia al modo de aumento
			retlw	0					; Vuelve al ciclo principal


;-----------------------------------------------------------------------------------------------------------
;					Aumenta o disminuye la intensidad del canal rojo
;-----------------------------------------------------------------------------------------------------------

OnOffRojo
			decfsz	divisor_rojo,f		; La descripción de esta sub es igual
			retlw	0					; a la del canal verde (OnOffVerde)

			movlw	tiempo_rojo
			movwf	divisor_rojo

			btfss	aumenta_rojo
			goto	DisminuyeRojo					
			incfsz	intensidad_rojo,f
			retlw	0
			bcf		aumenta_rojo
			decf	intensidad_rojo,f
			retlw	0

DisminuyeRojo	
			movf	intensidad_rojo,f
			btfsc	STATUS,Z
			goto	DisminuyeRojoCambia
			decf	intensidad_rojo,f
			retlw	0
DisminuyeRojoCambia
			bsf		aumenta_rojo
			retlw	0

;-----------------------------------------------------------------------------------------------------------
;					Aumenta o disminuye la intensidad del canal azul
;-----------------------------------------------------------------------------------------------------------

OnOffAzul
			decfsz	divisor_azul,f		; La descripción de esta sub es igual		
			retlw	0					; a la del canal verde (OnOffVerde)

			movlw	tiempo_azul
			movwf	divisor_azul

			btfss	aumenta_azul
			goto	DisminuyeAzul					
			incfsz	intensidad_azul,f
			retlw	0
			bcf		aumenta_azul
			decf	intensidad_azul,f
			retlw	0

DisminuyeAzul	
			movf	intensidad_azul,f
			btfsc	STATUS,Z
			goto	DisminuyeAzulCambia
			decf	intensidad_azul,f
			retlw	0
DisminuyeAzulCambia
			bsf		aumenta_azul
			retlw	0

;-----------------------------------------------------------------------------------------------------------
;					Actualiza intensidad de los 3 canales (rojo, verde y azul)
;					en base a los registros de intensidad
;-----------------------------------------------------------------------------------------------------------
PwmRefresh
			incf	RegPwm,f				; actualiza la intensidad
			movf	intensidad_verde,W		; del canal verde
			subwf	RegPwm,W
			btfss	STATUS,C
			bsf		p_verde
			btfsc	STATUS,C
			bcf		p_verde	

			movf	intensidad_rojo,W		; actualiza la intensidad
			subwf	RegPwm,W				; del canal rojo
			btfss	STATUS,C
			bsf		p_rojo
			btfsc	STATUS,C
			bcf		p_rojo	

			movf	intensidad_azul,W		; actualiza la intensidad
			subwf	RegPwm,W				; del canal azul
			btfss	STATUS,C
			bsf		p_azul
			btfsc	STATUS,C
			bcf		p_azul	
			retlw	0		

;-------------------------------------------------------------------------------------------- 
; lectura trimmer (ADC)
; =====================
;-------------------------------------------------------------------------------------------- 		
ADC		
		clrf	CountAdcL			; Reset contadores ADC
		clrf	CountAdcH
		PAG_RAM1
		movlw   IOMap_adc    		; Pone el pin ADC como entrada para leer el trimmer 
 		movwf	TRISIO 
		PAG_RAM0      	
cicloADC
		clrwdt
		call	PwmRefresh	
		btfss	p_adc
		goto	finADC
		incfsz 	CountAdcL,f
		goto	cicloADC
		incf 	CountAdcH,f
		goto	cicloADC
finADC
		PAG_RAM1
		movlw   IOMap_normal		; Pone el pin ADC como salida para permitir
 		movwf	TRISIO 				; que el capacitor se descargue
		PAG_RAM0
		bsf		p_adc
		retlw	0

;-----------------------------------------------------------------------------------------------------------
;					MAIN
;-----------------------------------------------------------------------------------------------------------
main    	
			PAG_RAM1
			movlw   IOMap_normal    		
			movwf	TRISIO				; Set de los puertos como entradas o salidas 

			movlw	B'11100011'			; RB pull-up on. Prscaler %128 in Watch-Dog (max.time)
			movwf	OPTION_REG			; 
		
			PAG_RAM0

			movlw	B'00000111'			; Set de los puertos como entradas/salidas digitales
			movwf	CMCON

			bcf	INTCON,GIE				; Ningun interrupt global activado
			bcf	INTCON,PEIE				; Ningun interrupt periférico activado

			movlw	tiempo_verde		; Carga todos los registros
			movwf	divisor_verde		; con los datos necesarios
			movlw	tiempo_rojo			; para el correcto funcionamiento
			movwf	divisor_rojo		; del circuito
			movlw	tiempo_azul
			movwf	divisor_azul
			clrf	RegFlags
			clrf	divisor_general
			clrf	intensidad_azul
			clrf	intensidad_verde
			clrf	intensidad_rojo
			bsf		p_adc
			
;-----------------------------------------------------------------------------------------------------------
;				CICLO DE TRABAJO PRINCIPAL
;-----------------------------------------------------------------------------------------------------------
Ciclo
			clrwdt						; Watchdog para evitar que el micro se pueda bloquear
			call	ADC
			movf	CountAdcL,W
			movwf	divisor_general
CicloVerde
			call	PwmRefresh			; Actualiza los canales (PWM) 
			decfsz 	divisor_general,f	; Ciclo para disminuir la velocidad
			goto	CicloVerde			; de la actualizaz
			call	OnOffVerde
			movf	CountAdcL,W
			movwf	divisor_general	
			clrwdt
CicloRojo
			call	PwmRefresh
			decfsz 	divisor_general,f
			goto	CicloRojo
			call	OnOffRojo
			movf	CountAdcL,W
			movwf	divisor_general
			clrwdt
CicloAzul
			call	PwmRefresh
			decfsz 	divisor_general,f
			goto	CicloAzul
			call	OnOffAzul
			goto	Ciclo

;***********************************************************************************************
; Service Interrupt: no se usa
;***********************************************************************************************
service_int
		retfie
;***********************************************************************************************
		END
