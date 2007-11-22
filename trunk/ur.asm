.equ PINB  = 0x16
.equ DDRB  = 0x17
.equ PORTB = 0x18

.equ PINC  = 0x13
.equ DDRC  = 0x14
.equ PORTC = 0x15

.equ PIND  = 0x10
.equ DDRD  = 0x11
.equ PORTD = 0x12

.equ PIND0 = 0
.equ PIND1 = 1
.equ PIND2 = 2
.equ PIND3 = 3
.equ PIND4 = 4
.equ PIND5 = 5
.equ PIND6 = 6
.equ PIND7 = 7

.equ SPH   = 0x3e
.equ SPL   = 0x3d

.equ SPCR  = 0x0d
.equ SPR0  = 0
.equ SPR1  = 1
.equ CPHA  = 2
.equ CPOL  = 3
.equ MSTR  = 4
.equ DORD  = 5
.equ SPE   = 6
.equ SPIE  = 7

.equ TCNT0 = 0x32
.equ TCCR0 = 0x33
.equ SREG  = 0x3f
.equ MCUCR = 0x35
.equ GICR  = 0x3b
.equ TIMSK = 0x39

.equ RAMEND = 0x0400


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

counter_overflow:
	push	r16
	in		r16,		SREG
	push	r16

	;ldi		r18,	1

	; Get the current bit from the DCF77 circuit.
	in		r16,		PIND
	andi	r16,		0x01

	rcall	process_sample

	cpi		r16,		NO_FLANK
	; Exit without touching the timers.
	breq	exit_counter_overflow

	; Is this a rising flank?
	cpi		r16,		RISING_FLANK
	breq	handle_rising_flank

	rcall	handle_falling_flank
	rjmp	exit_counter_overflow

handle_rising_flank:
	; See if this is synch.
	lds		r16,		low_time
	cpi		r16,		85
	brlo	no_synch

	; Synch found.
	ldi		r16,		0xff
	out		PORTB,		r16

no_synch:
	clr		r16
	sts		low_time,	r16
	ldi		r16,		1
	sts		high_time,	r16

exit_counter_overflow:
	; Cleanup.

;	sbrc	r20,		0
;	rcall	clear_low_time

	pop		r16
	out		SREG,		r16
	pop		r16
	reti



; Function that resets low time and figures out if we got a logical one or zero
; from the DCF77-receiver.
;
;	Parameters:
;		-
;	Return:
;		-
handle_falling_flank:
	push	r16

	; See how long the signal was high. More than 100 ms, set data out to 1,
	; otherwise, set to 0.
	lds		r16,		high_time

	; Output the number of ticks the pulse has been high.
;	out		PORTB,		r16
;	rjmp	exit_handle_falling_flank

	cpi		r16,		9
	brsh	handle_falling_flank_output_one

handle_falling_flank_output_zero:
	ldi		r16,		2
	out		PORTB,		r16
	rjmp	exit_handle_falling_flank

handle_falling_flank_output_one:
	ldi		r16,		1
	out		PORTB,		r16
	rjmp	exit_handle_falling_flank


exit_handle_falling_flank:
	clr		r16
	sts		high_time,	r16
	ldi		r16,		1
	sts		low_time,	r16

	pop		r16
	ret


clear_low_time:
	push	r16

	clr		r16
	sts		low_time,	r16

	pop		r16
	ret

; Function that adds a sample to the sample register and checks if this is a
; rising or falling flank. Returns NO_FLANK, RISING_FLANK or FALLING_FLANK in
; r16.
;
;	Parameters:
;		r16	-	The sample bit in LSB.
;	Returns:
;		r16	-	Which flank it was, either NO_FLANK, RISING_FLANK or
;				FALLING_FLANK.
;
process_sample:
	push	r18

	push	r16
	rcall	get_mean_state

	; Save state prior to sample, shifted left one step, in r18.
	mov		r18,	r16
	lsl		r18

	; Retrieve the new sample to add into r16 again.
	pop		r16

	rcall	add_sample
	rcall	get_mean_state

	; After oring together the previous state, shifted one step left, with the
	; new state, we will get 10 for falling flank, 01 for rising and 00 or 11 for
	; no change. These correspond to the flank constants we declared above.
	or		r16,	r18

	cpi		r16,	NO_FLANK
	breq	low_low
	cpi		r16,	RISING_FLANK
	breq	low_high
	cpi		r16,	FALLING_FLANK
	breq	high_low
	rjmp	high_high

high_high:
	; If r16 contains 11 binary, it indicates no flank. Set to NO_FLANK.
	ldi		r16,		NO_FLANK
	lds		r18,		high_time
	inc		r18
	sts		high_time,	r18
	clr		r18
	sts		low_time,	r18
	rjmp	exit_process_sample

low_high:
	ldi		r16,		RISING_FLANK
	rjmp	exit_process_sample

low_low:
	ldi		r16,		NO_FLANK
	lds		r18,		low_time
	inc		r18
	sts		low_time,	r18
	clr		r18
	sts		high_time,	r18
	rjmp	exit_process_sample

high_low:
	ldi		r16,		FALLING_FLANK

exit_process_sample:
	pop		r18
	ret



; Pause for a little while.
pause_for_awhile:
	push	r24
	push	r25

	clr		r24
	clr		r25
wait_loop:
	adiw	r24,	1
	brcc	wait_loop

	pop		r25
	pop		r24
	ret


; Returns the mean state of the last 8 samples in r16.
get_mean_state:
	push	r17
	push	r19
	push	r20

;	mov		r16,	r20
;	andi	r16,	0x01
;	rjmp	exit_get_mean_state

	; r17 will count ones.
	clr		r17
get_mean_state_count_loop:
	sbrc	r20,	0
	inc		r17

	; Move down the next bit.
	lsr		r20
	; Bail out if r20 i 0, then there are no more ones to count.
	brne	get_mean_state_count_loop

	clr		r16
	; If r17 < 5, keep r16 as 0 and exit.
	cpi		r17,	4
	brlo	exit_get_mean_state

	; If r17 >= 5, set r16 = 1 and exit.
	ldi		r16,	1

exit_get_mean_state:

	pop		r20
	pop		r19
	pop		r17
	ret


; Shifts in the lowest bit in r16 into the sample set.
add_sample:
	; Save the parameter register.
	push	r16

	; Shift in the lowest bit from the parameter into the lowest position of r20.
	lsl		r20
	andi	r16,	0x01
	or		r20,	r16

	; restore the parameter register.
	pop		r16
	ret


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
