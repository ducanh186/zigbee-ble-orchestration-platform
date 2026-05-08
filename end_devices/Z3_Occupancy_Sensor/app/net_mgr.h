#ifndef NET_MGR_H
#define NET_MGR_H

#include "app/framework/include/af.h"

void netMgrInit(void);
void netMgrRequestLeaveAndRejoin(void);
void netMgrOnStackStatus(EmberStatus status);

#endif
