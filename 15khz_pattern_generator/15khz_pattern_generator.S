; 15 KHz RGB Pattern Generator
; (c) Olivier Le Cam <olc@glou.fr>

#define DDRD            0x0A
#define PORTD           0x0B
#define PORTD2          2
#define PORTD3          3
#define PORTD4          4
#define PORTD5          5
#define PORTD6          6
#define PORTD7          7
#define PIN_DIRECTION   0b11111100          // DDD2 to DDD7 as output

#define DDR_VIDEO       DDRD                // Video (RGB + SYNC) on port D
#define PORT_VIDEO      PORTD

#define BLACK           0x00
#define RED             (1<<PORTD2)
#define GREEN           (1<<PORTD3)
#define BLUE            (1<<PORTD4)
#define CYAN            GREEN | BLUE
#define MAGENTA         RED|BLUE
#define YELLOW          RED|GREEN
#define WHITE           RED|GREEN|BLUE
#define RGB_PINS_MASK   ~(RED|GREEN|BLUE)

#define HSYNC_BIT       PORTD5
#define VSYNC_BIT       PORTD6
#define CSYNC_BIT       PORTD7
#define HSYNC_OFF       (1<<HSYNC_BIT)
#define VSYNC_OFF       (1<<VSYNC_BIT)
#define CSYNC_OFF       (1<<CSYNC_BIT)
#define HSYNC_ON        0x00                // just for clarity of code (it's on by default)
#define VSYNC_ON        0x00                // just for clarity of code (it's on by default)
#define CSYNC_ON        0x00                // just for clarity of code (it's on by default)
#define SYNC_PINS_MASK  ~(HSYNC_OFF|VSYNC_OFF|CSYNC_OFF)

#define REG_TMP         r17
#define REG_LC          r18

  .global main

  ; Set hsync pin to on
  .MACRO set_hsync_on       ; 2C
  cbi PORT_VIDEI, HSYNC_BIT
  .ENDM

  ; Set hsync pin to off
  .MACRO set_hsync_off      ; 2C
  sbi PORT_VIDEO, HSYNC_BIT
  .ENDM

  ; Set vsync pin to on
  .MACRO set_vsync_on       ; 2C
  cbi PORT_VIDEO, VSYNC_BIT
  .ENDM

  ; Set vsync pin to off
  .MACRO set_vsync_off      ; 2C
  sbi PORT_VIDEO, VSYNC_BIT
  .ENDM

  ; Set csync pin to on
  .MACRO set_csync_on       ; 2C
  cbi PORT_VIDEO, CSYNC_BIT
  .ENDM

  ; Set csync pin to off
  .MACRO set_csync_off      ; 2C
  sbi PORT_VIDEO, CSYNC_BIT
  .ENDM

  ; Set sync pins
  .MACRO set_sync pins                    ; total: 4C
  in REG_TMP, PORT_VIDEO                  ; 1C
  andi REG_TMP, SYNC_PINS_MASK            ; 1C
  ori REG_TMP, &pins                      ; 1C   
  out PORT_VIDEO, REG_TMP                 ; 1C
  .ENDM

  ; Delay n * 0,25us
  .MACRO delay count                      ; total: 4 * count
  ldi REG_TMP, &count                     ; 1C
1: 
  nop                                     ; 1C
  dec REG_TMP                             ; 1C
  brne 1b                                 ; 2C when branching, 1C otherwise
  .ENDM

  ; Send an hsync pulse
  .MACRO h_sync                           ; 80C, 5us (pulse duration is 76C, 4.75ux)
  set_sync VSYNC_OFF|HSYNC_ON|CSYNC_ON    ; 4C
  delay 18                                ; 72C
  set_sync VSYNC_OFF|HSYNC_OFF|CSYNC_OFF  ; 4C
  .ENDM

  ; Horizontal back porch
  .MACRO h_back_porch                     ; 99C, 6.19us
  set_color BLACK                         ; 5C
  delay 23                                ; 92C
  nop                                     ; 1C
  nop                                     ; 1C
  .ENDM

  ; Send an horizontal front porch
  .MACRO h_front_porch                    ; 49C, 3.06us
  set_color BLACK                         ; 5C
  delay 11                                ; 44C
  .ENDM

  ; Set the RGB pins
  .MACRO set_color color                  ; total: 4C
  in REG_TMP, PORT_VIDEO                  ; 1C
  andi REG_TMP, RGB_PINS_MASK             ; 1C
  ori REG_TMP, &color                     ; 1C
  out PORT_VIDEO, REG_TMP                 ; 1C
  .ENDM

  ; Show part of line
  .MACRO h_line color duration            ; 4 * count + 5C 
  set_color &color                        ; 4C
  delay &duration                         ; 4 * count
  .ENDM

  ; Generate a Vertical Frame Pulse
  ; Set a frame sync (vsync) and keep it on during 3 blank lines
  ;
  ; This part of code is a bit tricky because csync must be triggered
  ; ahead of hsync: the csync falling edges horizontal pulses are to be
  ; be lined up with the hsync pulses.
  ; for details, see:
  ; https://www.hdretrovision.com/blog/2019/10/10/engineering-csync-part-2-falling-short
  .MACRO v_sync
  set_color BLACK                         ; 5C
  ldi REG_LC, 3                           ; 1C
v_sync:
  set_sync VSYNC_ON | HSYNC_ON | CSYNC_ON ; 4C
  delay 18                                ; 72C
  nop                                     ; 1C
  nop                                     ; 1C total: 74C, 4.625us
  set_hsync_off                           ; 2C
  h_back_porch                            ; 99C
  delay 191                               ; 764C, 47.75us
  set_csync_off                           ; 2C
  delay 17                                ; 68C
  nop                                     ; 1C total: 69C, 4.3125us
  dec REG_LC                              ; 1C
  brne v_sync                             ; 2C when branching, 1C otherwise
  nop                                     ; 1C
  h_sync                                  ; 78C
  h_back_porch                            ; 99C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 49C
  set_csync_off                           ; 2C
  .ENDM

  ; Vertical Back Porch: 23 blank lines
  .MACRO v_back_porch
  ldi REG_LC, 23                          ; 1C
v_bp:
  h_sync                                  ; 80C 
  h_back_porch                            ; 99C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 49C
  dec REG_LC                              ; 1C
  brne v_bp                               ; 2C when branching, 1C otherwise  total: 1019, 63.68us
  .ENDM

  ; Vertical Front Porch: 13 blank lines
  .MACRO v_front_porch
  ldi REG_LC, 13                          ; 1C
v_fp:
  h_sync                                  ; 80C
  h_back_porch                            ; 99C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 49C     
  dec REG_LC                              ; 1C
  brne v_fp                               ; 2C when branching, 1C otherwise  total: 1019, 63.68us
  rjmp loop                               ; 2C
  .ENDM
  
main:
  ; PinMode(PORTD, PIN_DIRECTION)
  ldi REG_TMP, PIN_DIRECTION
  out DDR_VIDEO, REG_TMP

  ; Initialize outputs
  cli
  set_sync VSYNC_OFF|HSYNC_OFF|CSYNC_OFF
  set_color BLACK
  
loop:
  v_sync
  v_back_porch

  ; Active video: 224 lines, 8 bars
  ldi REG_LC, 224                         ; 1C
v_disp:
  h_sync                                  ; 78C
  h_back_porch                            ; 99C
  h_line WHITE,23                         ; 96C
  h_line YELLOW,23                        ; 96C
  h_line CYAN,23                          ; 96C
  h_line GREEN,24                         ; 100C
  h_line MAGENTA,24                       ; 100C
  h_line RED,24                           ; 100C 
  h_line BLUE,24                          ; 100C
  h_line WHITE,23                         ; 96C  
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C     total: 787 (49.1875us)
  h_front_porch                           ; 49C
  dec REG_LC                              ; 1C
  breq v_disp_done                        ; 2C when branching, 1C otherwise
  rjmp v_disp                             ; 2C
v_disp_done:

  v_front_porch

  rjmp loop
