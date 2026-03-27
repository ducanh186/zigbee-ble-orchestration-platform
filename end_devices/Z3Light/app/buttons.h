#ifndef BUTTONS_H
#define BUTTONS_H

// Process pending button actions (called from main loop)
// PB0: Leave network and rejoin
// PB1: Start find-and-bind target (make Light discoverable for Switch binding)
void buttonsInit(void);
void buttonsTick(void);

#endif
