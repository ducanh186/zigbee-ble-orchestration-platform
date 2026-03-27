#include "app/app_config.h"
#include "app/net_mgr.h"
#include "app/buttons.h"
#include "app/framework/include/af.h"

void emberAfMainInitCallback(void)
{
  netMgrInit();
  buttonsInit();
  emberAfCorePrintln("Z3Light init, netState=%d", emberAfNetworkState());
}

void emberAfMainTickCallback(void)
{
  buttonsTick();
}

#ifndef EZSP_HOST
void emberAfRadioNeedsCalibratingCallback(void)
{
  sl_mac_calibrate_current_channel();
}
#endif
