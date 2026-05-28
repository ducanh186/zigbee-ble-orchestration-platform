#include <string.h>

#include "app/app_config.h"
#include "app/net_mgr.h"
#include "app/buttons.h"
#include "app/display_qr.h"
#include "app/provisioning_qr.h"
#include "app/framework/include/af.h"

void emberAfMainInitCallback(void)
{
  netMgrInit();
  buttonsInit();

  if (display_qr_init("LIGHT KIT")) {
    char payload[224];
    if (provisioning_qr_build_payload(payload, sizeof(payload)) > 0) {
      display_qr_render_provisioning(payload);
    }
    // Never log raw payload — contains install_code per contract §7.
    memset(payload, 0, sizeof(payload));
  }

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
