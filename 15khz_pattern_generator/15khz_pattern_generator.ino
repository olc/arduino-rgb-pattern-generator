// 15 KHz RGB Pattern Generator
// Designed for Arduino Nano/Uno
// (c) Olivier Le Cam <olecam@glou.fr>
//
// Project is pure assembly, this is why this ino file is empty.
//
// Outputs:
//    PD2: Red
//    PD3: Green
//    PD4: Blue
//    PD5: V.SYNC (vertical synchronization signal)
//    PD6: H.SYNC (horizontal synchronization signal)
//    PD7: C.SYNC (combines both V.SYNC and H.SYNC)
//
// Arduino outputs can be be wired directly to the Monitor or via a buffer
// (LS125, LS367, ...) in order to protect your Arduino.
// C.SYNC combines both vertical and horizontal sync signals on a sigle wire.
// Most of the time, like with Hantarex Monitors, you can just wire C.SYNC. 
