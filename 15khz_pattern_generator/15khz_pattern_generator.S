; 15 KHz RGB Pattern Generator
; (c) Olivier Le Cam <olc@glou.fr>

#define PINB_ADDR       0x03
#define DDRB_ADDR       0x04
#define PORTB_ADDR      0x05
#define DDRD_ADDR       0x0A
#define PORTD_ADDR      0x0B
#define BIT0            0                   // DDB0, DDC0, DDD0
#define BIT1            1                   // DDB1, DDC1, DDD1
#define BIT2            2                   // etc.
#define BIT3            3
#define BIT4            4
#define BIT5            5
#define BIT6            6
#define BIT7            7

#define PATTERN_SWITCH  BIT0
#define INPUTS_PIN      PINB_ADDR
#define INPUTS_DDR      DDRB_ADDR
#define INPUTS_PORT     PORTB_ADDR

#define PINDIR_VIDEO    0b11111100          // DDD2 to DDD7 as output
#define VIDEO_DDR       DDRD_ADDR           // Video (RGB + SYNC) on port D
#define VIDEO_PORT      PORTD_ADDR

#define BLACK           0x00
#define RED             (1<<BIT2)
#define GREEN           (1<<BIT3)
#define BLUE            (1<<BIT4)
#define CYAN            GREEN | BLUE
#define MAGENTA         RED|BLUE
#define YELLOW          RED|GREEN
#define WHITE           RED|GREEN|BLUE
#define RGB_PINS_MASK   ~(RED|GREEN|BLUE)

#define HSYNC_BIT       BIT5
#define VSYNC_BIT       BIT6
#define CSYNC_BIT       BIT7
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
  .MACRO set_hsync_on                     ; 2C
  cbi PORT_VIDEI, HSYNC_BIT
  .ENDM

  ; Set hsync pin to off
  .MACRO set_hsync_off                    ; 2C
  sbi VIDEO_PORT, HSYNC_BIT
  .ENDM

  ; Set vsync pin to on
  .MACRO set_vsync_on                     ; 2C
  cbi VIDEO_PORT, VSYNC_BIT
  .ENDM

  ; Set vsync pin to off
  .MACRO set_vsync_off                    ; 2C
  sbi VIDEO_PORT, VSYNC_BIT
  .ENDM

  ; Set csync pin to on
  .MACRO set_csync_on                     ; 2C
  cbi VIDEO_PORT, CSYNC_BIT
  .ENDM

  ; Set csync pin to off
  .MACRO set_csync_off                    ; 2C
  sbi VIDEO_PORT, CSYNC_BIT
  .ENDM

  ; Set sync pins
  .MACRO set_sync pins:req                ; total: 4C
  in REG_TMP, VIDEO_PORT                  ; 1C
  andi REG_TMP, SYNC_PINS_MASK            ; 1C
  ori REG_TMP, \pins                      ; 1C
  out VIDEO_PORT, REG_TMP                 ; 1C
  .ENDM

  ; Delay n * 0,25us
  .MACRO delay count:req                  ; total: 4 * count
  ldi REG_TMP, \count                     ; 1C
1:
  nop                                     ; 1C
  dec REG_TMP                             ; 1C
  brne 1b                                 ; 2C when branching, 1C otherwise
  .ENDM

  ; Send an hsync pulse
  .MACRO h_sync                           ; 80C, 5us (pulse duration is 76C, 4.75us)
  set_sync VSYNC_OFF|HSYNC_ON|CSYNC_ON    ; 4C
  delay 18                                ; 72C
  set_sync VSYNC_OFF|HSYNC_OFF|CSYNC_OFF  ; 4C
  .ENDM

  ; Horizontal back porch
  .MACRO h_back_porch                     ; 98C, 6.125us
  set_color BLACK                         ; 4C
  delay 23                                ; 92C
  nop                                     ; 1C
  nop                                     ; 1C
  .ENDM

  ; Send an horizontal front porch
  .MACRO h_front_porch                    ; 48C, 3.0us
  set_color BLACK                         ; 4C
  delay 11                                ; 44C
  .ENDM

  ; Set the RGB pins
  .MACRO set_color color:req              ; total: 4C
  in REG_TMP, VIDEO_PORT                  ; 1C
  andi REG_TMP, RGB_PINS_MASK             ; 1C
  ori REG_TMP, \color                     ; 1C
  out VIDEO_PORT, REG_TMP                 ; 1C
  .ENDM

  ; Show part of line
  .MACRO h_line color:req,duration:req    ; 4 * count + 4C
  set_color \color                        ; 4C
  delay \duration                         ; 4 * count
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
  set_color BLACK                         ; 4C
  ldi REG_LC, 3                           ; 1C
2:
  set_sync VSYNC_ON | HSYNC_ON | CSYNC_ON ; 4C
  delay 18                                ; 72C
  nop                                     ; 1C
  nop                                     ; 1C total: 74C, 4.625us
  set_hsync_off                           ; 2C
  h_back_porch                            ; 98C
  delay 191                               ; 764C, 47.75us
  set_csync_off                           ; 2C
  delay 17                                ; 68C
  nop                                     ; 1C total: 69C, 4.3125us
  dec REG_LC                              ; 1C
  brne 2b                                 ; 2C when branching, 1C otherwise
  nop                                     ; 1C
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  set_csync_off                           ; 2C
  .ENDM

  ; Vertical Back Porch: 23 blank lines
  .MACRO v_back_porch count=23
  ldi REG_LC, \count                      ; 1C
v_bp:
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  brne v_bp                               ; 2C when branching, 1C otherwise  total: 1019, 63.68us
  .ENDM

  ; Vertical Front Porch: 13 blank lines
  .MACRO v_front_porch
  ldi REG_LC, 13                          ; 1C
3:
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  brne 3b                                 ; 2C when branching, 1C otherwise  total: 1019, 63.68us
  .ENDM  

  ; Draw a 36-lines block in order to form the grid
  ; between each horizontal white lines
  .MACRO grid_rows_block
  ldi REG_LC,36                           ; 1C
4:
  grid_row                                ; 788C + sync + porchs
  dec REG_LC                              ; 1C
  breq 5f                                 ; 2C when branching, otherwise 1C
  rjmp 4b                                 ; 2C
5:
  .ENDM

  ; Draw a white line for the grid pattern
  ; nop are added in order to sync timings with grid_row
  .MACRO grid_line_white
  nop                                     ; 1C
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line WHITE,196                        ; 788C
  h_front_porch                           ; 48C
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C
  .ENDM

  ; Draw an intermediate row line for the grid pattern 
  .MACRO grid_row
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  set_color WHITE                         ; 4C  total line: 788C
  h_line BLACK,30                         ; 124C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  h_line BLACK,30                         ; 124C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  h_line BLACK,30                         ; 124C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C
  h_line BLACK,30                         ; 124C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  h_line BLACK,30                         ; 124C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  h_line BLACK,30                         ; 124C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  h_front_porch                           ; 48C
  .ENDM

  ; Draw v line for the cross pattern 
  .MACRO cross_v_line
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,96                         ; 388C, total: 788C
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C
  set_color WHITE                         ; 4C
  nop                                     ; 1C
  nop                                     ; 1C
  h_line BLACK,96                         ; 388C
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C
  h_front_porch                           ; 48C
  .ENDM

  ; Draw a 110-lines block in order to form the first
  ; and second part of screen (before and after the
  ; horizontal line)
  .MACRO cross_v_line_block
  ldi REG_LC,110                          ; 1C
6:
  cross_v_line                            ; 788C + sync + porchs
  dec REG_LC                              ; 1C
  breq 7f                                 ; 2C when branching, otherwise 1C
  rjmp 6b                                 ; 2C
7:
  .ENDM

  ; Draw an horizontal line for the cross pattern
  ; code is actually the same as `grid_line_white`
#define cross_h_line grid_line_white

  ; Draw an "dots" line for the dots pattern 
  .MACRO dots_line
  nop
  h_sync                                  ; 80C
  h_back_porch                            ; 98C  
  delay 3                                 ; 12C, total line: 788C 
  nop                                     ; 1C
  nop                                     ; 1C    14  
  set_color WHITE                         ; 4C
  h_line BLACK,29                         ; 120C
  nop                                     ; 1C
  nop                                     ; 1C    126
  set_color WHITE                         ; 4C
  h_line BLACK,29                         ; 120C
  nop                                     ; 1C
  nop                                     ; 1C    126
  set_color WHITE                         ; 4C
  h_line BLACK,29                         ; 120C
  nop                                     ; 1C
  nop                                     ; 1C    126
  set_color WHITE                         ; 4C
  h_line BLACK,29                         ; 120C
  nop                                     ; 1C
  nop                                     ; 1C    126
  set_color WHITE                         ; 4C
  h_line BLACK,29                         ; 120C
  nop                                     ; 1C
  nop                                     ; 1C    126
  set_color WHITE                         ; 4C
  h_line BLACK,29                         ; 120C
  nop                                     ; 1C
  nop                                     ; 1C    126
  set_color WHITE                         ; 4C    
  set_color BLACK                         ; 4C    8
  delay 2                                 ; 12C   14
  nop                                     ; 1C
  nop                                     ; 1C
  h_front_porch                           ; 48C
  nop
  nop
  nop
  .ENDM

  ; Draw a block a black lines for the dots pattern
  .MACRO dots_black_block count:req
  ldi REG_LC,\count                       ; 1C
8:
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  breq 9f                                 ; 2C when branching, otherwise 1C
  rjmp 8b                                 ; 2C
9:
  .ENDM


; Debounce function: avoid bouncing when the pattern switch button
; is pressed
debounce:
  delay 255                               ; 1020C (63us) (maybe a bit shot: could be increased)
  sbic INPUTS_PIN, PATTERN_SWITCH         ; 1C if switch is released, 2C otherwise
  ret                                     ; 1C
  rjmp debounce                           ; 2C


; Main function
main:
  ; Set PATTERN_SWITCH pin as a PULLUP input
  cbi INPUTS_DDR, PATTERN_SWITCH
  sbi INPUTS_PORT, PATTERN_SWITCH
  
  ; PinMode(VIDEO_DDR, PINDIR_VIDEO)
  ldi REG_TMP, PINDIR_VIDEO
  out VIDEO_DDR, REG_TMP

  ; Initialize outputs
  cli
  set_sync VSYNC_OFF|HSYNC_OFF|CSYNC_OFF  ; 4C
  set_color BLACK                         ; 4C

loop:
  rcall pattern_bars
  rcall pattern_cross
  rcall pattern_grid
  rcall pattern_dots
  rjmp loop


; Draw an 8 colored bars patter
pattern_bars:
  v_sync
  v_back_porch
  
  ; Active video: 224 lines, 8 bars
  ldi REG_LC, 224                         ; 1C
pattern_bar_lines_loop:
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line WHITE,23                         ; 96C
  h_line YELLOW,23                        ; 96C
  h_line CYAN,23                          ; 96C
  h_line GREEN,24                         ; 100C
  h_line MAGENTA,24                       ; 100C
  h_line RED,24                           ; 100C
  h_line BLUE,24                          ; 100C
  h_line BLACK,23                         ; 96C
  nop                                     ; 1C
  nop                                     ; 1C
  nop                                     ; 1C     total: 787 (49.1875us)
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  breq pattern_bar_lines_done             ; 2C when branching, 1C otherwise
  rjmp pattern_bar_lines_loop             ; 2C
pattern_bar_lines_done:

  v_front_porch

  ; Read Pattern Switch Button State
  sbic INPUTS_PIN, PATTERN_SWITCH
  rjmp pattern_bars
  call debounce
  ret


; Draw a grid pattern
pattern_grid:
  v_sync

  ; Generate a Vertical Back Porch paying attention to have
  ; the exact same timing than visible lines
  ; (aka, 1 cycle before a line and 3 cycles after)
  ldi REG_LC, 23                          ; 1C
pattern_grid_back_porch_loop:
  nop
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  brne pattern_grid_back_porch_loop       ; 2C when branching, 1C otherwise
  nop                                     ; 1C
 
  grid_line_white
  grid_rows_block
  grid_line_white
  grid_rows_block
  grid_line_white
  grid_rows_block
  grid_line_white
  grid_line_white
  grid_rows_block
  grid_line_white
  grid_rows_block
  grid_line_white
  grid_rows_block
  grid_line_white

  v_front_porch

  ; Read Pattern Switch Button State
  sbic INPUTS_PIN, PATTERN_SWITCH
  rjmp pattern_grid
  call debounce
  ret

 ; Draw a grid pattern
pattern_cross:
  v_sync

  ; Generate a Vertical Back Porch paying attention to have
  ; the exact same timing than visible lines
  ; (aka, 1 cycle before a line and 3 cycles after)
  ldi REG_LC, 23                          ; 1C
pattern_cross_back_porch_loop:
  nop
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  brne pattern_cross_back_porch_loop      ; 2C when branching, 1C otherwise
  nop                                     ; 1C

  cross_v_line_block
  cross_h_line
  cross_h_line
  cross_v_line_block

  v_front_porch

  ; Read Pattern Switch Button State
  sbic INPUTS_PIN, PATTERN_SWITCH
  rjmp pattern_cross
  call debounce
  ret

   ; Draw a dots pattern
pattern_dots:
  v_sync

  ; Generate a Vertical Back Porch paying attention to have
  ; the exact same timing than visible lines
  ; (aka, 1 cycle before a line and 3 cycles after)
  ldi REG_LC, 23                          ; 1C
pattern_dots_back_porch_loop:
  nop
  h_sync                                  ; 80C
  h_back_porch                            ; 98C
  h_line BLACK,196                        ; 788C
  h_front_porch                           ; 48C
  dec REG_LC                              ; 1C
  brne pattern_dots_back_porch_loop       ; 2C when branching, 1C otherwise
  nop                                     ; 1C

  dots_black_block 6
  dots_line
  dots_line
  dots_black_block 33
  dots_line
  dots_line
  dots_black_block 33
  dots_line
  dots_line
  dots_black_block 33
  dots_line
  dots_line
  dots_black_block 33
  dots_line
  dots_line
  dots_black_block 33
  dots_line
  dots_line
  dots_black_block 33
  dots_line
  dots_line
  dots_black_block 6

  v_front_porch

  ; Read Pattern Switch Button State
  sbic INPUTS_PIN, PATTERN_SWITCH
  jmp pattern_dots
  call debounce
  ret
