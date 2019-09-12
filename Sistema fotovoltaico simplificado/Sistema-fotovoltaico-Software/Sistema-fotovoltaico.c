//---------------------------------------------------------------------------------------------------------------
// Sistema fotovoltaico (in C) 
// ===============================
// Project: Sistema-fotovoltaico.c
// author: Gabriel Inventable
// date:  03/07/2013
// picmicro: PIC12F675
// clock: internal RC
// This works is licensed under Creative Commons BY-NC-SA
// --------------------------------------------------------------------------------------------------------------
// DEFINE
// --------------------------------------------------------------------------------------------------------------

#define FOSC 4000000L

//---------------------------------------------------------------------------------------------------------------
// I/O pins map
//---------------------------------------------------------------------------------------------------------------

#define	p_trim_vmax		GP0					// IN ANA 0 
#define	P_trim_vmin		GP4					// IN ANA (ANA 3)
#define	p_vbat			GP1					// IN ANA 1
#define	p_ctrl_power	GP2					// OUT (ANA 2)
#define	p_ctrl_solar	GP5					// OUT
#define	p_push_button	GP3					// IN DIG 

#define TrisMap			0b00011011			// In/Out pins mode (TRIS MAP)
#define AnaInMap		0b00001011			// An0 = ON, An1 = ON, An2 = OFF, An3 = ON 

//---------------------------------------------------------------------------------------------------------------
// Analogic channel
//---------------------------------------------------------------------------------------------------------------

#define	ch_trim_vmax	0					// trimmer max analogic channel  
#define ch_trim_vmin	3					// trimmer min analogic channel
#define ch_vbat			1					// V battery analogic channel

//---------------------------------------------------------------------------------------------------------------
// State system
//---------------------------------------------------------------------------------------------------------------

#define	BAT_NORMAL		0					// Normal battery operation
#define	BAT_EMPTY		1					// Empty charge battery 
#define	BAT_FULL		2					// Full charge battery
#define	BAT_TEST		3					// not used

// --------------------------------------------------------------------------------------------------------------
// INCLUDE
// --------------------------------------------------------------------------------------------------------------

#include <pic.h>
#include "delay.c"

// --------------------------------------------------------------------------------------------------------------
// FUSE CONFIG
// --------------------------------------------------------------------------------------------------------------

__CONFIG(FOSC_INTRCIO & 					// INTERNAL OSC RC 4MHz
 		WDTE_OFF &							// watchdog disabled
		PWRTE_ON &							// power timer enabled
		MCLRE_OFF &							// Master clear off
		BOREN_ON &							// Brown-out Reset Enable bit ON
		CP_ON &								// Code Protection ON 
		CPD_OFF);							// Code Protection Data OFF


// --------------------------------------------------------------------------------------------------------------
// Variabili 
// --------------------------------------------------------------------------------------------------------------

	unsigned char 	status_sys = 0;			// System status (state machine)
	unsigned int 	vmax_trim = 0;			// V max trimmer var  
	unsigned int	vmin_trim = 0;			// V min trimmer var
	unsigned int	vbat = 0;				// V bat var
	unsigned int 	v_offset_full;			// V offset full
	unsigned int 	v_offset_empty;			// V offset empty

// --------------------------------------------------------------------------------------------------------------
// Settings 
// --------------------------------------------------------------------------------------------------------------
void settings(void)
{
	TRISIO = TrisMap;						// Setting In/Out pins
	CMCON = 7; 								// Comparator Module OFF
	ANSEL = AnaInMap;						// Set analogic input



	// Pic setting 	
	// ---------------------------------------------
	ADCON0 = 0b10000001;					// Programming ADC Module
											// bit 0 -> ADC ON / OFF
											// bit 1 -> GO/DONE	(1=start 0=finish)
											// bit 2 -> CHS0 AN input A0
											// bit 3 -> CHS1 AN input A1
											// bit 4 -> NC
											// bit 5 -> NC
											// bit 6 -> AVCFG: Voltage Reference bit 1 = VREF pin 0 = VDD
											// bit 7 -> ADFM A/D Result Format Select bit (1:right 0:left)
	OPTION_REG = 0b11010001;
											// bits 2,1,0 -> Prescaler Rate Select bit 
											// bit 3 -> Prescaler assegnato al Timer0 
											// bit 4 -> TMR0 Source edge mode (not used)
											// bit 5 -> TMR0 Clock Source Select bit (0:internal 1:RA4/T0CKI)
											// bit 6 -> Interrupt edge mode (not used)
											// bit 7 -> Pull-up Enable bit (0: enabled)
	DelayMs(100); 

	PEIE = 0; 								// periferic interrupt disable
	GIE = 0; 								// global interrupt disable
}

// --------------------------------------------------------------------------------------------------------------
// Read ADC function
// --------------------------------------------------------------------------------------------------------------
unsigned int read_adc(unsigned char channel)
{
	unsigned int 	adc_temp_value 	= 0;
		
	ADCON0 &= 0xf3;      					// Clear Channel selection bits

	switch(channel)
	{
		case 0:	ADCON0 |= 0x00; break;  	// Select GP0 pin as ADC input
		case 1:	ADCON0 |= 0x04; break;  	// Select GP1 pin as ADC input
		case 2:	ADCON0 |= 0x08; break;  	// Select GP2 pin as ADC input
		case 3:	ADCON0 |= 0x0c; break;  	// Select GP4 pin as ADC input

		default:	return 0; 				//Return error, wrong channel selected
	}

	DelayMs(10); 

	for(char samples_count = 0; samples_count < 10; samples_count++)
	{
		GO = 1;								// initiate conversion on the selected channel
		while(GO)continue;
		adc_temp_value = adc_temp_value + ADRESL + (ADRESH<<8);
		DelayMs(5);
	}
		
	return adc_temp_value / 10;				// return the result
}


// --------------------------------------------------------------------------------------------------------------
// Switch mode
// --------------------------------------------------------------------------------------------------------------
void status_switch(unsigned int mode)
{
	status_sys = mode;

	switch(mode)	
		{
		case BAT_FULL:	p_ctrl_solar = 0; p_ctrl_power = 0; break;
		case BAT_EMPTY:	p_ctrl_solar = 1; p_ctrl_power = 1;	break;
		case BAT_NORMAL:p_ctrl_solar = 1; p_ctrl_power = 0; break;
		}

}

// --------------------------------------------------------------------------------------------------------------
// Main 
// --------------------------------------------------------------------------------------------------------------
void main(void)
{
	settings();
	status_sys = BAT_NORMAL;		
	while(1)
		{
		if (p_push_button == 1) 
			{
				v_offset_full = 40;
				v_offset_empty = 40;
			}
		else 
			{
				v_offset_full = 0;
				v_offset_empty = 0;
			}

		vmin_trim = read_adc(ch_trim_vmin);				// Read Vmin trimmer
		vmax_trim = read_adc(ch_trim_vmax);				// Read Vmax trimmer
		vbat = read_adc(ch_vbat);

		switch (status_sys)
			{
				case BAT_NORMAL:
					{
						if (vbat > vmax_trim) status_switch(BAT_FULL);
						if (vbat < vmin_trim) status_switch(BAT_EMPTY);
						break;
					}   
				case BAT_FULL:
					{
						if ((vbat + v_offset_full) < vmax_trim) status_switch(BAT_NORMAL);	break;
					}

				case BAT_EMPTY:
					{
						if (vbat > (vmin_trim + v_offset_empty)) status_switch(BAT_NORMAL);	break;
					}

			} 	// end switch
							
		} 		// end while
} 				// end function
