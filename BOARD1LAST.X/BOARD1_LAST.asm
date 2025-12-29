; ==============================================================================
; PROJE: PIC16F877A FINAL SYSTEM (W Register Korumal? Tablo)
; ==============================================================================
LIST P=PIC16F877A
INCLUDE "p16f877a.inc"
 __CONFIG _PWRTE_ON & _HS_OSC & _WDT_OFF & _BOREN_ON & _LVP_OFF & _CPD_OFF &_CP_ON &_WRT_OFF &_DEBUG_OFF 

CBLOCK 0x20
    TF, TI, T_L, T_H, ADC_F, D_TF, D_TI, FAN_RPS
    SEC_CNT, W_TEMP, STATUS_TEMP, FLAGS, RX_DATA, TX_DATA
    SHOW_MODE, TWO_SEC_CNT, DISP_DELAY_VAR
    DISP_VAL, HUND, TENS, ONES, HARF_TEMP
    TABLE_INDEX ; <--- YEN?: Tablo için say?y? saklayacak de?i?ken
ENDC
      
ORG 0X00      
GOTO SETTINGS 

ORG 0X04      
ISR:
    MOVWF   W_TEMP          
    SWAPF   STATUS, W       
    MOVWF   STATUS_TEMP     

    BANKSEL PIR1
    BTFSS   PIR1, RCIF      
    GOTO    CHECK_TIMER0    
    BANKSEL RCREG
    MOVF    RCREG, W        
    MOVWF   RX_DATA         
    BSF     FLAGS, 1        
    
CHECK_TIMER0:    
    BANKSEL INTCON
    BTFSS   INTCON, T0IF
    GOTO    ISR_EXIT        
    BSF     ADC_F, 0        
    INCF    SEC_CNT, F      
    MOVLW   d'244'          
    SUBWF   SEC_CNT, W
    BTFSS   STATUS, Z       
    GOTO    CHECK_2SEC      
    CLRF    SEC_CNT         
    BSF     FLAGS, 0        
CHECK_2SEC:
    MOVF    SEC_CNT, W
    SUBLW   d'0'
    BTFSS   STATUS, Z
    GOTO    TMR0_DONE
    INCF    TWO_SEC_CNT, F
    MOVLW   d'2'
    SUBWF   TWO_SEC_CNT, W
    BTFSS   STATUS, Z       
    GOTO    TMR0_DONE       
    CLRF    TWO_SEC_CNT
    INCF    SHOW_MODE, F    
    MOVLW   d'3'
    SUBWF   SHOW_MODE, W    
    BTFSC   STATUS, Z
    CLRF    SHOW_MODE       

TMR0_DONE:
    BCF     INTCON, T0IF    
ISR_EXIT:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS          
    SWAPF   W_TEMP, F       
    SWAPF   W_TEMP, W       
    RETFIE 

; ------------------------------------------------------------------
; MAIN LOGIC
; ------------------------------------------------------------------
GET_ADC: 
    BANKSEL ADCON0
    BSF     ADCON0, GO  
    CALL    WAIT_ADC
    MOVF    ADRESH, W   
    MOVWF   T_H
    BANKSEL ADRESL
    MOVF    ADRESL,W 
    BANKSEL T_L
    MOVWF   T_L
    
    MOVLW   d'20'           
    SUBWF   T_L, W          
    BTFSS   STATUS, C        
    GOTO    GET_ADC         
    BCF     STATUS, C 
    MOVLW   d'206'          
    SUBWF   T_L, W          
    BTFSC   STATUS, C        
    GOTO    GET_ADC         
    BCF     STATUS, C 
    RRF     T_L, W        
    MOVWF   TI              
    MOVLW   d'0'
    BTFSC   STATUS, C       
    MOVLW   d'5'            
    MOVWF   TF
    BCF STATUS,C
    CALL COMPARE 
    CLRF    ADC_F
    RETURN 
    
WAIT_ADC: 
    BTFSC   ADCON0, GO    
    GOTO    WAIT_ADC 
    RETURN
    
COMPARE:
    MOVF    D_TI, W    
    SUBWF   TI, W    
    BTFSS   STATUS, C    
    GOTO    SMALLER      
    GOTO    GREATER
GREATER: 
    BANKSEL PORTE
    BCF     PORTE, 1 
    BSF     PORTE, 2 
    BTFSS   FLAGS, 0     
    RETURN               
    BCF     FLAGS, 0        
    BANKSEL T1CON
    BCF     T1CON, TMR1ON   
    MOVF    TMR1L, W        
    MOVWF   FAN_RPS
    BCF     STATUS, C       
    RRF     FAN_RPS, F      
    CLRF    TMR1L
    CLRF    TMR1H
    BSF     T1CON, TMR1ON   
    RETURN
SMALLER: 
    BANKSEL PORTE
    BCF     PORTE, 2 
    BSF     PORTE, 1 
    RETURN

PROCESS_UART:
    BCF     FLAGS, 1        
    MOVF    RX_DATA, W      
    BTFSC   RX_DATA, 7      
    GOTO    CHECK_SET_CMD   
    MOVLW   0x01
    SUBWF   RX_DATA, W
    BTFSC   STATUS, Z
    GOTO    SEND_D_TF
    MOVLW   0x02
    SUBWF   RX_DATA, W
    BTFSC   STATUS, Z
    GOTO    SEND_D_TI
    MOVLW   0x03
    SUBWF   RX_DATA, W
    BTFSC   STATUS, Z
    GOTO    SEND_TF
    MOVLW   0x04
    SUBWF   RX_DATA, W
    BTFSC   STATUS, Z
    GOTO    SEND_TI
    MOVLW   0x05
    SUBWF   RX_DATA, W
    BTFSC   STATUS, Z
    GOTO    SEND_FAN
    RETURN 
CHECK_SET_CMD:
    BTFSC   RX_DATA, 6
    GOTO    SET_D_TI        
    GOTO    SET_D_TF        
SET_D_TF:
    MOVF    RX_DATA, W
    ANDLW   b'00111111'     
    MOVWF   D_TF            
    RETURN
SET_D_TI:
    MOVF    RX_DATA, W
    ANDLW   b'00111111'     
    MOVWF   D_TI            
    RETURN
SEND_D_TF:
    MOVF    D_TF, W
    CALL    UART_SEND
    RETURN
SEND_D_TI:
    MOVF    D_TI, W
    CALL    UART_SEND
    RETURN
SEND_TF:
    MOVF    TF, W
    CALL    UART_SEND
    RETURN
SEND_TI:
    MOVF    TI, W
    CALL    UART_SEND
    RETURN
SEND_FAN:
    MOVF    FAN_RPS, W
    CALL    UART_SEND
    RETURN
UART_SEND:
    MOVWF   TX_DATA         
    BANKSEL TXSTA
WAIT_TX:
    BTFSS   TXSTA, TRMT     
    GOTO    WAIT_TX         
    BANKSEL TXREG
    MOVF    TX_DATA, W
    MOVWF   TXREG           
    BANKSEL PORTD           
    RETURN

SETTINGS:
    BANKSEL OPTION_REG
    MOVLW   b'00000100'
    MOVWF   OPTION_REG
    BANKSEL INTCON
    MOVLW   b'11100000'   
    MOVWF   INTCON        
    BANKSEL PIE1
    BSF     PIE1, RCIE 
    BANKSEL SPBRG
    MOVLW   d'51'           
    MOVWF   SPBRG
    BANKSEL TXSTA
    MOVLW   b'00100100'     
    MOVWF   TXSTA
    BANKSEL RCSTA
    MOVLW   b'10010000'     
    MOVWF   RCSTA
    BANKSEL TRISC
    MOVLW   b'10000001'      
    MOVWF   TRISC
    BANKSEL TRISD
    CLRF    TRISD           
    BANKSEL PORTB
    CLRF    PORTB
    BANKSEL TRISA
    MOVLW b'00001111'
    MOVWF TRISA 
    BANKSEL TRISE
    MOVLW b'00000111'
    MOVWF TRISE
    BANKSEL ADCON1 
    MOVLW b'11001101' 
    MOVWF ADCON1 
    BANKSEL ADCON0    
    MOVLW b'01000001' 
    MOVWF ADCON0
    BANKSEL D_TF
    MOVLW .5
    MOVWF D_TF
    MOVLW .45
    MOVWF D_TI
    BANKSEL TRISE
    CLRF TRISE
    BANKSEL PORTE 
    CLRF PORTE
    BANKSEL PORTD
    CLRF PORTD        
    BANKSEL TRISC
    BSF     TRISC, 0
    BANKSEL T1CON
    MOVLW   b'00000111'     
    MOVWF   T1CON
    CLRF    SEC_CNT         
    CLRF    FAN_RPS
    CLRF    FLAGS            
    CLRF    RX_DATA
    CLRF    TX_DATA
    CLRF    SHOW_MODE
    CLRF    TWO_SEC_CNT

LOOP:
    BTFSC   ADC_F,0
    CALL    GET_ADC
    BTFSC   FLAGS, 1
    CALL    PROCESS_UART
    CALL    REFRESH_DISPLAY_MANUAL
    GOTO    LOOP

REFRESH_DISPLAY_MANUAL:
    BANKSEL PORTD  
    MOVF    SHOW_MODE, W
    SUBLW   d'0'
    BTFSC   STATUS, Z
    GOTO    PREP_D_VAL      
    MOVF    SHOW_MODE, W
    SUBLW   d'1'
    BTFSC   STATUS, Z
    GOTO    PREP_A_VAL      
    GOTO    PREP_F_VAL      

PREP_D_VAL:
    MOVF    D_TI, W         
    MOVWF   DISP_VAL        
    MOVLW   0x5E            
    MOVWF   HARF_TEMP
    GOTO    START_DISPLAY_SEQ
PREP_A_VAL:
    MOVF    TI, W           
    MOVWF   DISP_VAL        
    MOVLW   0x77            
    MOVWF   HARF_TEMP
    GOTO    START_DISPLAY_SEQ
PREP_F_VAL:
    MOVF    FAN_RPS, W      
    MOVWF   DISP_VAL        
    MOVLW   0x71            
    MOVWF   HARF_TEMP

START_DISPLAY_SEQ:
    BANKSEL PORTD   
    CLRF    HUND
    CLRF    TENS
    CLRF    ONES
    MOVF    DISP_VAL, W
    MOVWF   ONES            
CALC_HUND:                  
    MOVLW   d'100'
    SUBWF   ONES, W
    BTFSS   STATUS, C       
    GOTO    CALC_TENS       
    MOVWF   ONES            
    INCF    HUND, F
    GOTO    CALC_HUND
CALC_TENS:                  
    MOVLW   d'10'
    SUBWF   ONES, W
    BTFSS   STATUS, C
    GOTO    SHOW_NOW
    MOVWF   ONES
    INCF    TENS, F
    GOTO    CALC_TENS

SHOW_NOW:
    ; 1. BASAMAK: HARF
    MOVF    HARF_TEMP, W
    BANKSEL PORTD
    MOVWF   PORTD
    BANKSEL PORTC
    BSF     PORTC, 1        
    CALL    DISP_DELAY_SHORT
    BCF     PORTC, 1        

    ; 2. BASAMAK: YÜZLER
    BANKSEL PORTD           
    MOVF    HUND, W
    CALL    GET_SEG_CODE    
    MOVWF   PORTD
    BANKSEL PORTC
    BSF     PORTC, 2        
    CALL    DISP_DELAY_SHORT
    BCF     PORTC, 2

    ; 3. BASAMAK: ONLAR
    BANKSEL PORTD           
    MOVF    TENS, W
    CALL    GET_SEG_CODE    
    MOVWF   PORTD
    BANKSEL PORTC
    BSF     PORTC, 3        
    CALL    DISP_DELAY_SHORT
    BCF     PORTC, 3

    ; 4. BASAMAK: B?RLER
    BANKSEL PORTD           
    MOVF    ONES, W
    CALL    GET_SEG_CODE    
    MOVWF   PORTD
    BANKSEL PORTC
    BSF     PORTC, 4        
    CALL    DISP_DELAY_SHORT
    BCF     PORTC, 4
    RETURN

DISP_DELAY_SHORT:
    MOVLW   d'50'           
    MOVWF   DISP_DELAY_VAR
DELAY_LOOP:
    DECFSZ  DISP_DELAY_VAR, F
    GOTO    DELAY_LOOP
    RETURN

ORG     0x500       ; Güvenli bir adres (Sayfa ba??)
    
GET_SEG_CODE:
    ; 1. W içindeki say?y? (örn: 5) hemen sakla!
    MOVWF   TABLE_INDEX
    
    ; 2. PCLATH'? ayarla (Tablo 0x500'de oldu?u için High Byte 0x05)
    MOVLW   HIGH TABLE_START
    MOVWF   PCLATH
    
    ; 3. Say?y? geri ça??r
    MOVF    TABLE_INDEX, W
    
    ; 4. Z?pla
    ADDWF   PCL, F

TABLE_START:
    RETLW   0x3F ; 0
    RETLW   0x06 ; 1
    RETLW   0x5B ; 2
    RETLW   0x4F ; 3
    RETLW   0x66 ; 4
    RETLW   0x6D ; 5
    RETLW   0x7D ; 6
    RETLW   0x07 ; 7
    RETLW   0x7F ; 8
    RETLW   0x6F ; 9
    RETLW   0x00 ; Hata
    RETLW   0x00
    RETLW   0x00

END