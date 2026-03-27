#ifndef BUTTONS_H
#define BUTTONS_H

// Process pending button actions (called from main loop)
// PB0: Leave network and rejoin
// PB1: Send On/Off toggle to Light
void buttonsInit(void);
void buttonsTick(void);

#endif
