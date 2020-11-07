// 15 KHz RGB Pattern Generator
// Designed for Arduino Nano/Uno
// (c) Olivier Le Cam <olecam@glou.fr>

#define PIN_DIRECTION 0b11111100  // PD2 (DDD2) to PD7 (DDD7) as output 

// @16MHz: 1 CPU cycle = 0.0625us
// nop instructions are added in order to adust timings

void setup() {
  // set pinMode
  asm volatile (
    "out %0, %1                   \n"
     :
     : "I" (_SFR_IO_ADDR(DDRD)), "r" (PIN_DIRECTION)
     :
   );
}

void loop() {
  asm volatile (
    ".set BLACK,0b00000000                    \n"
    ".set RED,  0b00000100                    \n"
    ".set GREEN,0b00001000                    \n"
    ".set BLUE, 0b00010000                    \n"
    ".set CYAN,GREEN+BLUE                     \n"
    ".set MAGENTA,RED+BLUE                    \n"
    ".set YELLOW,RED+GREEN                    \n"
    ".set WHITE,RED+GREEN+BLUE                \n"
    ".set HSYNC_BIT,5                         \n"
    ".set VSYNC_BIT,6                         \n"
    ".set CSYNC_BIT,7                         \n"    
    ".set HSYNC_OFF,0b00100000                \n"
    ".set VSYNC_OFF,0b01000000                \n"
    ".set CSYNC_OFF,0b10000000                \n"
    ".set HSYNC_ON,0b00000000                 \n"
    ".set VSYNC_ON,0b00000000                 \n"
    ".set CSYNC_ON,0b00000000                 \n"
    ".set SYNC_PINS_MASK,0b00011111           \n"
    
    
    // set hsync pin to on
    ".MACRO set_hsync_on                      \n"   // 2C
    "cbi %[port], HSYNC_BIT                   \n" 
    ".ENDM                                    \n"

    // set hsync pin to off
    ".MACRO set_hsync_off                     \n"   // 2C
    "sbi %[port], HSYNC_BIT                   \n"
    ".ENDM                                    \n"

    // set vsync pin to on
    ".MACRO set_vsync_on                      \n"   // 2C
    "cbi %[port], VSYNC_BIT                   \n"
    ".ENDM                                    \n"

    // set vsync pin to off
    ".MACRO set_vsync_off                     \n"   // 2C
    "sbi %[port], VSYNC_BIT                   \n"
    ".ENDM                                    \n"

    // set csync pin to on
    ".MACRO set_csync_on                      \n"   // 2C
    "cbi %[port], CSYNC_BIT                   \n"
    ".ENDM                                    \n"

    // set csync pin to off
    ".MACRO set_csync_off                     \n"   // 2C
    "sbi %[port], CSYNC_BIT                   \n"
    ".ENDM                                    \n"

    // set sync pins
    ".MACRO set_sync pins                     \n"   // total: 4C
    "in r17, %[port]                          \n"   // 1C
    "andi r17, SYNC_PINS_MASK                 \n"   // 1C
    "ori r17, &pins                           \n"   // 1C   
    "out %[port], r17                         \n"   // 1C
    ".ENDM                                    \n"
    
    // delay n * 0,25us
    ".MACRO delay count                       \n" // total: 4 * count
    "ldi r17, &count                          \n" // 1C
  "1:                                         \n" 
    "nop                                      \n" // 1C
    "dec r17                                  \n" // 1C
    "brne 1b                                  \n" // 2C when branching, 1C otherwise
    ".ENDM                                    \n"

    // send an hsync pulse
    ".MACRO h_sync                            \n"   // 80C, 5us (pulse duration is 76C, 4.75ux)
    "set_sync VSYNC_OFF+HSYNC_ON+CSYNC_ON     \n"   // 4C
    "delay 18                                 \n"   // 72C
    "set_sync VSYNC_OFF+HSYNC_OFF+CSYNC_OFF   \n"   // 4C
    ".ENDM                                    \n"

    // send an horizontal back porch
    ".MACRO h_back_porch                      \n"   // 99C, 6.19us
    "set_color BLACK                          \n"   // 5C
    "delay 23                                 \n"   // 92C
    "nop                                      \n"   // 1C
    "nop                                      \n"   // 1C
    ".ENDM                                    \n"

    // send an horizontal front porch
    ".MACRO h_front_porch                     \n"   // 49C, 3.06us
    "set_color BLACK                          \n"   // 5C
    "delay 11                                 \n"   // 44C
    ".ENDM                                    \n"

    // set the RGB pins
    ".MACRO set_color color                   \n"   // total: 4C
    "in r17, %[port]                          \n"   // 1C
    "andi r17, 0b11100011                     \n"   // 1C
    "ori r17, &color                          \n"   // 1C
    "out %[port], r17                         \n"   // 1C
    ".ENDM                                    \n"

    // show part of line
    ".MACRO h_line color duration             \n" // 4 * count + 5C 
    "set_color &color                         \n" // 4C
    "delay &duration                          \n" // 4 * count
    ".ENDM                                    \n"

    // Generate a Vertical Frame Pulse
    ".MACRO v_sync                            \n"
    // S  et frame sync (vsync) and keep it on during 3 blank lines
    //
    // this is the trickiest part of code because csync must be triggered
    // ahead of hsync: the csync falling edges horizontal pulses are to be 
    // be lined up with the hsync pulses. 
    // for details, see:
    // https://www.hdretrovision.com/blog/2019/10/10/engineering-csync-part-2-falling-short
    //
    "set_color BLACK                          \n"   // 5C
    "ldi r18, 3                               \n"   // 1C
   "v_sync:                                   \n"
    "set_sync VSYNC_ON | HSYNC_ON | CSYNC_ON  \n"   // 4C
    "delay 18                                 \n"   // 72C
    "nop                                      \n"   // 1C
    "nop                                      \n"   // 1C total: 74C, 4.625us
    "set_hsync_off                            \n"   // 2C
    "h_back_porch                             \n"   // 99C
    "delay 191                                \n"   // 764C, 47.75us
    "set_csync_off                            \n"   // 2C
    "delay 17                                 \n"   // 68C
    "nop                                      \n"   // 1C total: 69C, 4.3125us
    "dec r18                                  \n"   // 1C
    "brne v_sync                              \n"   // 2C when branching, 1C otherwise
    "nop                                      \n"   // 1C
    "h_sync                                   \n"   // 78C
    "h_back_porch                             \n"   // 99C
    "h_line BLACK,196                         \n"   // 788C
    "h_front_porch                            \n"   // 49C
    "set_csync_off                            \n"   // 2C
    ".ENDM                                    \n"

    ".MACRO v_back_porch                      \n"
    // Vertical Back Porch: 23 blank lines
    "ldi r18, 23                              \n"   // 1C
  "v_bp:                                      \n"
    "h_sync                                   \n"   // 80C 
    "h_back_porch                             \n"   // 99C
    "h_line BLACK,196                         \n"   // 788C
    "h_front_porch                            \n"   // 49C
    "dec r18                                  \n"   // 1C
    "brne v_bp                                \n"   // 2C when branching, 1C otherwise  total: 1019, 63.68us
    ".ENDM                                    \n"

    ".MACRO v_front_porch                     \n"
    // Vertical Front Porch: 13 blank lines
    "ldi r18, 13                              \n"   // 1C
  "v_fp:                                      \n"  
    "h_sync                                   \n"   // 80C
    "h_back_porch                             \n"   // 99C
    "h_line BLACK,196                         \n"   // 788C
    "h_front_porch                            \n"   // 49C     
    "dec r18                                  \n"   // 1C
    "brne v_fp                                \n"   // 2C when branching, 1C otherwise  total: 1019, 63.68us
    "rjmp loop                                \n"   // 2C
    ".ENDM                                    \n"
    
    // Initialize outputs
    "cli \n"
    "set_sync VSYNC_OFF+HSYNC_OFF+CSYNC_OFF   \n"
    "set_color BLACK                          \n"
    
   "loop:                                     \n"

    "v_sync                                   \n"
    "v_back_porch                             \n"  

    // Active video: 224 lines, 8 bars
    "ldi r18, 224                             \n"   // 1C
  "v_disp2:                                   \n"
    "h_sync                                   \n"   // 78C
    "h_back_porch                             \n"   // 99C
    "h_line WHITE,23                          \n"   // 96C
    "h_line YELLOW,23                         \n"   // 96C
    "h_line CYAN,23                           \n"   // 96C
    "h_line GREEN,24                          \n"   // 100C
    "h_line MAGENTA,24                        \n"   // 100C
    "h_line RED,24                            \n"   // 100C 
    "h_line BLUE,24                           \n"   // 100C
    "h_line BLACK,23                          \n"   // 96C  
    "nop                                      \n"   // 1C
    "nop                                      \n"   // 1C
    "nop                                      \n"   // 1C     total: 787 (49.1875us)
    "h_front_porch                            \n"   // 49C
    "dec r18                                  \n"   // 1C
    "breq v_disp_done2                        \n"   // 2C when branching, 1C otherwise
    "rjmp v_disp2                             \n"   // 2C
  "v_disp_done2:"

    "v_front_porch                            \n"
  
    :
    : [port] "I" (_SFR_IO_ADDR(PORTD))
    : "r17", "r18"
  );
}
