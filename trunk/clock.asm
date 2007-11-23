.include "atmega8.inc"

; Record the number of clock overflows since last rising and falling flanks.
; Each overflow corresponds to 16.4 milli seconds.
.equ high_time	= 0x0000
.equ low_time	= 0x0001

; Flank constants.
.equ	NO_FLANK		= 0
.equ	RISING_FLANK	= 1
.equ	FALLING_FLANK	= 2

.cseg
.org 0x0000
	rjmp	main

.org 0x0009
	; Counter overflow.
	rjmp	counter_overflow

.include "decode_dcf77.asm"
.include "dcf77_comm.asm"

; Main program
main:
	ldi		r16,	low(RAMEND)
	out		SPL,	r16
	ldi		r16,	high(RAMEND)
	out		SPH,	r16

	; Set port D to be all inputs.
	ldi		r16,	0x00
	out		DDRD,	r16

	; Set port B to be all outputs.
	ldi		r16,	0xff
	out		DDRB,	r16

	; Set timer register for timer to use internal clock with 64 prescaler. One
	; tick corresponds to 64 micro seconds (one overflow happens every 16.4
	; milliseconds).
	ldi		r16,	0x03
	out		TCCR0,	r16

	; Set interrupt 0 to sense both rising and falling edges.
;	ldi		r16,	0x81
;	out		MCUCR,	r16

	; Enable interrupt 0
;	ldi		r16,	0x40
;	out		GICR,	r16

	; Reset clock.
	clr		r16
	out		TCNT0,	r16

	; Turn on counter interrupts.
	ldi		r16,	0x01
	out		TIMSK,	r16

	clr		r16
	sts		high_time,	r16
	sts		low_time,	r16

	; Globally enable interrupts.
	sei

	; Set the sample state to 0.
	clr		r20

	clr		r18
	; Loop forever, waiting for interrupts.

main_loop:
	; Sleep in Idle Mode.
;	rcall	pause_for_awhile
;	out		PORTB,	r16
;	com		r16
;	ldi		r16,	0x81
;	out		MCUCR,	r16
;	sleep
	nop
	rjmp	main_loop
