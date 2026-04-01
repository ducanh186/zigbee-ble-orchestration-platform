####################################################################
# Automatically-generated file. Do not edit!                       #
# Makefile Version 21                                              #
####################################################################

BASE_SDK_PATH = /home/phu/SimplicityStudio/SDKs/gecko_sdk
BASE_PKG_PATH = /home/phu/.silabs/slt/installs
UNAME:=$(shell $(POSIX_TOOL_PATH)uname -s | $(POSIX_TOOL_PATH)sed -e 's/^\(CYGWIN\).*/\1/' | $(POSIX_TOOL_PATH)sed -e 's/^\(MINGW\).*/\1/')
ifeq ($(UNAME),MINGW)
# Translate "C:/super" into "/C/super" for MinGW make.
SDK_PATH := /$(shell $(POSIX_TOOL_PATH)echo $(BASE_SDK_PATH) | sed s/://)
PKG_PATH := /$(shell $(POSIX_TOOL_PATH)echo $(BASE_PKG_PATH) | sed s/://)
endif
SDK_PATH ?= $(BASE_SDK_PATH)
PKG_PATH ?= $(BASE_PKG_PATH)
COPIED_SDK_PATH ?= gecko_sdk_4.5.0

# This uses the explicit build rules below
PROJECT_SOURCE_FILES =

C_SOURCE_FILES   += $(filter %.c, $(PROJECT_SOURCE_FILES))
CXX_SOURCE_FILES += $(filter %.cpp, $(PROJECT_SOURCE_FILES))
CXX_SOURCE_FILES += $(filter %.cc, $(PROJECT_SOURCE_FILES))
ASM_SOURCE_FILES += $(filter %.s, $(PROJECT_SOURCE_FILES))
ASM_SOURCE_FILES += $(filter %.S, $(PROJECT_SOURCE_FILES))
LIB_FILES        += $(filter %.a, $(PROJECT_SOURCE_FILES))

C_DEFS += \
 '-DEMBER_CUSTOM_MAC_FILTER_TABLE_SIZE=15' \
 '-DEFR32MG12P332F1024GL125=1' \
 '-DSL_APP_PROPERTIES=1' \
 '-DSL_BOARD_NAME="BRD4162A"' \
 '-DSL_BOARD_REV="A03"' \
 '-DHARDWARE_BOARD_DEFAULT_RF_BAND_2400=1' \
 '-DHARDWARE_BOARD_SUPPORTS_1_RF_BAND=1' \
 '-DHARDWARE_BOARD_SUPPORTS_RF_BAND_2400=1' \
 '-DHFXO_FREQ=38400000' \
 '-DSL_COMPONENT_CATALOG_PRESENT=1' \
 '-DSEGGER_RTT_ALIGNMENT=1024' \
 '-DCORTEXM3=1' \
 '-DCORTEXM3_EFM32_MICRO=1' \
 '-DCORTEXM3_EFR32=1' \
 '-DPHY_RAIL=1' \
 '-DPLATFORM_HEADER="platform-header.h"' \
 '-DSL_LEGACY_HAL_ENABLE_WATCHDOG=1' \
 '-DMBEDTLS_CONFIG_FILE=<sl_mbedtls_config.h>' \
 '-DMBEDTLS_PSA_CRYPTO_CLIENT=1' \
 '-DMBEDTLS_PSA_CRYPTO_CONFIG_FILE=<psa_crypto_config.h>' \
 '-DSL_RAIL_LIB_MULTIPROTOCOL_SUPPORT=0' \
 '-DSL_RAIL_UTIL_PA_CONFIG_HEADER=<sl_rail_util_pa_config.h>' \
 '-DRTT_USE_ASM=0' \
 '-DSEGGER_RTT_SECTION="SEGGER_RTT"' \
 '-DCUSTOM_TOKEN_HEADER="sl_token_manager_af_token_header.h"' \
 '-DUSE_NVM3=1' \
 '-DUC_BUILD=1' \
 '-DEMBER_AF_NCP=1' \
 '-DEMBER_SERIAL1_RTSCTS=1' \
 '-DEZSP_UART=1' \
 '-DEMBER_MULTI_NETWORK_STRIPPED=1' \
 '-DSL_ZIGBEE_PHY_SELECT_STACK_SUPPORT=1' \
 '-DSL_ZIGBEE_STACK_COMPLIANCE_REVISION=22'

ASM_DEFS += \
 '-DEMBER_CUSTOM_MAC_FILTER_TABLE_SIZE=15' \
 '-DEFR32MG12P332F1024GL125=1' \
 '-DSL_APP_PROPERTIES=1' \
 '-DSL_BOARD_NAME="BRD4162A"' \
 '-DSL_BOARD_REV="A03"' \
 '-DHARDWARE_BOARD_DEFAULT_RF_BAND_2400=1' \
 '-DHARDWARE_BOARD_SUPPORTS_1_RF_BAND=1' \
 '-DHARDWARE_BOARD_SUPPORTS_RF_BAND_2400=1' \
 '-DHFXO_FREQ=38400000' \
 '-DSL_COMPONENT_CATALOG_PRESENT=1' \
 '-DSEGGER_RTT_ALIGNMENT=1024' \
 '-DCORTEXM3=1' \
 '-DCORTEXM3_EFM32_MICRO=1' \
 '-DCORTEXM3_EFR32=1' \
 '-DPHY_RAIL=1' \
 '-DPLATFORM_HEADER="platform-header.h"' \
 '-DSL_LEGACY_HAL_ENABLE_WATCHDOG=1' \
 '-DMBEDTLS_CONFIG_FILE=<sl_mbedtls_config.h>' \
 '-DMBEDTLS_PSA_CRYPTO_CLIENT=1' \
 '-DMBEDTLS_PSA_CRYPTO_CONFIG_FILE=<psa_crypto_config.h>' \
 '-DSL_RAIL_LIB_MULTIPROTOCOL_SUPPORT=0' \
 '-DSL_RAIL_UTIL_PA_CONFIG_HEADER=<sl_rail_util_pa_config.h>' \
 '-DRTT_USE_ASM=0' \
 '-DSEGGER_RTT_SECTION="SEGGER_RTT"' \
 '-DCUSTOM_TOKEN_HEADER="sl_token_manager_af_token_header.h"' \
 '-DUSE_NVM3=1' \
 '-DUC_BUILD=1' \
 '-DEMBER_AF_NCP=1' \
 '-DEMBER_SERIAL1_RTSCTS=1' \
 '-DEZSP_UART=1' \
 '-DEMBER_MULTI_NETWORK_STRIPPED=1' \
 '-DSL_ZIGBEE_PHY_SELECT_STACK_SUPPORT=1' \
 '-DSL_ZIGBEE_STACK_COMPLIANCE_REVISION=22'

INCLUDES += \
 -Iconfig \
 -Iautogen \
 -I$(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Include \
 -I$(COPIED_SDK_PATH)/platform/common/inc \
 -I$(COPIED_SDK_PATH)/hardware/board/inc \
 -I$(COPIED_SDK_PATH)/platform/bootloader \
 -I$(COPIED_SDK_PATH)/platform/bootloader/api \
 -I$(COPIED_SDK_PATH)/platform/CMSIS/Core/Include \
 -I$(COPIED_SDK_PATH)/hardware/driver/configuration_over_swo/inc \
 -I$(COPIED_SDK_PATH)/platform/driver/debug/inc \
 -I$(COPIED_SDK_PATH)/platform/service/device_init/inc \
 -I$(COPIED_SDK_PATH)/platform/emdrv/dmadrv/inc \
 -I$(COPIED_SDK_PATH)/platform/emdrv/common/inc \
 -I$(COPIED_SDK_PATH)/platform/emlib/inc \
 -I$(COPIED_SDK_PATH)/platform/service/iostream/inc \
 -I$(COPIED_SDK_PATH)/platform/service/legacy_common_ash/inc \
 -I$(COPIED_SDK_PATH)/platform/service/legacy_hal/inc \
 -I$(COPIED_SDK_PATH)/platform/service/legacy_hal_wdog/inc \
 -I$(COPIED_SDK_PATH)/platform/service/legacy_ncp_ash/inc \
 -I$(COPIED_SDK_PATH)/platform/service/legacy_printf/inc \
 -I$(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/config \
 -I$(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/config/preset \
 -I$(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/inc \
 -I$(COPIED_SDK_PATH)/util/third_party/mbedtls/include \
 -I$(COPIED_SDK_PATH)/util/third_party/mbedtls/library \
 -I$(COPIED_SDK_PATH)/hardware/driver/mx25_flash_shutdown/inc/sl_mx25_flash_shutdown_usart \
 -I$(COPIED_SDK_PATH)/platform/emdrv/nvm3/inc \
 -I$(COPIED_SDK_PATH)/platform/service/power_manager/inc \
 -I$(COPIED_SDK_PATH)/util/third_party/printf \
 -I$(COPIED_SDK_PATH)/util/third_party/printf/inc \
 -I$(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/inc \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/common \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/protocol/ble \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/protocol/ieee802154 \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/protocol/wmbus \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/protocol/zwave \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/chip/efr32/efr32xg1x \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/protocol/sidewalk \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_ieee802154 \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/efr32xg1x \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_power_manager_init \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_pti \
 -I$(COPIED_SDK_PATH)/util/third_party/segger/systemview/SEGGER \
 -I$(COPIED_SDK_PATH)/util/silicon_labs/silabs_core/memory_manager \
 -I$(COPIED_SDK_PATH)/platform/common/toolchain/inc \
 -I$(COPIED_SDK_PATH)/platform/service/system/inc \
 -I$(COPIED_SDK_PATH)/platform/service/sleeptimer/inc \
 -I$(COPIED_SDK_PATH)/platform/service/token_manager/inc \
 -I$(COPIED_SDK_PATH)/platform/service/udelay/inc \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/platform/micro \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/framework \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/include \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/gp \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/em260 \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/xncp \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/util/ezsp \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/framework/util \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/app/util/security \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/security \
 -I$(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin \
 -I$(COPIED_SDK_PATH)/protocol/zigbee \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack \
 -I$(COPIED_SDK_PATH)/platform/radio/mac/rail_mux \
 -I$(COPIED_SDK_PATH)/platform/radio/mac \
 -I$(COPIED_SDK_PATH)/util/silicon_labs/silabs_core \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/core \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/mac \
 -I$(COPIED_SDK_PATH)/protocol/zigbee/stack/zll

GROUP_START =-Wl,--start-group
GROUP_END =-Wl,--end-group

PROJECT_LIBS = \
 -lgcc \
 -lc \
 -lm \
 -lnosys \
 $(COPIED_SDK_PATH)/platform/emdrv/nvm3/lib/libnvm3_CM4_gcc.a \
 $(COPIED_SDK_PATH)/platform/radio/rail_lib/autogen/librail_release/librail_efr32xg12_gcc_release.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-debug-basic/release_singlenetwork/libzigbee-debug-basic.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-debug-extended/release_singlenetwork/libzigbee-debug-extended.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/ncp-gp-library/release_singlenetwork/libncp-gp-library.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-gp/release_singlenetwork/libzigbee-gp.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-ncp-uart/release_singlenetwork/libzigbee-ncp-uart.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/ncp-pro-library/release_singlenetwork/libncp-pro-library.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-pro-stack/release_singlenetwork/libzigbee-pro-stack.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-r22-support/release_singlenetwork/libzigbee-r22-support.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/ncp-source-route-library/release_singlenetwork/libncp-source-route-library.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-source-route/release_singlenetwork/libzigbee-source-route.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/ncp-zll-library/release_singlenetwork/libncp-zll-library.a \
 $(COPIED_SDK_PATH)/protocol/zigbee/build/gcc/cortex-m4/zigbee-zll/release_singlenetwork/libzigbee-zll.a

LIBS += $(GROUP_START) $(PROJECT_LIBS) $(GROUP_END)

LIB_FILES += $(filter %.a, $(PROJECT_LIBS))

C_FLAGS += \
 -mcpu=cortex-m4 \
 -mthumb \
 -mfpu=fpv4-sp-d16 \
 -mfloat-abi=softfp \
 -std=c99 \
 -Wall \
 -Wextra \
 -Os \
 -fdata-sections \
 -ffunction-sections \
 -fomit-frame-pointer \
 -imacros sl_gcc_preinclude.h \
 -fno-builtin-printf \
 -fno-builtin-sprintf \
 --specs=nano.specs \
 -Wno-unused-parameter \
 -Wno-missing-field-initializers \
 -Wno-missing-braces \
 -g

CXX_FLAGS += \
 -mcpu=cortex-m4 \
 -mthumb \
 -mfpu=fpv4-sp-d16 \
 -mfloat-abi=softfp \
 -std=c++11 \
 -fno-rtti \
 -fno-exceptions \
 -Wall \
 -Wextra \
 -Os \
 -fdata-sections \
 -ffunction-sections \
 -fomit-frame-pointer \
 -imacros sl_gcc_preinclude.h \
 -fno-builtin-printf \
 -fno-builtin-sprintf \
 --specs=nano.specs \
 -Wno-unused-parameter \
 -Wno-missing-field-initializers \
 -Wno-missing-braces \
 -g

ASM_FLAGS += \
 -mcpu=cortex-m4 \
 -mthumb \
 -mfpu=fpv4-sp-d16 \
 -mfloat-abi=softfp \
 -imacros sl_gcc_preinclude.h \
 -x assembler-with-cpp

LD_FLAGS += \
 -mcpu=cortex-m4 \
 -mthumb \
 -mfpu=fpv4-sp-d16 \
 -mfloat-abi=softfp \
 -T"autogen/linkerfile.ld" \
 --specs=nano.specs \
 -Xlinker -Map=$(OUTPUT_DIR)/$(PROJECTNAME).map \
 -Wl,--gc-sections \
 -Wl,--no-warn-rwx-segments


####################################################################
# Pre/Post Build Rules                                             #
####################################################################
pre-build:
	# No pre-build defined

post-build: $(OUTPUT_DIR)/$(PROJECTNAME).out
	# No post-build defined

####################################################################
# SDK Build Rules                                                  #
####################################################################
$(OUTPUT_DIR)/sdk/hardware/board/src/sl_board_control_gpio.o: $(COPIED_SDK_PATH)/hardware/board/src/sl_board_control_gpio.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/hardware/board/src/sl_board_control_gpio.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/hardware/board/src/sl_board_control_gpio.c
CDEPS += $(OUTPUT_DIR)/sdk/hardware/board/src/sl_board_control_gpio.d
OBJS += $(OUTPUT_DIR)/sdk/hardware/board/src/sl_board_control_gpio.o

$(OUTPUT_DIR)/sdk/hardware/board/src/sl_board_init.o: $(COPIED_SDK_PATH)/hardware/board/src/sl_board_init.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/hardware/board/src/sl_board_init.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/hardware/board/src/sl_board_init.c
CDEPS += $(OUTPUT_DIR)/sdk/hardware/board/src/sl_board_init.d
OBJS += $(OUTPUT_DIR)/sdk/hardware/board/src/sl_board_init.o

$(OUTPUT_DIR)/sdk/hardware/driver/configuration_over_swo/src/sl_cos.o: $(COPIED_SDK_PATH)/hardware/driver/configuration_over_swo/src/sl_cos.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/hardware/driver/configuration_over_swo/src/sl_cos.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/hardware/driver/configuration_over_swo/src/sl_cos.c
CDEPS += $(OUTPUT_DIR)/sdk/hardware/driver/configuration_over_swo/src/sl_cos.d
OBJS += $(OUTPUT_DIR)/sdk/hardware/driver/configuration_over_swo/src/sl_cos.o

$(OUTPUT_DIR)/sdk/hardware/driver/mx25_flash_shutdown/src/sl_mx25_flash_shutdown_usart/sl_mx25_flash_shutdown.o: $(COPIED_SDK_PATH)/hardware/driver/mx25_flash_shutdown/src/sl_mx25_flash_shutdown_usart/sl_mx25_flash_shutdown.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/hardware/driver/mx25_flash_shutdown/src/sl_mx25_flash_shutdown_usart/sl_mx25_flash_shutdown.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/hardware/driver/mx25_flash_shutdown/src/sl_mx25_flash_shutdown_usart/sl_mx25_flash_shutdown.c
CDEPS += $(OUTPUT_DIR)/sdk/hardware/driver/mx25_flash_shutdown/src/sl_mx25_flash_shutdown_usart/sl_mx25_flash_shutdown.d
OBJS += $(OUTPUT_DIR)/sdk/hardware/driver/mx25_flash_shutdown/src/sl_mx25_flash_shutdown_usart/sl_mx25_flash_shutdown.o

$(OUTPUT_DIR)/sdk/platform/bootloader/api/btl_interface.o: $(COPIED_SDK_PATH)/platform/bootloader/api/btl_interface.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/bootloader/api/btl_interface.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/bootloader/api/btl_interface.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/bootloader/api/btl_interface.d
OBJS += $(OUTPUT_DIR)/sdk/platform/bootloader/api/btl_interface.o

$(OUTPUT_DIR)/sdk/platform/bootloader/api/btl_interface_storage.o: $(COPIED_SDK_PATH)/platform/bootloader/api/btl_interface_storage.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/bootloader/api/btl_interface_storage.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/bootloader/api/btl_interface_storage.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/bootloader/api/btl_interface_storage.d
OBJS += $(OUTPUT_DIR)/sdk/platform/bootloader/api/btl_interface_storage.o

$(OUTPUT_DIR)/sdk/platform/bootloader/app_properties/app_properties.o: $(COPIED_SDK_PATH)/platform/bootloader/app_properties/app_properties.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/bootloader/app_properties/app_properties.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/bootloader/app_properties/app_properties.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/bootloader/app_properties/app_properties.d
OBJS += $(OUTPUT_DIR)/sdk/platform/bootloader/app_properties/app_properties.o

$(OUTPUT_DIR)/sdk/platform/common/src/sl_assert.o: $(COPIED_SDK_PATH)/platform/common/src/sl_assert.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/common/src/sl_assert.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/common/src/sl_assert.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_assert.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_assert.o

$(OUTPUT_DIR)/sdk/platform/common/src/sl_slist.o: $(COPIED_SDK_PATH)/platform/common/src/sl_slist.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/common/src/sl_slist.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/common/src/sl_slist.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_slist.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_slist.o

$(OUTPUT_DIR)/sdk/platform/common/src/sl_string.o: $(COPIED_SDK_PATH)/platform/common/src/sl_string.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/common/src/sl_string.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/common/src/sl_string.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_string.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_string.o

$(OUTPUT_DIR)/sdk/platform/common/src/sl_syscalls.o: $(COPIED_SDK_PATH)/platform/common/src/sl_syscalls.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/common/src/sl_syscalls.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/common/src/sl_syscalls.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_syscalls.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_syscalls.o

$(OUTPUT_DIR)/sdk/platform/common/toolchain/src/sl_memory.o: $(COPIED_SDK_PATH)/platform/common/toolchain/src/sl_memory.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/common/toolchain/src/sl_memory.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/common/toolchain/src/sl_memory.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/toolchain/src/sl_memory.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/toolchain/src/sl_memory.o

$(OUTPUT_DIR)/sdk/platform/Device/SiliconLabs/EFR32MG12P/Source/startup_efr32mg12p.o: $(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Source/startup_efr32mg12p.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Source/startup_efr32mg12p.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Source/startup_efr32mg12p.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/Device/SiliconLabs/EFR32MG12P/Source/startup_efr32mg12p.d
OBJS += $(OUTPUT_DIR)/sdk/platform/Device/SiliconLabs/EFR32MG12P/Source/startup_efr32mg12p.o

$(OUTPUT_DIR)/sdk/platform/Device/SiliconLabs/EFR32MG12P/Source/system_efr32mg12p.o: $(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Source/system_efr32mg12p.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Source/system_efr32mg12p.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/Device/SiliconLabs/EFR32MG12P/Source/system_efr32mg12p.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/Device/SiliconLabs/EFR32MG12P/Source/system_efr32mg12p.d
OBJS += $(OUTPUT_DIR)/sdk/platform/Device/SiliconLabs/EFR32MG12P/Source/system_efr32mg12p.o

$(OUTPUT_DIR)/sdk/platform/driver/debug/src/sl_debug_swo.o: $(COPIED_SDK_PATH)/platform/driver/debug/src/sl_debug_swo.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/driver/debug/src/sl_debug_swo.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/driver/debug/src/sl_debug_swo.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/driver/debug/src/sl_debug_swo.d
OBJS += $(OUTPUT_DIR)/sdk/platform/driver/debug/src/sl_debug_swo.o

$(OUTPUT_DIR)/sdk/platform/emdrv/dmadrv/src/dmadrv.o: $(COPIED_SDK_PATH)/platform/emdrv/dmadrv/src/dmadrv.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emdrv/dmadrv/src/dmadrv.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emdrv/dmadrv/src/dmadrv.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emdrv/dmadrv/src/dmadrv.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emdrv/dmadrv/src/dmadrv.o

$(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_default_common_linker.o: $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_default_common_linker.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_default_common_linker.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_default_common_linker.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_default_common_linker.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_default_common_linker.o

$(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_hal_flash.o: $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_hal_flash.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_hal_flash.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_hal_flash.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_hal_flash.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_hal_flash.o

$(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_lock.o: $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_lock.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_lock.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emdrv/nvm3/src/nvm3_lock.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_lock.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emdrv/nvm3/src/nvm3_lock.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_cmu.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_cmu.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_cmu.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_cmu.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_cmu.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_cmu.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_core.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_core.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_core.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_core.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_core.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_core.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_crypto.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_crypto.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_crypto.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_crypto.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_crypto.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_crypto.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_emu.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_emu.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_emu.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_emu.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_emu.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_emu.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_gpio.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_gpio.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_gpio.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_gpio.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_gpio.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_gpio.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_ldma.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_ldma.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_ldma.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_ldma.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_ldma.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_ldma.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_msc.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_msc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_msc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_msc.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_msc.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_msc.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_prs.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_prs.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_prs.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_prs.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_prs.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_prs.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_rmu.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_rmu.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_rmu.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_rmu.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_rmu.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_rmu.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_rtcc.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_rtcc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_rtcc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_rtcc.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_rtcc.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_rtcc.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_system.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_system.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_system.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_system.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_system.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_system.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_timer.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_timer.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_timer.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_timer.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_timer.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_timer.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_usart.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_usart.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_usart.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_usart.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_usart.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_usart.o

$(OUTPUT_DIR)/sdk/platform/emlib/src/em_wdog.o: $(COPIED_SDK_PATH)/platform/emlib/src/em_wdog.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/emlib/src/em_wdog.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/emlib/src/em_wdog.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_wdog.d
OBJS += $(OUTPUT_DIR)/sdk/platform/emlib/src/em_wdog.o

$(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/coexistence/protocol/ieee802154_uc/coexistence-802154.o: $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/coexistence/protocol/ieee802154_uc/coexistence-802154.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/coexistence/protocol/ieee802154_uc/coexistence-802154.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/coexistence/protocol/ieee802154_uc/coexistence-802154.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/coexistence/protocol/ieee802154_uc/coexistence-802154.d
OBJS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/coexistence/protocol/ieee802154_uc/coexistence-802154.o

$(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/pa-conversions/pa_conversions_efr32.o: $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/pa_conversions_efr32.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/pa_conversions_efr32.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/pa_conversions_efr32.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/pa-conversions/pa_conversions_efr32.d
OBJS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/pa-conversions/pa_conversions_efr32.o

$(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/pa-conversions/pa_curves_efr32.o: $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/pa_curves_efr32.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/pa_curves_efr32.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/pa-conversions/pa_curves_efr32.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/pa-conversions/pa_curves_efr32.d
OBJS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/pa-conversions/pa_curves_efr32.o

$(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_ant_div/sl_rail_util_ant_div.o: $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_ant_div/sl_rail_util_ant_div.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_ant_div/sl_rail_util_ant_div.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_ant_div/sl_rail_util_ant_div.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_ant_div/sl_rail_util_ant_div.d
OBJS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_ant_div/sl_rail_util_ant_div.o

$(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_power_manager_init/sl_rail_util_power_manager_init.o: $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_power_manager_init/sl_rail_util_power_manager_init.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_power_manager_init/sl_rail_util_power_manager_init.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_power_manager_init/sl_rail_util_power_manager_init.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_power_manager_init/sl_rail_util_power_manager_init.d
OBJS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_power_manager_init/sl_rail_util_power_manager_init.o

$(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_pti/sl_rail_util_pti.o: $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_pti/sl_rail_util_pti.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_pti/sl_rail_util_pti.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/radio/rail_lib/plugin/rail_util_pti/sl_rail_util_pti.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_pti/sl_rail_util_pti.d
OBJS += $(OUTPUT_DIR)/sdk/platform/radio/rail_lib/plugin/rail_util_pti/sl_rail_util_pti.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/crypto_aes.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/crypto_aes.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/crypto_aes.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/crypto_aes.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/crypto_aes.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/crypto_aes.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/mbedtls_ccm.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/mbedtls_ccm.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/mbedtls_ccm.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/mbedtls_ccm.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/mbedtls_ccm.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/mbedtls_ccm.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/sl_mbedtls.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/sl_mbedtls.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/sl_mbedtls.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_mbedtls_support/src/sl_mbedtls.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/sl_mbedtls.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_mbedtls_support/src/sl_mbedtls.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/crypto_management.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/crypto_management.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/crypto_management.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/crypto_management.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/crypto_management.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/crypto_management.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_aead.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_aead.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_aead.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_aead.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_aead.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_aead.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_cipher.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_cipher.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_cipher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_cipher.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_cipher.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_cipher.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_hash.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_hash.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_hash.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_hash.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_hash.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_hash.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_mac.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_mac.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_mac.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_mac.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_mac.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_crypto_transparent_driver_mac.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_common.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_common.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_common.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_common.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_init.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_init.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_init.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_init.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_init.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_psa_driver_init.o

$(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_se_version_dependencies.o: $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_se_version_dependencies.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_se_version_dependencies.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/security/sl_component/sl_psa_driver/src/sli_se_version_dependencies.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_se_version_dependencies.d
OBJS += $(OUTPUT_DIR)/sdk/platform/security/sl_component/sl_psa_driver/src/sli_se_version_dependencies.o

$(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_dcdc_s1.o: $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_dcdc_s1.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_dcdc_s1.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_dcdc_s1.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_dcdc_s1.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_dcdc_s1.o

$(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_emu_s1.o: $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_emu_s1.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_emu_s1.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_emu_s1.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_emu_s1.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_emu_s1.o

$(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_hfxo_s1.o: $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_hfxo_s1.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_hfxo_s1.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_hfxo_s1.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_hfxo_s1.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_hfxo_s1.o

$(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_lfxo_s1.o: $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_lfxo_s1.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_lfxo_s1.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_lfxo_s1.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_lfxo_s1.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_lfxo_s1.o

$(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_nvic.o: $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_nvic.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_nvic.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/device_init/src/sl_device_init_nvic.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_nvic.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/device_init/src/sl_device_init_nvic.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream.o: $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_debug.o: $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_debug.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_debug.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_debug.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_debug.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_debug.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_swo_itm_8.o: $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_swo_itm_8.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_swo_itm_8.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_swo_itm_8.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_swo_itm_8.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_swo_itm_8.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_uart.o: $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_uart.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_uart.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_uart.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_uart.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_uart.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_usart.o: $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_usart.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_usart.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_usart.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_usart.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_usart.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_vuart.o: $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_vuart.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_vuart.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/iostream/src/sl_iostream_vuart.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_vuart.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_vuart.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_common_ash/src/ash-common.o: $(COPIED_SDK_PATH)/platform/service/legacy_common_ash/src/ash-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_common_ash/src/ash-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_common_ash/src/ash-common.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_common_ash/src/ash-common.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_common_ash/src/ash-common.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/base-replacement.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/base-replacement.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/base-replacement.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/base-replacement.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/base-replacement.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/base-replacement.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/crc.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/crc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/crc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/crc.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/crc.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/crc.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/diagnostic.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/diagnostic.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/diagnostic.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/diagnostic.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/diagnostic.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/diagnostic.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/ember-phy.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/ember-phy.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/ember-phy.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/ember-phy.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/ember-phy.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/ember-phy.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/faults.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/faults.s
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/faults.s'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(ASMFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/faults.s
ASMDEPS_s += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/faults.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/faults.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/random.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/random.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/random.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/random.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/random.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/random.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/token_legacy.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/token_legacy.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/token_legacy.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal/src/token_legacy.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/token_legacy.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/token_legacy.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal_wdog/src/sl_legacy_hal_wdog.o: $(COPIED_SDK_PATH)/platform/service/legacy_hal_wdog/src/sl_legacy_hal_wdog.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_hal_wdog/src/sl_legacy_hal_wdog.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_hal_wdog/src/sl_legacy_hal_wdog.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal_wdog/src/sl_legacy_hal_wdog.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal_wdog/src/sl_legacy_hal_wdog.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_ncp_ash/src/ash-ncp.o: $(COPIED_SDK_PATH)/platform/service/legacy_ncp_ash/src/ash-ncp.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_ncp_ash/src/ash-ncp.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_ncp_ash/src/ash-ncp.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_ncp_ash/src/ash-ncp.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_ncp_ash/src/ash-ncp.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_printf/src/sl_legacy_printf.o: $(COPIED_SDK_PATH)/platform/service/legacy_printf/src/sl_legacy_printf.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/legacy_printf/src/sl_legacy_printf.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/legacy_printf/src/sl_legacy_printf.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_printf/src/sl_legacy_printf.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_printf/src/sl_legacy_printf.o

$(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager.o: $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager.o

$(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager_debug.o: $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager_debug.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager_debug.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager_debug.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager_debug.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager_debug.o

$(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager_hal_s0_s1.o: $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager_hal_s0_s1.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager_hal_s0_s1.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/power_manager/src/sl_power_manager_hal_s0_s1.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager_hal_s0_s1.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/power_manager/src/sl_power_manager_hal_s0_s1.o

$(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer.o: $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer.o

$(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer_hal_rtcc.o: $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer_hal_rtcc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer_hal_rtcc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer_hal_rtcc.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer_hal_rtcc.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer_hal_rtcc.o

$(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer_hal_timer.o: $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer_hal_timer.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer_hal_timer.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/sleeptimer/src/sl_sleeptimer_hal_timer.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer_hal_timer.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/sleeptimer/src/sl_sleeptimer_hal_timer.o

$(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_init.o: $(COPIED_SDK_PATH)/platform/service/system/src/sl_system_init.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/system/src/sl_system_init.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/system/src/sl_system_init.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_init.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_init.o

$(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_process_action.o: $(COPIED_SDK_PATH)/platform/service/system/src/sl_system_process_action.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/system/src/sl_system_process_action.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/system/src/sl_system_process_action.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_process_action.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_process_action.o

$(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_def.o: $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_def.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_def.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_def.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_def.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_def.o

$(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manager.o: $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manager.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manager.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manager.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manager.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manager.o

$(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manufacturing.o: $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manufacturing.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manufacturing.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manufacturing.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manufacturing.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manufacturing.o

$(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manufacturing_generic.o: $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manufacturing_generic.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manufacturing_generic.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/token_manager/src/sl_token_manufacturing_generic.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manufacturing_generic.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_manufacturing_generic.o

$(OUTPUT_DIR)/sdk/platform/service/udelay/src/sl_udelay.o: $(COPIED_SDK_PATH)/platform/service/udelay/src/sl_udelay.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/udelay/src/sl_udelay.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/udelay/src/sl_udelay.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/udelay/src/sl_udelay.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/udelay/src/sl_udelay.o

$(OUTPUT_DIR)/sdk/platform/service/udelay/src/sl_udelay_armv6m_gcc.o: $(COPIED_SDK_PATH)/platform/service/udelay/src/sl_udelay_armv6m_gcc.S
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/platform/service/udelay/src/sl_udelay_armv6m_gcc.S'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(ASMFLAGS) -c -o $@ $(COPIED_SDK_PATH)/platform/service/udelay/src/sl_udelay_armv6m_gcc.S
ASMDEPS_S += $(OUTPUT_DIR)/sdk/platform/service/udelay/src/sl_udelay_armv6m_gcc.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/udelay/src/sl_udelay_armv6m_gcc.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-binding-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-binding-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-binding-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-binding-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-binding-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-binding-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-green-power-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-green-power-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-green-power-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-green-power-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-green-power-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-green-power-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-messaging-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-messaging-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-messaging-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-messaging-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-messaging-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-messaging-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-networking-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-networking-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-networking-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-networking-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-networking-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-networking-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-security-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-security-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-security-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-security-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-security-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-security-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-trust-center-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-trust-center-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-trust-center-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-trust-center-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-trust-center-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-trust-center-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-zll-generated.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-zll-generated.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-zll-generated.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/command-handlers-zll-generated.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-zll-generated.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/command-handlers-zll-generated.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/em260-common.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/em260-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/em260-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/em260-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/em260-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/em260-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/ncp-stack-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/ncp-stack-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/ncp-stack-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/ncp-stack-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/ncp-stack-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/ncp-stack-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/serial-interface-uart.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/serial-interface-uart.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/serial-interface-uart.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/em260/serial-interface-uart.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/serial-interface-uart.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/em260/serial-interface-uart.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_common.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_sleep.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_sleep.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_sleep.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_sleep.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_sleep.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_sleep.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_stack_cb.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_stack_cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_stack_cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_stack_cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_stack_cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_stack_cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_enhanced_routing.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_enhanced_routing.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_enhanced_routing.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_enhanced_routing.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_enhanced_routing.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_enhanced_routing.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_ncp_framework_cb.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_ncp_framework_cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_ncp_framework_cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_ncp_framework_cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_ncp_framework_cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_ncp_framework_cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/security/security-address-cache.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/util/security/security-address-cache.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/util/security/security-address-cache.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/util/security/security-address-cache.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/security/security-address-cache.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/security/security-address-cache.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/xncp/xncp-stubs.o: $(COPIED_SDK_PATH)/protocol/zigbee/app/xncp/xncp-stubs.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/app/xncp/xncp-stubs.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/app/xncp/xncp-stubs.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/xncp/xncp-stubs.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/xncp/xncp-stubs.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration-access.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/config/ember-configuration-access.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/config/ember-configuration-access.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/config/ember-configuration-access.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration-access.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration-access.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/config/ember-configuration.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/config/ember-configuration.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/config/ember-configuration.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/ember-multi-network-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/ember-multi-network-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/ember-multi-network-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/ember-multi-network-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/ember-multi-network-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/ember-multi-network-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/multi-pan-common.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/multi-pan-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/multi-pan-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/multi-pan-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/multi-pan-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/multi-pan-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/multi-pan-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/multi-pan-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/multi-pan-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/core/multi-pan-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/multi-pan-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/core/multi-pan-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/aes-ecb.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/aes-ecb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/aes-ecb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/aes-ecb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/aes-ecb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/aes-ecb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/strong-random-api.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/strong-random-api.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/strong-random-api.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/strong-random-api.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/strong-random-api.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/strong-random-api.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/zigbee-event-logger-stub-gen.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/zigbee-event-logger-stub-gen.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/zigbee-event-logger-stub-gen.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/framework/zigbee-event-logger-stub-gen.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/zigbee-event-logger-stub-gen.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/framework/zigbee-event-logger-stub-gen.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-163k1-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-163k1-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-163k1-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-163k1-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-163k1-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-163k1-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-283k1-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-283k1-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-283k1-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-283k1-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-283k1-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-283k1-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-sign-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-sign-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-sign-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-sign-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-sign-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-sign-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-283k1-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-283k1-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-283k1-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-283k1-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-283k1-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-283k1-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-dsa-verify-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-stub.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-stub.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-stub.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/cbke-crypto-engine-stub.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-stub.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/cbke-crypto-engine-stub.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager-no-vault.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager-no-vault.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager-no-vault.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager-no-vault.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager-no-vault.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager-no-vault.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_dynamic_commissioning_stubs.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_dynamic_commissioning_stubs.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_dynamic_commissioning_stubs.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_dynamic_commissioning_stubs.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_dynamic_commissioning_stubs.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_dynamic_commissioning_stubs.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_fragmentation_stubs.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_fragmentation_stubs.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_fragmentation_stubs.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_fragmentation_stubs.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_fragmentation_stubs.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_fragmentation_stubs.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_r23_misc_support_stubs.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_r23_misc_support_stubs.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_r23_misc_support_stubs.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/stubs/sl_zigbee_r23_misc_support_stubs.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_r23_misc_support_stubs.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/stubs/sl_zigbee_r23_misc_support_stubs.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/zigbee/aps-keys-full.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee/aps-keys-full.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee/aps-keys-full.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee/aps-keys-full.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/zigbee/aps-keys-full.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/zigbee/aps-keys-full.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/zigbee/sli_zigbee_zdo_cluster_filter.o: $(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee/sli_zigbee_zdo_cluster_filter.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee/sli_zigbee_zdo_cluster_filter.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/protocol/zigbee/stack/zigbee/sli_zigbee_zdo_cluster_filter.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/zigbee/sli_zigbee_zdo_cluster_filter.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/zigbee/sli_zigbee_zdo_cluster_filter.o

$(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/memory_manager/sl_malloc.o: $(COPIED_SDK_PATH)/util/silicon_labs/silabs_core/memory_manager/sl_malloc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/silicon_labs/silabs_core/memory_manager/sl_malloc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/silicon_labs/silabs_core/memory_manager/sl_malloc.c
CDEPS += $(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/memory_manager/sl_malloc.d
OBJS += $(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/memory_manager/sl_malloc.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/aes.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/aes.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/aes.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/aes.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/aes.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/aes.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/ccm.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/ccm.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/ccm.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/ccm.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/ccm.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/ccm.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/cipher.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/cipher.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/cipher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/cipher.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/cipher.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/cipher.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/cipher_wrap.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/cipher_wrap.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/cipher_wrap.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/cipher_wrap.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/cipher_wrap.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/cipher_wrap.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/constant_time.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/constant_time.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/constant_time.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/constant_time.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/constant_time.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/constant_time.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/platform.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/platform.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/platform.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/platform.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/platform.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/platform.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/platform_util.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/platform_util.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/platform_util.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/platform_util.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/platform_util.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/platform_util.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/psa_crypto_client.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/psa_crypto_client.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/psa_crypto_client.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/psa_crypto_client.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/psa_crypto_client.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/psa_crypto_client.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/psa_util.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/psa_util.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/psa_util.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/psa_util.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/psa_util.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/psa_util.o

$(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/threading.o: $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/threading.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/threading.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/mbedtls/library/threading.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/threading.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/mbedtls/library/threading.o

$(OUTPUT_DIR)/sdk/util/third_party/printf/printf.o: $(COPIED_SDK_PATH)/util/third_party/printf/printf.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/printf/printf.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/printf/printf.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/printf/printf.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/printf/printf.o

$(OUTPUT_DIR)/sdk/util/third_party/printf/src/iostream_printf.o: $(COPIED_SDK_PATH)/util/third_party/printf/src/iostream_printf.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/printf/src/iostream_printf.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/printf/src/iostream_printf.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/printf/src/iostream_printf.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/printf/src/iostream_printf.o

$(OUTPUT_DIR)/sdk/util/third_party/segger/systemview/SEGGER/SEGGER_RTT.o: $(COPIED_SDK_PATH)/util/third_party/segger/systemview/SEGGER/SEGGER_RTT.c
	@$(POSIX_TOOL_PATH)echo 'Building $(COPIED_SDK_PATH)/util/third_party/segger/systemview/SEGGER/SEGGER_RTT.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(COPIED_SDK_PATH)/util/third_party/segger/systemview/SEGGER/SEGGER_RTT.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/segger/systemview/SEGGER/SEGGER_RTT.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/segger/systemview/SEGGER/SEGGER_RTT.o

$(OUTPUT_DIR)/project/app.o: app.c
	@$(POSIX_TOOL_PATH)echo 'Building app.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app.c
CDEPS += $(OUTPUT_DIR)/project/app.d
OBJS += $(OUTPUT_DIR)/project/app.o

$(OUTPUT_DIR)/project/autogen/sl_board_default_init.o: autogen/sl_board_default_init.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_board_default_init.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_board_default_init.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_board_default_init.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_board_default_init.o

$(OUTPUT_DIR)/project/autogen/sl_device_init_clocks.o: autogen/sl_device_init_clocks.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_device_init_clocks.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_device_init_clocks.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_device_init_clocks.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_device_init_clocks.o

$(OUTPUT_DIR)/project/autogen/sl_event_handler.o: autogen/sl_event_handler.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_event_handler.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_event_handler.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_event_handler.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_event_handler.o

$(OUTPUT_DIR)/project/autogen/sl_iostream_handles.o: autogen/sl_iostream_handles.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_iostream_handles.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_iostream_handles.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_iostream_handles.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_iostream_handles.o

$(OUTPUT_DIR)/project/autogen/sl_iostream_init_usart_instances.o: autogen/sl_iostream_init_usart_instances.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_iostream_init_usart_instances.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_iostream_init_usart_instances.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_iostream_init_usart_instances.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_iostream_init_usart_instances.o

$(OUTPUT_DIR)/project/autogen/sl_power_manager_handler.o: autogen/sl_power_manager_handler.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_power_manager_handler.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_power_manager_handler.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_power_manager_handler.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_power_manager_handler.o

$(OUTPUT_DIR)/project/autogen/sl_rail_util_ieee802154_phy_select.o: autogen/sl_rail_util_ieee802154_phy_select.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_rail_util_ieee802154_phy_select.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_rail_util_ieee802154_phy_select.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_rail_util_ieee802154_phy_select.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_rail_util_ieee802154_phy_select.o

$(OUTPUT_DIR)/project/autogen/sl_rail_util_ieee802154_stack_event.o: autogen/sl_rail_util_ieee802154_stack_event.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_rail_util_ieee802154_stack_event.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_rail_util_ieee802154_stack_event.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_rail_util_ieee802154_stack_event.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_rail_util_ieee802154_stack_event.o

$(OUTPUT_DIR)/project/autogen/zigbee_common_callback_dispatcher.o: autogen/zigbee_common_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_common_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_common_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_common_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_common_callback_dispatcher.o

$(OUTPUT_DIR)/project/autogen/zigbee_ncp_callback_dispatcher.o: autogen/zigbee_ncp_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_ncp_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_ncp_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_ncp_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_ncp_callback_dispatcher.o

$(OUTPUT_DIR)/project/autogen/zigbee_stack_callback_dispatcher.o: autogen/zigbee_stack_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_stack_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_stack_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_stack_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_stack_callback_dispatcher.o

$(OUTPUT_DIR)/project/main.o: main.c
	@$(POSIX_TOOL_PATH)echo 'Building main.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ main.c
CDEPS += $(OUTPUT_DIR)/project/main.d
OBJS += $(OUTPUT_DIR)/project/main.o

# Automatically-generated Simplicity Studio Metadata
# Please do not edit or delete these lines!
# SIMPLICITY_STUDIO_METADATA=eJzsvQmT20iSJvpX2mRrz/ZoJHEftd09plZl1eitVNJTqrZ3dmoMhgSDJDoBAg2AeWhs//uLCAAkAAIk4OGBVO3udI0kksDnX9weEX78+5u79x8/f3j/7v3Xf/Hvvv764/tP/ucfP969+eHNn/7pOYl/++0PjyQvonT/59/eaDfqb2/oN2Qfputov6Vf/fr1J8X97c0//eW3337b/ynL07+TsKSP7IOE0J8P4U2Srg8xuSlIechuDuG7dL+Jtjf7MFMOQV4qu6ebbRhyWPp2RvLy5S6kf9OXG7Q3HJw+QP/70yaN1yQ/SQg5XueZ5skoJqfnithPSJLmL371xs2Oy9ySPcmDkqzpI2V+IPzLONo/8G82QVzQr1YTwKO0KHMSJP6hoMXyH8M0kSTpW7S9J8Rfk/vD1s/yaF/KLtIjaylJQsr0gez9JNgHW5JLkhEeipI2RyVqRwLagSSJoOU4bIKwPNBm2UoVWPcCOkb8ogzCB7mdrUgPeUj8PD2URK6kbU5onWXpk7Te0BSJhLSVyhefYfgP5KWQKy+OtruyEiZBTlOomJBMBv7d7c8/337xv3z96rMZHBV7/5gYdDrbBIdY1ixTTZbFUyoDf50E6/xRBjJJ4uieAufNdC+ndqrRJnEOzorAD/OXrJRS/7x9HyM6P0X7qPTX4TpcQEy8eZZVmphsg/DF3wWx/7ROZbV6HkSxfyjpH1kZSZJxnwb5mmGXeRrLkBFkmV/rjRGRNYO3m50kB0lSkmfd8jdxUOz8Ynco1+nTvlYmJchrdTHpvaszu/BKlN9MO3mjs1WyQIaI+5Kq3vuS5FSRpMrWBr0AXEkoo0SahpXck3UZyxqNDXrd3PIGB93CJeneZwNSTMifVtWutf1VtA/jw5p8Dsod/Ug1UVa48rCO0h9W9cZ31extK6w/Nd/zT3+Qsz3/SpIspmXD26AHhzKlNTZph14tF40qyAbyTSX5/hDFZbRvV/h5K0zpPHS9iKMwKGmN+eVLRuomxcH/8vWWasdJlu7JvixQodkWs0H2Kf8gTrfYAtrzZxin4UOBXfvkkdHfBft1fNwRSwJHZn48C6nw0Rv3DF8Wf9660b4og30osRhcTKW9nIRJLVNfGG7Jot6i5tfTmmwxZR7si02aJ5IE9rQzOaMn8vkGUG7FMRE1mlxRLQUwIoS4qq5Zpp/tXvyCxHQ5xO7mg+KqMz8+5aHK42pMzr67ideIuM35VHVUGcTxPfvHOiqyoAx3yIvBVWGYNVYLq5XFhYp2QZqEslFdcKmCjYmSUKpg0zmgB68YUO3+qBgvpt7XD3wkZbCmKuQr6PhsNj4d1/zvXt9Hjf2Of0Sr7i0JH1K/WD/45o3FWA5Ue+8VtqljasTAsyNv/Mh3A6PPj7x1F9HtVbr/ENwXV14dAbj96Yuhf/xZ0z9Pen+MBr+vmoEw2FvpApLThvPJJjf0ZKvpWT0P9Tf7Z32Ots2qqfJVVZOrVtWsTqVcVVRXw7LO57J5BXgpSpIsw39I1HT6A4N6ZpO/r6YA0TY/FcAw9I2m6uY21nSrXhwwK64mvLogUbD5T8h+ECbZImU4SkLkvg4Xol4JQmS+8TO6I12I/UkYbgnSvFywCI00vDKEyWEZ+rUgROb5S8oP6hfi3xaHWoqsTBcrQi0LkX9xPEOQzb6WhMednenuNwtVfksYYgmSgAIXYR7Rhl1oIJzLRC1PTv6xWDlqWXj8yVKzKcGeTUmZLMS8EoTHfJMdyG4Z7kdReOy3WZgvpMEdRWGyjxaaPhtJuNz9hfT+kyw8/pG+UL+pBSEyXwdLUa8l4XGP6bKxDPdGEi53P1xormwJQywBoUpgQRYqwUkYegn8+8Nm0VI0AvFLsliH6sjDL0dRLluOSh5mORbcDbeEYZaA3QAsVYBGFh7/pFhoWasF4THPwv1C9d5IQuSeL3QAVwtCZb7Y7HmShcu/iLZ7Sni5QrQE4pUkX2rfnmPv2/M0KYP7eCGVqC0NsQxluNDE2UjC5e4vSd+XUoKcLDT/t6XhlaFYavwW2ON3QZ1NgsZWO0os1P3b0hDLkO+3C/GvJeFx53a9y5A/isJj/7jYOdAj+jkQQ/TTbKGzoLY0vDIw/8ll+DeScLnTzcRC2nNbmmgZktqXRCbztgx0Myl5vAdlSbGTmvTolYeu/XwejYXZJc81Goz24URjwTN3rjJNItgEW1FdUdmrDtCUthhwPtqvo2C/JwVsm9gl0wWDEjrAbjv7VA6T7zIHmqcoCHDx7jXPEQhGpEJDIHICghEpShYZBoHICQhIJI6Ap8E9Hg0OtD6C8oAxZk5Al4lMmxX7M1SRg2eoqudC7G7rAlLZqw6QUM8TJ3ICAhJ5KZiHR4FBpQUlMgwQmDQ4MnpfmaZxuAuiawurYOcdq6MqbppIJR0L0FTXCXJSs81QeqC6xeXC+znZRmILyKkO6hnrDHmGFjjWRvj8RIltw9DPclI76KASPIdG60zIavF9mpZxyrzM5qrG3fg2kDWoiwAaxSf6qy7a6hxcxvwXZBGk5J1AKuIFj1ZngIA1pxvdpSjTPNjik2sDA0i2o2S0mhcyeHssx5GBdUnyPM3DFDi1DNRhB1C0gbFIdQCFe10W5AXwRP5ipzvhog0MdI4tYCDJnBSEBZoAWtUPsOsiCs2gc1emdx/v3t/NXZTepfk0PzsEJ71eA4RJERU8FE4UA7swL/KKleF4KHeOClZ5KqjaixiXXwsUTK/8xqPxkWfY3n+AWxdRsN62wHu20Trbzr1K69NisTfDxERj1cIDk0qygx/kyaODxaoD+L0q0es8epyvQPO4qa+zbz4GnQWpd1VxVxyk2TZ3EL/3nfOJLKSXdopfb/g6iN9rN6UaECRwQiv4Gqy3ijfXWfQ3SLvVxV+14E7NNyRB5HChH/ZXJuMGH4sv1I9uIt3Z3nPX46nKpNvgY/GNJfONkfnuH4HXmBP5NviyFw3xNbMXyLvQQKvnULUcF9FBEYjjWjLpkwTM0S2ZdEsE5hiXzDrGZ81HokTKDf5S+tHIRNAE53wd1buRLlTRDUhTy21Qkd5wjFvK9VkpFE/QKERZ4oyoTHxXDtkOPAph7vgkhWuDjEOzkMezwCT6KK9CH+fU6GvuZ4/DX0RNO1ZDraO1QRHnFBkUT9ACRKOhUY/IdgwfeRqUUr/4hMG+ple5zvcsvdQVsHkOQCPO13IqdL7vwdX5WgrRR9QahR4PThlMS54SNgXtrTlnmUReQR2mUpXabFVkAT8rCl/Ju+Df9RLeoirS487rgXW9Ljh4aDCYLE/LNExjSSzb8N/H6NgF8SsMCxYoCmE8UPJ8INRw4Ja/Dwqi5ISKCUlyiuqPwm0IG0x0HQXbPZ1lBU8xehS7qGByJLknuZLtYNaqI9w6oGBqPKdRcVPg8TohgknlwX6dip2S9EidEOE2Cjwqf4WLSa2P+72tVucXidHEmfFCZVYoGGsJq0auZXHE1Ql4ySjfYZqX5DkxRKulNd8gVk3DbtWFX7KCpi6mF+pmh9tf2N+7BXpKT5ESO6fplaGGg6/uR6M/Rcw2dITfGD4qYSXIYJ6xM0g3MjCIE0J1XdRuMAgOp3ooS5zNyJHfERFu8AYM1To2I84Nx3rmDp8Yup9EYS52TtCj1YMV0Df152eF2+8qa7IRM5npcxzAFiBaZRJvpTFFItnFBRPEX3SE6PAJKT9kZaHwvoLJbQgbTDQma0xuNRzcNJUNKcRjloZXH1eQIEv9ijpYe7Bi9NCJCVFqJChVnjRMcgPQoltZRHYnRDipZvZG5dUGhZ/CS9oYirknsC26kgT7A1UGywNzNFcYLCkUDZPqNTkyCoC6hlyTg1kAybxF75JOErib1zavvAt3aSpowtzv3tdFfTfn6Tya0+uYXvVIIB3gcazGdmRAxPd2lnetVnD6ZVUr551zTiwy+f2R5XR9vatPKh2jD9aFOF561rDfdb9reCJ0tqb4zS1iDft9dLCMLiPl5lWnu4oCRkerkHpT3Qn+u+5wZ4QRel5dH91J7gT/yj0wS59I7lN9Jthe9U2U1AM7FIR6YAep6YFn8CK6WgcMwf75OmMcS+guJFtiC1XU9WAC944gIVO7Li4dPo9BKXYDMUT/gpzvfd7qdnO8iqnnrTN47FEklzGS7a/cSh7Af+XVoQr2+jrLQh1olvkECU1TFU4r4l4bVaQX11BZnoakKPwgZHtpfKrn+N/7VNSuY5ExUldHEyCzi4rfcuhUz/FfezjHhGQ8Qv8rDemjfLFhcoQ5Ra9sAwt1jSMSV154MhJZXDsSEEnLreGuCKHltAsqNgD7jIfQv/uJ89SNkeriGOS4DYzUZrgc+8ivPFVWtpavui+uKLBrMpGh3ClIM5o70CIzTwddFk+kvfsRrHV1I49xVwgyb39L9iQXtGCfyr8t7HufQSv6QRYJTU7dmqnn0A403piRxBNpp94B84NN/QWCJcV17kPisMe/vBLg3Q8PDUmJPXxQEDb/6qrfF7OJmFyItjRJJREzjphbEjETiSvT/CIFaQl7ZU3vsCZx8PI6Kl4lW2gVryCa5fsEKNI7KhQeUdNOeAjSO2SGPezvXa2oq1VkZNS1UA+JE+D3GgaSJOv8cXYQyCS4/paMsVQJBg0kXtBVBVC5ch6xvutuWdOE9MlOkVmPPGG98mQ8Kf+ajNok4BD8VWW2kjmRWcH35dXl/nGimyFuTTKx7GiBOfcKVCiD4dXZxwMvbAwIi5AwESFta6iGZipU48SgJ7FDpES9WBoQfxMHBSyP6AitE6IYORYGGI1XA/ZdBzltj8cmPgcvOuz8r1UPbPG9jI7VkbCIdhAROhIWrwZMdkeKo3t4R6Ivc7LvPpp8HxCIFZ7CrQYgv1/9+nrlYSWaJYkf7iKYHS3nWbtKHlEAmWfY28CI4V0K0+OCDzLgWVICqGbSJdLCAvBhd14otdIFgtWMQKbbTq0IJbql798Dk6l2SNxPSaQ62kfgvp/d/iGSaZe+nwfJ5rCHKogtIi0gGBORZEAdJjMTAA21TQ7dpHVaJofmz6rfFtTee1xmH4aec8pfshLmdttlc8QR4YE3xfbhYKygmSo6XGbkozhnsM0ihNZpUGAc4nUSiHNoUGAckgJhyNQgYAZo3bOLBeOT5QjrXQ0CXGcwRkcuMjq4CZw4hXJ6qrRzDpXJpjiLE44ID7z15RwPxgtu8dWhM8+864wFPH5xh8WsWMXnLMAOsB0S03xcgYa+Ew94hvdosFMIVrQq2mQDIqDjiVOoUYT0KXEWRxy45iJMgoi0Btc5hCk0KAKaizCHBgWuuQhTqEHgmoIwgxoErikIM8hFeiPYHL9LYYbJ/aimIMzihCOyIgvTmGXJP7YiC7OYle1lZEUWJjEtFgd6us2Q8iuvGSAN+PLwvUe6J3tgwk2KkNyTdRkXfnHIsjSfhjOCVoXQE472G0dHUkEYkphUIWqApjdV1a7adbU6L/aq4r66JHz65c7VcqXJPspYDKw91D0OXqyebIRSZUXwOi01JHjJQMXzLlFH6q8pINAEcGKt1aZ3LVmCDV8fzAVkAeJdWYLEGwFhCA0aP4N5T9iSnXOeBc+1zil1SNcWkS1Zgm1Me4ofAG2PZrFuCRIdT2GyDOWWIFHKSRAuxLklSXTB2gXaMqTbksRJ65a9GO2WLHHilqYvRrwlS5D4dqnhuEUbjizgCVWIHoP4AA4MPG/C7oqTsrgJ2bhVDNd59DjRgXcECGUpjVpk/A0JykOO3UwnAadwMsMykbT+GlkoVjaoLJAo2qMlKUhjluCvSUb2a7IPowXa5oJcHOW8csJK0HeZvbIMSkNolxq3zIN9kQU5BfaZFQvb6clvnGvC5ZRPJKi7UNkgYd+/j/1zZ14QCBV1vfqOAeLO5UmZTxcsx7z8l8D5VHZ5LshFn09llmVQmpz5pmn+KNuBg3dMb6ApBKSWcwe1/Mcp5W62mwCgjHSr/IpFrKVLLWFAgvUrFrER/3r7HeT7pzygVTX38ikPotif6vwh4uQ52EGYdJCaxMu6asg3PpsNnEDmFgqYbGDWY+OcGkgxXpVBvk/yPGUr/RqoYV6gOSxBjDVcFb5AVDy7EYcR2r5foDd3iy5yOtIk0RY5GLmnNSOowPNyUxyMqmyKtKJ4qzbwovcuhBBX1TXLRKmaExxqDZ1gVwNilqyvp+T+UKBUFUdCrSWOuOqCL1k3356CR5wRxpFQ64Yjrrrgix4eRGvyFMQPKNXTgKHWUAO6OhPx3R2VM69OkYWAbHJDB7TEEMzzVnueDTXetKxofpGRMNoAren7CzYFXHGmqyPf1bCo2dug2aNime4RHMp0S+bp6+d+4ryOchKToBCe1Bq4pgV05uzdgIP8yHutXBd51eO9uir4uxvbWXzYRkJtxwt8KDtqAoJtyRCsX5RB+OCTR+ilRX8y5oVfDYlaTaQgfi07KCXbvfgF7Tbhq5Wzy2DJtTsLlDDd14e1EOVP7rrRqbAs8MND/oiz2aubqVv+1jIyLln6UjJYE4zCiWg16YGO3ibVw5g0wRF4rMcl+PcEIVA/qxFp/XBMGlL9V6cvSxRiSBpyJ5LOH0RdfGpuTT+d7EnsphN1zT+HRxyYl8SsJtDAXPMHJMhY8AEFfb2uVUa4famM5HSeMloNCULtHiUsjjeI+6u1eMDuz6JpcWGn1lyNKaXla+zVmEDMHtDAyugFF8uxcG8IU/IcFSXZh5Dtv/j1xUW81r7oMN8q6UJTt0qt1CfseB22BT50tk+LshqWP7f/zisgXk+GFRCg7gE7udhrwtfi05pFUnvUN5c9Qb+7M09YfI0kmBpfY2hNTA5zjipGFg8K4ueEfSnQwLQcqwZtNYwskkeggZPAUMoleYd/tF9HOQlL5R8HchCt5HMwgKN7zJR4hRlZiZHp4IjwUOCpewfYKLNy9PYdO+n74S6K14JsOjhQHnRqDPYoTE5IQC4bCqwIpGvq8umhATmh0RFmkgXhA0GsnzM8KK8dLNlIj81ueoaRcw6iJlgNi1lWV30eh7iMEGa8Dg6wPiqMPSmf0lzEVKCplzM8SAjhMIB5Xp2oNBAA6YcsQ1mPOjhygq+M/9DX0HZBvn4K8vFN6rkdXEpfmR2+BRahjWpAXNzsI9OmWCv+ehMRoosFimFdY4TpvszTeHa8sEu8+pgyIuUBI6r3Oc4ZAb0i1+60Z3AirTH3nPkSpWmHxchW6ZPcdkdiEB2qeDB+yuz1i6drxu2CA3SsIcJ0ls/TsQVqT4ThojTjowaXbSUsmjaN0YT0wst1UPfOGnyp/A4jVZQ861aVAsQvdodynT4Bs1fN7W8DwbzOqVRx1TAiwZxji/TuAbhjkKKxUoz8+LrOOEgD5/UbU2CYDjVmE9RnbmO+qnmsfOWSXcBMVyzLXUTX34xW1+zogHXMDthUxK0c82kpUQf72My4YKxWVq3CNoGzVjWR1ezYX+fhlVD5zA/o1eMz2+P2OiWAD+0gK/8pDzIJ1I64cH7pvijZ7SULWYrLsI8M5ljuckL3tftZ0Uiv8uuggrk1O29Uam1QYWb8gloKvSMynGMRSKDXAgUzC+Jou58b5+X6nNtGBXO73/vJYdbu+CqxEyScVVAQ26Q725Lk+3npLq/TO8eG86RNcJif9eg6xy6uKL8knXXXMZVeDYvAzs+DJ0kMG2gklrTfPAZFNM9bbybdjgwUbQGTaw9XQFuYG5ZsgpowP+7YJR3Gj5IMd/IZhsdiK2O6HBcBZk3C7Ag0N4zjVb5D4IJMJQz4PjCcITuOzl78LI1x270PDGYYJ2k565TxKrUjIphTsmZBZVBJnSBFWKHP1i1MOK+sAASRvE6tAyvEjoc2QSd3RBXils+2XZhELp9lwjDKrsyDeRaIk8gdUeG7uWA9N3P79c3cCRPO60HOMtvDFeGHPoe0MAV4PeVRidvTWpjCpwaSWnUIHR7ciCXUiEt/R+KMzEtLeZXpADbcsLSIfW4qKIXpILoQ1zCOsA9nurBC7JJoXk7WSdwaUCFmFFQz5OjHw/AIbB/IC3537EILzUVNRuWq72AfZZ6hL2CgEB/WcxyKhG7KLlRuMM9WcrQ66xIdPwcoIcGDPMLZjpzRq4FF+RV7TQ6/GhiBH56CMUQSoGoMMq2On6XQPEGLcuTHkXI4HqFFOR6imNm+bWblbZ/OswMvGqCa/hXHkkZ4G1w8y5EciiFGi4e7gP6nq3IotsBReGZpPMtFYCbTBl6YKwkf/MqOTxLbrgBRvpUVhRSmR2iExFtyGM7wj7jEL02yoFT0m1luf9NZduCFubKO4wfrvx+K0o/JNghfmqTdcshflCejNJs8TdBOoyeVpy0RtURsi8HBK0ELlGhAInqJigM7ZSDlsqUakIpaMrpvXaAktRRU5s+W6i1AvRGDw13yAEcbzS0zO0l0uxJEGZe5v87vJekuLXBBnrP9sCeTnOWTfZGhnPOR2dkGhtnt5OxMalxBdiRc76TQa4DF+Umafo7Iwgz/ngUPcuacFrYwS5yLtXOGMy/XhtlVFhtyGJ6wRVmiXdWfcZx/XT/IcCvpFGSLcgqye1hvpNBrgEX5sWTQ0pbkDrog0ziRs+LVuILsmqS+Es9mzkWIcsYxMz7jOdPMeISbJYmchcGOJGn+4t8fNhuWwyyOUzlHSCNyBNnv6Ta1SFlkFTkjqocvyjaiu7sHHHvzM6YnbEGWaSRnMNW4ovGWiZw1ssYVZYdjN3ZGbqbp2Ai3sNBmBaiewa+BRuAoZ7Y8IiMwdKQxdDAYNn53Uki2wJF4yjvzOZOAxZg75kll3EgQZZzGL5qhShpSLXBRnnn0GJTED8KQFHKW8nMRopwbD00pbFvggjzziK5ta82Wc33dQRdlKumsKEc5KSp2gRxLpAZYnJ9u2bIY1tDiHA1ZDA0cfpYkHekELcpR0v0Zzo0Ztz8Owp2cFb2DjsGUm14Uh6iUdAkxJASDd5o+RBKr+AiPwLWM2P5ZGtcTvCDXUygNGVQ76KJMo0QazSO0IMc6b5EUki1sQZbSbvSR7vAZjB/mcib8NjgOTzmjvA2OwrOQcw3UBpcSqqwpUj/lSRGI+ihIMGyjrFZ49muV+0htIMNysPpkH9zHBPeo8sR5TBRqOWoTmgfyQvlEuT87rjagQKMyZZSseNmn+xfk267RMrWlfZ82/ow6rn1/VQ8Ms4z2zKk9Swt0ZbZV48OScEuR5VQJKaOZqVUhpehKwi0FG2F0mmaHTth60EBJzqXhlKayqZbF/oSOxRb9yrrDFsuXoMKrgqRiBrgYIH0mBJn7viTPZbHAzHNZopxSLTOGr0uVUzr58+xliTilosA57rFxqwBHcByuEuz4W2Tx7PUrPCkXiS2+iHeJNWJB6i4ni3JHABLn6Ju8AXgER+Ja5odQmjZwQsdhK3U7hbxvegzigzyyJ3Qp5xISkyjQFWNfbl4hT0eU0u5IgsSvGAgFxKggeBqDAdgFImHgVYNIB62rgSUAGIBFr4a+gQFSK85suEEaCLU4teJgw64g2+3VJDtj774UJUkeI/IkEnzl7vbnn2+/iJ5rVij+l69fhZq+qo7VqWSrCnjVxRdcCiowoc5xhSjCetUqsUSiDf53u1zNzVpVRHFEt0F+HNxfCyg09C59i8fkho3I2vY6CfbB1FE92PYsfFdluT13MLWLv2qVZ9WltupIgAfdOqLM7aLzecpYufpZBCubeeHmq/aHTSbSChWvhrosV2PCwI1aQcxPuTyLdV+IKNsKF5SBYSblriTZXZI8UkE+ryZ4f+Qg2A3aYrbqCUCrFPnZoLI8LdMwnZER6lu0vSfXGuPsrSDLYEvKJqd/s/S0IjpedSgtquNVJfdpUfwjq+a8e8Y61VT5qsJbUbzVEa8O8L+6IktQtxpEL8qAxTG6X6YsbWlSShMTMiuHlEBRGlEyyjH/0ka4f4nr7oPofJJcpiBHUVJahOpj98G8wN0CbdKShlMast8F+5Cs/TylK9y8NGFzyjEkB6cE+7BTQ9JmrCE5i9pbxYdtBFm2+pmMWQAVhR/kzAYbbAe6K6mrqApTzaHxWqEq96pFezUqcW6PmlEetPE9uTyQMT67lwl3S6YXC8cq3ih0dCll+kAQFzeusfehX+9oB6f+Bs5MQ1oxVxOyXu/1NY4SrNc5KQqlcngQHMbVrqmGXo3LEDX4r4FFO88w3aUta8m3Ytr+6EKNMAylKSJKtTDE1RmsaHQchkdmBl+eQJHgBF3mWHxGUZiAqIzm3ZZOYDqA/t3NUSTRbRV+4sL0qGC/VqgGuI5JXijbnJC9kqVPJFe2ZE/yoCRr0amGk1xNlwU+ZOOCFJytfkW6jwg/giZ5FMQKz76yCULar4JcWBWrOI5Cg8mydZlv/OmfB2G1vWJ5jgmm1/Sk2oxMdNh3u2cLFK2xcRgOoYoOlXrXKjx1dkZLG1S4kY/TRXg/LyrfjJmogcYjm2y2cXQvie4JHI/wfbRnzojSJ/1BOYj1TnXXYLtEQUYk4RVlT0q2WVqiLGOi8Apz3F/ILsqwILyClPmhKJWQsElYemHGheEV6Nu8bK0z2H8TTNc6NndIottCx+/3kjgD98HXugSXyzaTsnpGRwBqX5Y+Js9kyL5af6aaM3yH91zp3Yf7QrQ+GNKqCwduOQYj2reOfJa8yh9pI76xAVpHzj8lHLxtOa18tSGIsk+Vx+AQC+0yecFO525TRIE7xQi4fPoyWCuQLK7A2kdJ6ToGzttVKQ5Zls4L5wAszJk8+PJAd3VK5fCgkD1V1YnwcUavDBckYLLWbONBW4B7Vw5mCXR3mRJ05WCWYF0EyiPJo83LAsUYEIZdliLa7hcqSUeUpDZZqoONipStBcLs67p3uaRQiJgVRlVBp4vcFqTgwlPfr4dUz94ThEXzxHEMX3SlrMwEyHNJ9ut5YWemMR4QIEq5sn+NU+ZqwXsu28lg9odrcuAn6mWe7rdKTndhaaIEWYTJehBc9oBunJ2FElJHYZ4unI56uDKb0qw4pfmpqBe6LoUkAe9mZMmU2V7EwzXWeOW2EQUunMSPmbq0UE6WxvZbaCwvCEDfCCG3+1Ux4AKwRTlJhM7uulRbgPAemh7ykCjMxlToFq/XS3uoAteh9/hN3AOF98g4Ru99bUiMWkM87xioPpwjDg6IzA+h/mZnZJxSbYBkjH1yLIkZxZnlnX6FWhtSjBgyKbGDpl0UI2wAGkJHOMF+FcR8zJREmZkGfEr/OgMXHQQHugaGL2GMuDoMIYNpVvf9iOxagHBSh7iMmut7RGp9WEGC2Q5RM+1Awk3cqsIpbNMyO5jbZYKD0AI7X2YzNzfy6BW1qYMJptY2T8Aj10cVP6d5jEJS2R6iq+99cDDZPHhS0KeYHijcef2lRDKz7vI7xxVcRVpHOMirSBcZTDOO7vMgR5wNW4DwSToIlTh4wRzEHUh4v0vTMk4DRN2qjYh4FYGo/A1iox78bsVcuQbnwSEB8P4obDzb64zi9rJsv4w6q7QA4cOjtqUtWTR6xDHShxWJu9M4S1duZbMjqF/RY0bxESiX8SOPICKDbhsbger6hX4VhTwwQFSwVCiCZpJjvEcFyb4t2QqYwG1rJ1NlfjTw4XrZZqsBTHA7brnf3vML1jiu6PUgRdgVlAsuuS6i7M5TERC4OM8K5YG8FMrmEMfiF49HG8YeKvzAv4Mk3ESD/MQmqqiZQL6tU59OKgXd2/n0IZSNY/PhmhSUu4uq1yqHbB1gXGQ0Hy5JkFTvWP34qhTZw7uaggXCjvENXoVyyKsTG+HKqeBWI9iC29wOnlInsJVIuSVCwFgfZ/GtWSKsu9UCjnQuVNPqYQpyQzk37TATPTYd6hxrsmE2uwjnQhd6YFuI/AllYmDVC1XUOUJHMkys4hlegBc9pg+wTEKrEKlnoAj8xJ37BxkiePgPNAzGiBhucoxLGVps3H1Rr07RNkhHSGyKS0wm3FlKKMTypb23L+zaVds8M5hrG/2TMIQzi1w3fAod+rWrh6ySjMtBKMQmD7YsxC5fo2SVYESI9F1zPC/61bnJEurkQhFXQ6iyqyEJBLJlVDMNivkFBVl14F7Z5ZGnrYS5PG7DeVV6rp6V5FlJTPGIix1L+/ugiOYQu4ick5gEBfELOm/GpF61geCDXSuO7s/Z3wTwbsYbdEXbZnWs4NW5hNVgwVajbIBxH+dGahN77WK3aBwwfrc94+hBIrNzNEIm9o82p99lF2F+8NtMqa/ff099o8scu1N00cd7wzmL32U3qDv1rOupV+8BR9KSZoRtdnUWqGT/npucdWAWaO932PANdUnN38Bf7QRtHr/LrsAKQCvm97oKtKjLWAZa8JfXgR6P32VXqLs0K8r0YDDfSV/oc5c0Lxzxr04MHSa/5+6Q63oTyuR32CFa7CV1iZaEq52ix+Z32S149Kz2Xf/vdOUYKoOMJWRIzuW1ZIzZ77K7ND7CrTL9nnrKAH1J80hbxNWJpM/nd9k1WF9nx+G/0wmkRV3GvNGCvzxd9Hj8LrtC3a3n3de8ei84sZY0J7ALo2tTQS39+2727yWT8cAPQ1/1fYsi4VQMLNBnESRZTJT6Iz82UHZPqwZ+Nc6AviKRQI1+QX5OgnVCbnZlEktj0ZHR4VLb8H8Oyt2ZICrk7yQsV1sSPqQ+FeubN9aNegrm8yP3blzdVblVP7DUqrc/fTH0jz9r+ufV+yaYDp7AOq8bxUBA3QX5+ilgCXJT+i8k0CPVxpOMJWCWgUqbPMJEfvfx7v3d6h2zf8FruGMVr/PokXLu2Oz5Kf3KL55S7KqvhfGbJGzsguS8z1eOvX60j0psESRZ54+rdRKwv6Rgow6jFjZdOGXVd5QWJZ3FEln4VfrxOnWqHxQ7yYJ2QSxfgv+0TqWNgFoMS64pv7p4XsUNvpAmX1zMWj5L96TK6Zjck3UZF41N2KpxIXg10RSQFKR8FQY4lc6Tp5W7KF/7GdVKXla1mMaLUKaI4yYYfUFLnnXL38R0APjF7lCu0yc+rfJqPP/JPxT8RhB7Pt8/JoasAcjzr/l19DlZfaEa3vKQF5s4siLw666BLDIP6HP0zyj22TJbLVQSBRx3GPcxqgo/JiYihLiqrlnmEtKekvtDsYSgb0/Bo8z6C3dRtiKb3NCrP5+32vMS5SqiNXkK4geZsqp0y/wzG9f+Ml2kkpoFzIaYjmNm2y61pwzJW6Yt+/Xbmer51mZR6SXGfvZsASgIizmyKl6KkiSPEXla3d3+/PPtFyxZRXX44cfs9IN+oH/5lRcJSdL8palOCacgZZrG4S6I0DdyzdJf1Zk09JgQ2uYJ/lLZSOCuAMiqy5kQChAHL1joF9Oi4635E2J0SxPTylQgub7qKaayKOaKoLRC4W1ixsJiSKqtOkG0FOwqM5kU6GMqbumdiEmSWYhTfi9JXaeJbiIJHpP/RVUBvwSy6gS/KphzF6+O5CBBI+QubHK1IWndTyo4TsWMDMu4P61QaXn6I9kwxZtuAn473hDefvzr7Rf/3a93Xz999D++fef/9P7DV/rN17d//XDr373/n7f8lvAxiA/scc2aDHy8rDMM/SdN1c2fP2j65NfvPvhvP3/2P3/59Pn2y9f3t3czXvzrp7dffvR/efuxy/3/+cchLf/rX7/8aKqq9rb6NBv1y+1/HwB9q+rz8P6ZYv3t7ZfbGvXH25/e/vrhq//lJ/+vb3/50dcpRSDU3a+fP3/68vXO1xo0USAQqZ/+xyf/py+3/1+nsgyXQqjTUaa0pWbr2G1pzMZ79+nj50+/3P7y1X/39uvbD59+ph339o5+nozB943+l69f/bcf3v/8y0f+bnvg0QE0Fewdbbbb//HRmPu8f/vTR0P3P75/9+UT4F063qe+9fmf/8X/8vb9h8nPf3j79adPXz76/3z79ke2vz5rtWbZUXaE3WDf7Ga34Yfbn9+++xf/n99+8G9/4bPf395+fffPP376udsQUyHpxPrj1w93tG/88tP7n9m82uvCcflfWzcijVf5X+bif75767/78i+fv37y3314P6PPDQFc4MqOn6vgsPO50uplze1/eP9X/yOd6N7Tef3rp3efPjSzTEfanPmBw/76lf7x+W1Df6iTVJXdOhEK5peCjc5f7279t3cfgXxPo/zu9t3X959+GejJp4fmdeF6Df/66b/d/jI+TmgldI4u/GBTfwEbOKw+fvnv0+eaX9/5f/31/YfJi1Kln7z9yf/l3WfYOKwQ7m6/vH/7ga6JX+/efZ2sTNz+z7vP/q9vv0weU5Uw3sX9X26//u3Tl//m33398v7z59vJRaa9+n++//mvt7c+mybvbj/QrkJB3r77b4OjZXJFnHArMLZofXj/9pd3t2wlfH/X7456fzqvrzp/qkzM4LeJbN/FbGDpv/13H01/G56564vJ6u3xgkOZbsm+uqql39WWmcfPzYG4zpg0v15h1A4ncf2xSQ8lUx7ap8VL/8oAVFeLR2BYhiZSLABpZHF81GXXJciLWjYpYd9eqY2aIXicyq7BTNwLUjZFJK88qU0txzNMds2i+SlJrVsM7xnZNQn07vgTu1T9lNVKGfvwnpnin769OYQ3x4tXroql/PtLj92E2aGjtbUiVMkXvukJ32SPpnJ2cSJHdJwGpR/cRx0CRbopNxD5zNKKdpf8svjmqZssJ8druZaolsAPUVEehR7pxVzFPL3dD6b2p9VJ4NwiBEVBkvurZTg+9l0WgnuoXClB9Uz9112YR1nZ6QT/oRnjJ8WfPclcY25Y3DjZnWNz2IdVvETC/y467Mr80L9VkMBhHZQBqvwZDbMP9qkfsq3Xa5Q8TaLS53esfpby3K2vQIJWAHkOSfZazU/l52UZLdzwdKyRPCjJxyDja+/y5Q59qrXu10G+7i6KnreA7OfnEen/5b9o/VMaCfKfgpxFyi1ugjh+hao/iqd76jx4TQIZWQf7Mgq7qknl8bhcI+TE5+l9i9egwZ5Iom/cF66rIEXfpolPggfCV8wgT27YCV0Z5FtS9uWPPHamlioJ/ebP85RTQQrl7pDc90jU38kX3teMlYR+8+daP1bWmr0IiUEdmVJh3yv0+z/P0JfPhJwmvqt8To+OzdBKUa7/PHWavoCfZTPIMP/psUm7IjR55kamNLR+K5t9qlTfvgqhEYWG02r/tlxfaiZbv7/iKX8LzkxgpFeTXDagejlfipW/1d+9Ut1IYzSnfkZXR+WTcP+dWzMyucypk/ENo7Jhvymn35atoMWIzamty1t8ZdP8/mq1tjjBWePv8hZd2bAHFP6Acnxg4WG5PMU5Nfh9HN0h1vd3WqDRM9XxJ7/Xogyf44w8Nn64Cj9TFWTETxXPzhQVup0iYfFn9usN/+cSXJqDLr/67CdB1mX1P2q83/6gfAyyP/+H//jp16+ff/3q//j+y39a/Yf/+PnLp//39t1XZtb6n274yxM4VzdYNxHtGfUBd59uHTgmzbqaBLdvSbaanhmGvmGWpNv43BR75hA/q6qoGEpgMt7f+b6B3bKV0V4ZctKfBVCAEK50nqvv/40yOOwPBVkrWcDWgrNlYBIET3O13yqbiMRrhRtuBXH0jeQQPg3YfR6EZC5APw7JrCmHdo2byi+Dd9IiMvSqy6zLm8rccM1vVfkt3s12f7hpLQL3QR2QrNWnWoC9p6uHblinu0nLHcljWpz/2/1+791vMLXYpSZISFHQfqXEZL8td3/uW+JKWTFnT3R/i/+oKNtwRNWe9jqtWbaHVvKnZ4rDc7L1VzpYYXdpUSJP7P+ndWvpsyQ7g5szT7afR5gp/09rz9/ZNDW+R5k9cp/phyOc8hSVO4Xv5JbVCWol+0pPnwsXRnl4iIN8TTJm8rsPX2B3lN9PifZ06l6f7Yim3zDCZqLhVVEE63fQNKdnmwk1Xm/iYDuUXXfppVyo6icuJ+2SL1juPzXmmvzTH/70T89JzHCrUEYUWbtROXvaZ9I1nc/pV79+/Ulxf3vzTxVAs1M+OlAcwpskXR/o/FmQ8pDdvOOBTz5Xj32mI+qvvK5aEY5vuJMHRaBYGcnLl7uQ/k2hjrvwdhEyCsGr+64k2V9oATqfFypUnbH+jpQlN0aYVZqVPF5i1SyR2CGsqcEbvh/Ivj4oGxoo/Udviphfi19IsdEL7H0T5mHjwEj/yVnWe9HjhEm/as6p1oOzaDPoLodW73bXN398Ux9e+V8+ffr65oc3//7bmy+3H95+ff/fb/32T7+9+YFyePO/6Bt375mn2bv3X//Fv/v664/vP/kfP/3464fbO/r6v/47C1OepI8sy+kPfPH6Y5Xhl5bl9pmfhNJp4od//bfT13fcOp1/y2YrHsS05Vv5jn7DDk//ePwxyDK/bsSInHxt24/cl7HPj/E3VCH0w03v5ypk8uCbPDYxj0Thc6eiwYfOYgBfeoqF1x36mXvM1WN78IEBH932z0Xs83jk7McyT4eFsLCTh6JME+YieqC1UR5yloC96yU6/MbFZ6rKKZ5GubXiXvvrcB1OeY4khymP7TbPk8TGF55rwkRXkVb9R9qWVx99ZFPJ2FO9YMpjj/U9xEd+rosx9lQVMW7s17F4smMvdMP5jTw06G09/sxZhMAJ75TR2EOnEHBjT3T9oEceqtw56r7LD/muPLnNCUWtCnP5yTja7kp+g3DlQTpz+dwZ68pzTbikCvOBvIz2meYFPo/63Mtn8NHmOVaXrQfYVFwtn3ySb5bXHz5+5F/+ga7P++KH+ts/02Xjza4ssx9Wq6enp0azpKNnVRSrZtklPNgOffK0jP1Wr1nsy2jNP58v2+8qUv1Vm72TrZMOyF+Y8lCH2eGRMP+QBSWd8CtRN/+Z/cmWx9OK1xToL7xOamK0yAzxf/1RdOFqbtK+fL2lS1Yd6LeoG2Dkmq31C21GuqzFUVglPChfMtJ79zjdN0sGG1Tsnrn7zDHIsE+hgjjdnsO0p8gwTsOH4hyGPDKIXbBf17fZl34+k3CcMasnBvDPnhjH4DyjPbPrC68/WE10p8fHJQ8+fobenchGK2Qo9qyf7V7oMI7ZiJj2QjUv8Mo9eyPqLR1+/dMZ5bMHyzzYF8yV/sIrTNeou/V1fK6YXHqonml60Sj6tVs/VWtRYRDH96z466igQzncnVXz9ecH8VnegcngYw8PItfT+FTs8ce/r1n4K0lY8AXyu56HWac8bRK+o/qtRXwkZcAM3n6flVzlqqK/Xk+VdLZPqcfSnDf5UjfptSI/F+hvsyidxrfzemuBhacrqtbk4hr7yzg1LYYzjQ8k28TIjxOZD0msac+WOFzGCwmoVmFSRIV/vCYbpnwdgB20Qt+tD7Ag77PDhjAxAa8m2cEP8uTRAbxbfuMDhDyPDa152dtWI4ZJ2OB+ECYZPuj6asvPx9z4GdUspeCmeYkPHCYHfMz8JeUbdxnIWZniwxbk6iCeDcq2XPsNPtl1ElDsght2pvhVTOFz8g90WCKhn5EyQcfcZAeyQ0fdZmGOP9lwHUcGqI8/2UY6fvmjdYAPGtMBIAXUD/H7VUzozFUQWbj+/WEjDVteddBdtwRoOStaTHigM2zYpMAfGVm4xyea5fg6DcWU0bsYbBFt93TvjI6dS1ge8zQpg/sYf3bIy+t7JhCoLws3J/g9t5DQZHLmmPoSDb9uy3y/RQflxwToqI8ydAUG6qcZvr7AbpOlgNJJHGtiTOpLJRy4Kp2Yf6IrBlsdXbJsGnl5yNqwVw6apsGekb2C2s3Mvmpf+50OrK+VuAfC7F14fJowXV9thIF3j7YyM8l33xWQy3LwFdenu4sQBd0CB1uhIhwx5vPgaZf9Kbv8zsttU6bex2sFOSVn59fHBa2/q3Nl750yTaKrU2H3nerTvHfIfh0F+z0prvbr/nuHq7v67hsFc4iY+UoZlIeZxIqSWVFNfKc+Bq8baFqj1u9UxZn3SkVt3jsvBbuWnNrjmF3vMZ/katDVGYJSWTWJvU2H4XbCKfwZSHNVUVG4Ug31lQc3I2rEH+3hronuvFyLPb18RXIVd7/VF8mUCb96qzJ65G9V/5z1GmNavzaJY5NpnP9jmqTOK42ZC+RVbih7fV4benUXjN1PXnutusSCvMxMcGa8N5JwYeLbrB17lqfcnKJx3pgPdCo74GVe9qvvsSLz3p5MXOY6r9xfn907z7NM2fNeuL776z/P7yqDeeWYtvL2XsknzA69F6aPn/aLk25jBl6B1MSEC4TO81MOxzsvTDn47bww4Yyt/zyk4BNOyDrP50HCYgPNe2dm5U45Aeq8UO2YAK+AOuakY5TOG5MOHTpvTLz777wzZVt/eoGZ3c2ZadgEWz8/aXZtnmfzxawXqmE/5xUyk9MF653hF/jgnfMCG7xznmejcM7z+cwS8xE154V6RM15pRoWc96ohsWcN3gXv/LCKW1tRDeJOQlL5R8Hcri6ap3ei5mFrkL/VWUBArw4/RUmhaoH8XrmK3TlDvYzX6I6Val0vG8mvgh5J6GqYKTUmS/mvZoF4QOBMc12V7d73ReYXfzVFbD1Ci/VrBZukicfbbTpv8XepltS5uc3HYTuxa8uJaenD1k2pxeL51GbIYNp0tWp86qBe65+Zb/4LPxEtLm+nvdRq+0v+wx/s95IVKemPttFT+xXg2AbEpSHXAgi2VxViS68PWNg9LKlUxjyHNH1Yx+SBrL1lTjmMRdPy9HhELYfUapvpy0VOKJApcoCOpPva2WvaHXpM/e4Q/4IbY6ekMrZrvlYjUpYRU0BxmLMyl/1SQnA2LXQxgTxPLV9sC/9dfTY7RD1lzC+E7EFeZ/GyxRnJvnC2o5QgtLOPVGveaqKNhRAomgZy+jMlVa4FEOYM3k20/F9TKpvJ1igjGG0eg3/8fQZilhEa/IUxA/VT80nKNpTcn8oqu/5P6E4356Cx7q2+D+v4TR+wh3nz7YreZOA8egwfHIQDMKQjujK20SmnDTZRxm7IL0+nCFimD+ilKKwk5eAsBwAeLwZZhgm+Jh0C4AOupVAtNgFmgxQ3bJlwFp0B4QOe/waG5YNBR6oCQ+ZHebUR/XBdaOEWbBHR+Xw6uHVLNxW/UJhWUXWV7V8dFUVUC3aicg81gNm81cNzv20syBnrvVNRH94M06TM2nfOEfG6auJ91VA8Kk77jnwBWlO8v1j8LoJtlhTRLQGUasPIXTOqrsPtm1dUwEJ1stICqNsd/1QGUfWbsKFM44kdrSGKOh8gMgBn7KTmQM9Njiuisi5EWUr6MjJZOYsDsnVkTYJjIWbQoKacNM8EYkFrUKCivGg9o/Xj1+HoI6GS70gX4UG6RADaCwUGBoYDxiGhhajovEWmAjVxK5pWrL5PLUFx973J92cXUWZYP02BcOPysR3hZGm+FJdB5liC3AV5VGAS4RXN5Fg5dS999jr5vba3vt1rxNFOdWKKNJhwgX3dZAp1+RXUR7ncDkLR1kdXBQ7ZaoKfg2nOZ2CI7ECthjNK9kuiGsqk6e63psnm3uFEFoaBJyj04DCwuHgwUGhDmU5u6mbl6tUvomxWkfBlkUin64V9JGu+7aPvEk2iaH7SRTmk1eRPkKiPz8r3BFDWZPNZHXyDKYKAduKoDgXYoIZ8fibAm/zTpQfsrJQeHUCYWJy1VZl5E3efLBppwsx8WBiHAH4bvP7RHuWERS6i1yD55hjBwa+T7+OwD2oelkQoxMNl/XJbR3Rapem03d5PVQeSlDphDFWGE1SKBo+JHToDEACkNhqyYL508mMPhZOPC0ahGETMuzN1loAAyDJPV3YmJEX7H3uoFDcFKCX6yEIk1yFray+nA/BDR8HRsIUk98xtFpB7KPN48aiW7bVOvp5Jp8GoVHnGMI8DlVutV7tVF/O5FIjdWumRprIqXMVf7xDaX85ldN1pHmb7CG8CINaXV1dJFB1DSHN29NNwGM9vVBnHLcMYfYqjnWSRxbgdGIFnqKPn9xMm2/AGJEYyNFB9IgxsX4uYfDanmJ9PhlMjFrUg5tcT9we/thYlfPIFEObiwB02xiSgllNTDMy6ECdPG2PXKbWyhBAj8tEqE6Q/KZ01ZdBdtW6ZwLKzJnpOlI/hjQO8nzdbCoeXj22MCe6Pc3GrVRdf7L2PBd4sg7dBa57evUl2waBencHZeY6dxmp1XuQ8Y4tPRH3sCZx8NK0RPVpap3X79Zk6nfnye28y+PQ2gl3R74bhjmauPF46CzaBTuysdVV7R+jXIlHe/X9Ojx/odwzZyK6mTumTBor2WxIcW7h/cOo5jEdhWcmUbhag1nKKrclctUlm20c3YuXuXZPQmbXXILLwBQvc5kfilIJCTvYw2RYPcEO9sU5fotjVGrxqKI3CsL/VJrcCqNHTNfev3g5MfoyC+HPLdbpn4f72a9XZ22t+4RLdz+TUWZUwYal8WUjq/H/afJ3ZJl//O2YuAIfeG6tz4LFZnvRKQGMyvc56FVQZxyZ0yXHgMl+xzLkrHl+qQuqzwxIdpbUai4Yy9pvgR87KPzwh6kk54m+5IJDugNzqlgFG3aEpnBdcAYKf5d8KzL+h3IpTtb1tzklhX0ZXQo9dx3o2i3xGMLJDK1ZioP1OqeaCJ3Qw91oQILJcDP4PNPW4H/wqXzUuu3SmxOl8TSyK6ot15evSmLyhWSbKdwFN39Z1U63PsttHpNa++GxfzrPjTnlThRIn5smsfWgoMgqVZ3CU9VNkz30hiAJprVMkt16UEBkrXBVc8l9UEThuNTzZ7EE090VM91cT5TdPC4ufptdFbnNxMU02ZSuCmseFBfJhgVfaK/KPD4pLjTXdaXxeLgmtvWsuOD2QLwquf2wuGg6Dq9KZHuHaYKqJqu9yC4be1x6s7rj7ORtUpgvWjF17biKVgdqm7ouX8OD0KoutS9E67j+ctXv572ek7oAnegkczZZl5Hm06lez4L9vK3iIAKsGKf3q3oF9dw2zqxXT9prQAqFTNbZ+28XZZ7ut0p1R6+wM3MYzvBiBStRjcX3d0qcbre0u7A2YkcbQvSaROI7FgJ3qnJcQdFVc8sVr+cX5WL8/gtv06nyAfwyuJPVsWB5P6EjBfRuc4o7n/wRobavhL38Us7fFnUh2FmvUrkW0U0a3UvCinEx5NTFN6tZL4hZssiAFudCnKAJOBctGKa8f6B7u/AlBLZmBdKaNOAg3LywOizbj98rTwWCvw97k8UsumQgeP1t0JtsPgAXt9lBQd5lob/i4AVYXdWdBqzLzbq66L0KVjW6CHPVrubtRl1iN3cXwyJcRMmDJ0WkAmeewfRePh621QdCF+PrT4Rav+yDJOLhV5OoYA6N06/1xjDL+PFirN3LMO1dEgiA3z2Aq6Z9xQQCOGph7HIYoOn3cDoa2Hbyuegg1vFEsb58F5jARhBhWHEMXsDYu/NLMSkc4uCbx9t/blbPFLpZrx9PY891IUWzjQdt/kboEqTuokOui0Bhub7wUR9JHm1eZHGu0VFx4WBjAxKkg11F3afKI08fgMqVQx7P0jAJz+PJriaurWj+nAuMYVy6kd0yz4PKd0McL9cNnxIMm1gtAMjjhUuhPJCXQtkc4lgcYE5LNh/iqCnWt3Xq06m5KFlYkohttSCMLgNCGLavTPgWWjlk6wtmz8NgcVytONcPAqrLtypZlh+zbFn0A/2La0ar+8Nm0zLMrj4qVwPqQEAvBZCehVf5FDQRjqsfQbhcpfE5r+rfAhzrRDdHa8KY/jOO0zGjQSDYBWblLsrXLGEXnc7qMEunLUv9eVxLmA6RR2M5GKZjFPsx69ZZGE90rr7YWlOAmEOXPRatcDoK1URGb/uno7Brlku7qclIYZCQOBZvKhYDTBRiF9D/dBUHJ0vjsV3rDCTCDHCuzpqTsKroSqIo4+r/dAyeuETRb8Yio89AYjVDd/d/p6td48J1MZWMGPQmTxMW3AgXnEVL4si1wyA6ONWXSM7SC8oQUBRjChAQ8NlSPSREnKaimgwLdReNBuGfDlbm/jq/Fx7Llw7SZ4AIr7HrnfCkS8L1WNazORjiDU3Cv2fBqGn9DJgxC67pEPsyTzPhYXrpoH4yyFZ8Wd09rMduGqZjsOi0GCMnToQ7/THqKMqynIxdzM1AsIQhKjW+3r6gaPB7utwUKdv4CFf4PqKrwsOTKEwaCVd1Npp3bDrE2Nn2DISw0MZ842ahCPcbBuIIg9QHxFg4KCv1EYy9IQxGtwKaoYpXd+V37tcGYqJoVDPEKF0e0WGx1mzhfVMuvoiz4OAIGLplI6CM5a2dg2GJj3QEBb1gAV65LT0GEN+IFoeoFFdAOV6aPkQozMqIrVeiSOUuJ8EFX8/pQFGCgHI5ueRkGIxdGcOg23Ph7ljjCLdUhVOAlWQ6gyKchDEUsTOLE0Kzh2bZ2XyyZ6f2YKXnHLXeVT+QF/pKlF+M/g6HL1726f4Frqe3gFnjlNG+Ck5diEw4A6CsGtaEL8kC42sAmC7zSVRG4ynA5oBezBI8D0hku9MCmhLeH4THnf8L3Mbug6M3el8AauNTxBysU7VwxM4NW0Ciun4LqiB13WFgRd9Q6rso88NogrM5QFgz68VcLqNAjVvbeL6W66/G0XZ/7V72EkB12+VfMe+4DsOvuy4Z102FSNLZK+k5gp8Hs88xhlFozTwGRTSa4Os63N5PDuB6HU+5c/3VS2k+Jr7tP+XBmL/7LAho8UGL1+nt9p0CtBRtED9KMnhbdpEERxwJsyPGhcxXE3HE+nh9ku5n6aiVzlWMOEnnH2E2LydryB1U622RTppkBVDLaiOArhHaAPmlyGuTEKgSMxqQ5CpAFqxZchjw6w/CI4JCiDRj9gAyHzm+3qhcwHmmexIKBSmCJkVSGEfj0YgnAYkSYQ8JN2rOkkbGpb8jMbtch8LwA6yqRgQQKg9BBCrMvFLkffpZM4Sn7RMSs7GEopzO4Sb2lVZo4WMijYuRhccQLgYRvvLSPEkshF6f60SxBdlykz0eEPQxIk+ru9uff779Uv81lcgVGP/L169IjDhUxSoJosanlrUxu+4pk/i3N//GfkvXh5j89uaH3978KcvTv5Ow/OHjR/7lH56TeF/8UH/7599+++3NriyzH1arp6enm8qu8YaumLQDrj5XD90QtnVgT/6hPp7hr9F9XvVltOafD+FNJfemIOUhuzlmQ7vjH5toEcru6WYbhvzNbJ10oP7y22/7P/zhT3wTx5OL/yELSjZH8adu/jP7c8Ue+tOqV6y/8Iqo6dGCM8T/9cd/Z3WTpI9kTb/aBHFBTg/dPvOdYkF/+dd/O319x01+j99+FzX5jiswNcZn2tX/yg5c/2+Nwmu0DghBeyYLxFX836qEV+X/Bt3ytzfsrmBL9qubIg5ZyLeSrG7CPGwOfOk/v6OJ9RA2779CVf/bmz++CdMsIuufopgUb35486//zta1OnRl/Rh9rwb7HJQ7Xl/HZON+bWnTOUxP82gbUVX0+Dj/tr63o19of+QIJV1O6CfP9VzDs1Sbt/ws4d0kY/4jbRERJprh2JZtqO58Jp3IFlxvESGieKpmeLZlAph0U6aJsHB1W9Mtz3Xmk+jGLBfpHIalq57jWfM5hIeipP1hIFr6zMbQXNfQPdvzwBy6Qa2FGWmeRf9zVNMAd1T6QBMNU2C8mIZjOpan6WAelVMWD6JJRKiYqmZbhgNpo5oJDyBd58UQIGJbjqc59A94ldSukH4c7R/4hlFoKnE0z1A1TVPBhOJouysrNiJEdNV2TM/V5tZMUy0sIqwQATq9W55juPbcqjht1/x39BugdFv1VN10Zs/p+8fE8GsdV2i0eqpjWq6lA0Zrta6xzKIiQ0PXVV03jLnVv06Cdf4oItkwNTomDW3ufNlkPsyPMatEBqLr6jrtg/Nrv5usR2SWtB1Dt3R7bj20TzuFZgDXo6uFagNW87PM2iIdUdVMi/4HmKPP8l4LaXmOoztU+wUMyF7eM6F5wXZVy3Y1R5tPIw+iuDp+zspIhIRje3ReNlSARnOfBvma25vkaSzEgc4RrkpHyEwOLMY4/SkjOYuLJjY+TaY/6IBa6OeKF1ooXd2lSoxuzqeRPOuWv4mDYucXu0O5Tp/29eZMaCNiMTazNYfWIBEZH5ZmqZ5FNwFC46Mzh/NmEuBk0X0R3ZwZgh1lJzqDWaZn0p6iAXpKq2oCQbXOpsNGo9rVTBL3ZX1rxtJD+OEGuJiwDZBNtcr5VdBK5iZUAbpqaqY9X69l47W6YxKTbxsO3fE4NmAda+TXvVKIhma4Bl1SvbktcZacXYyGp2qObdjTjyymnFcClAu627IsOjDm0jguqc2eo5Wcb25dOLZpaLYzfVlvkaDLahyFVawdZj4Im7wdzdId1XEnj42GwZevt3S3V996FUCVn+45dNeeru+2in+8cfNpHQRxCu2ODtvy0e44eVS0OLTXipAZnRSgfuAZtAlU2568821RqCLF1LmQgFWguralWp46WX8YlQ8bBTZdrS3HnD4/tuQfj3MrCrCOqHlUpaMTwvQV4hIDSCXoqmMaJl0lJ2sKQwx4R4y4cV8IrQrT9RxX86arTqNEKr32RAfWOSy6WFCN34R0zst8YPOlQ3V/1VEB7RT1tAm//gk4ak3aZyzVcAANdcakzIN9wY2+RDhpjudRpducvj9rtVU/jTN8QtFUjS6qOmQwRzx8Ckbz0Dld03VaGVASJ1cmcTKmrdKNs+ZAprfTPiQihLiqrlmmn+1e/ILE7FoW1kKe7pieMf3q7Bqh6q6myrUGYkT7re7QJXD2NMPO/ekWKYrJTbyGzfxsh0aXoLmSm4P/6pqqzrbnr6MiC8pwB9QGbKqR6Zo6f/BcZQNqFsM2Tc/R7dkdpaZTb1qwaod2Etd29OlXBNPpQKrHtDSN6g3ObP25psMy6mFVjat6tq7bBjYXmNageo6me9b8bU0TP7ybRhyoLLieoTq6ac3uLmymPx2ZgmYV1dM8TzfP15/GYqgvu2+ueYzj/CPf5azuqpiQH1hIyNufvhj6x581/fOqMi1i0T/z8pD5ZJMberLV9AzWcrat0yndcc/3QpJ4c+NTUdqap9u2Y7rWueaDTPt9k5XhSNgw9I2m6uY21nQLvAPUdJNuPs5XP+n0/SBMMqCORbVfRzPV80G+AOt1CDuZNnTD1V33fJpcgPPGz+j2B2j7pTs2XWwGDgmWIZ7m0FMmundUbdc0zk945DMPkwPQXscxbNewzvWeBTjnLyk/dQdOJpbmOSo7z3kd7qe4GrMva2idm87r1HkB3XN7pqHatqm9Bmt2/nkKhDL7JMWxLDoqpWsoQ8STgJIvwjyivQVoZMjstSzbkK6oDNPPyT+g14F0l+u4zoB1h3ziBDgdUtaubtANxqtoKKRMYF3EMk2NTeSvQXqTHcgOqFdZumNqtv4aetU2C3OYZqV5hmYyQ53XoR0Bp0HdUW06Dw6Y9y/D2ocp3wZddyzNHrg+lU870oE9xKBdxPCcAbvwBUivAxhrR2fznjNwiCCfdExXGtgc4qqsh7xGRTPOfgib+qhSYtmmNXCItQBvQnXAAniNb9q2pdv6ayw0NW8WTBi6s3RNRxtwkliOO7S7mKqq27b3Ksp3w70ogQuPRveX9M/X6TMCG0xXszzVUgfuBJYgzrzGYFt603E93Rsww5NPOymAa4+n6Z5uaK+xycnCPbBna1QV9HTnVUZlBrwrUGin9mxDNQf8XxZhDZ0DFY3qJqanDtzlLsObpVqkgqDmX6ZuuobjvEat58DdsKvbKjNdfA0tJU+Tdnr1mdOJ6xiqpg/YhyxAvAxhcyC3TzOZSdQrsfaBxKlKZequbr7KCRsnnhPgDE73w45nqQMuN/KZF8BRqVFlyjRsqpq8Amm4OmWork2796uRhvduje7UmNXmazDP92Dzd6p1q56tvUaFcwtI2LWlpqmmq3uvsUw+Qk9OFEt3XVUbiFexDGk/zYCnJ5qrq5oz6LMjnzpzmAT7cBuGZ7sD9lHL0KabBrAWa6mWrWkDzqayqCe1/wDQWZjZxhnecsYP55YysGMHl41KDGWqMqbj4fuYO0yZJhFUw9N0OtrsIQ9KQVZkv46C/f6UvWd2K5uq5QzZsQkTO8AutRzbcVXVxriv6DVgURDg6kRXVTr1MB9thFW1y6oTT3fuhZSrGS4LvIJNqijzCKyAmIZhMAsN9AYs4gh6FmmouutRzRl9VmDuggegxZNu6LZuaRZe87HonaeeDnSWYgqNZlgIm7ouq7pTwVh5pmPquoZxZdxj9VIwq2CgV5WtMj0K43Cnx4p3dVBV6aqjqrpn6gh725pUmaZxuAuiI70q6ByIH21Gx7KcAV9EcXb1mKxD4uVkG0FnVlOlDF2Mo9LLJIHuNnQ1snXHxRuiZ/S2YehnOakzgMB8GVSHziKajnFpeJ+mZZwyS/letI/eR+Ds4jrMP9PFsMzrMI26MQ6Apt90NHuGg7E1vkSOzs9pHmxhJBXHsA1bMzBOXnsk227orYYGDWtHY8GPPAwLnoGq5IkNwhQ4XBRNN02Trbxy2J16Iajq2K5Ktw2MVeViL8yCvICGZbRs1TNM9PlmbKCAzrls1fBsQ0NQjgc45qQgpQ83mdUs0/IGXBRnc3v38e793epdmpPj9j5MiqjKpRZBIwlo7MxKszWM2htlWAuH7hNt5ttoYOipAwzLb01eN+j5meU5zAod4RBqtAK3wAN3z7YsWzcG4ragcGNBBMPEhHpbs8iVFoZh3wC3JDv4QZ48OkBl1aMLh4YyKqoEeCsebLFR9o+xJ2FbJM1wNdUZCrInxq5WVE/sQJdTnmOppusgVB1dtfgpZytmy4njWRgX4DEii5zomAbCIjyRLgv1CPSK0hzXoYsdwpCZyBVu/G+rqut5JsZtyESuLPIbUIdVPdP1LHW5PhBDuZqOq1t0+CPsXCZS3T+Cj+gdU7UsC8U8aojscTLthVEtNJhnPlPGDRRfhIlsWVBLIFlDo1MW7QrLkeWBFYFsLc01TbqNWIxsLECW3StatmHZA2F6ZPHlgwwaOMewcEyxG65NCKaGaPMZWpuaa5h0KUBQQq8xrFQXWEWa3CZSx3AOvEqTRR2PysR3Yee9nuVqjj0QfQafKTedhkWFYGG3XBNzhhpnWUBpanR/ZLp01l+iMh/BtWnZtqN7Fsa15BnLes0/jnKYCmVqlo6q7Y3xq8c47M7Stti+DmPjNEIzGhrkIO1JZ16/DlX2EU7Qr9apGFeNdk5L1ZehCnbmUNgZoaVi3Ehcb3w4S6oo0anTxTBJvV6XYONCzdGoPqdRRWkBmo/g2qTqkU43dybmacSlQQT1lNfptsMwMHwvG5ZnEaD5akT/VmrzGFjIU0NzdNuSS5TVa4sopEodFhrQHcqdJIEnhSrTMI2BPZQqcvz4AZ3qLoh5ozPvfJAKR+d0zdM0Ca3dULsPCqLkhD4WkgQaCNJwTc9Rh+J2YtFcR8F2T4c5dJNmOh6dgnQMk8ARhiS5J7mS7WAWJJpF1xuT9kLEabJHkMddL24ggfEUOoW7DtXSBwJ+Y9HLg/06he1w2UGM7aE4+4+Qq8IaVl/CRoitO7ZpDkRAxqDI10GSR4wt/wtqQO/qtq0bFuIOvMcyTPOSPCdGe0BDuNosNYThDmSTwWLK/t4Ba9LVVYuuJ5i7nB67oIBtExXNZhtZuluQs9oxbqc7fEXMPkPRWFB12zMHsifJJKsEGTC4Isv/peu2h7nFGSdMCAWD9gNH01gXlaNZcKKHsgSbHBgmD3UtsR7BEZNcg67UloN5mtqjRjaJoftJFObA7Yyu2jpdbVDM68Y4Jvrzs8Jtc5Q12YA9yVVmIeFhXqieEa3SLcJTdTl0j+2xkNoy1xqgtb2nGyxovxy1llHjk2J+yMpC4d0SOi+qNt20DgRIx+IZkzXQoNdwXdVRMVwDRqjxgSyyl9YsWncu3U7LWwYrjiwjEngk2zyttux6hFnE2Lpneiim7yPcmt8VoZzglmbonmcOpFLF4lnvsoCLsmrajqYOJOZDo9esJ7BmpnsC1cYwGbu4xwKeMukaXetQDKFH2PFNqtJJC68wxqRQNGiL25bpOCrm4e100tC1xjINRzdVzHvk66Sh12FUxbUldthOUl+2lm/zyutgl6ZAiz12luawyPdSdHPukd7c2/a+hjr/6SqbWTGidYzxPa9rcDwATXUdlrwFI/5tjy7LFtK+h6CfofnFVNtlmbTkcWyO9hlH0DRAl1HXcB0Tf77N6HgvN70+Wn0JtiCyTR3Ff2KYard71lShm1/HNTXMDUcnh1lTq50vYbXK8qGoBqoN2XWqIvZPhuWyDPKIvWACXzZXFSrUUo/qW7puqZhKzRDnqEea9uBHKgc4vzqqaRg2pgFvl3M92rpdGLjSaiwUAkaAhulURcx7WPgxx3QxrZCGCEcIlatrhua5tuUi2p1V0V5aXvgs9otApmMWd5uqWpj7wUGKFCUkReFTZTYCGibQJUGzbUPDiEbR49pEpWhVJ2w0ubTJTRvz5mOQYa82IVxNl/ZMTcMI5XekeswLf4rH0HwD6550vdINEyNOxBSOfKXi8SghZG2PeW1YS1UoJytQtZpnqioLDoJ41HLGN+oRBltJUs3VUDHvQ1pUj2Fyjn0VdoJqMp841BPUM5KRKEtPY16sJkYg/YZkZbjQ0wCrL9kpG6xz0lXJU3FX+Qs8RTYBzHfZo/OUhnkTdplr60gINFGxkyvdw7Qzn8rX59KAFlb8ypFl7UQ8EugSr2eC6ssgi2CWGY7BMmhhRHyYwFJEP1V0VTU0w9E9xDXgOtd+EleoSSWLoozpbnaZueg5rOl5nmWjZEeYSxjclR2N2UDpmFZvkzlXJ/Q+8FqBncc6Ftvdvh512OWCq7qarWuYvkqTiTezM/Amx9A0XUdJONAwP6xJHLw0C0r1Cej3q9F5GdN6eIgaj0ZhJzyUxx1khfNol9V1zLuwmmbd6HUNgtrXMg1DZ9fH4uRIss4fV+skYH9x22v+T6gBu2N7lo7hpNLhxaqs5gUbD66jO3Q7iGF4VBFrhdAk4HhZmmqx2LU2Rsixitb+MTE4KfYPpvMzK3Bo7HiWbcXDa8sON9iOiWVdRNiGDNWVyHzLMqTonodhzT9EDbxZt+niZXooKctHePmbOCig4cR1kwWyszE03iF6LEoNLMCZbpqei7J4tnixubU9KhvPpjjaP0D3u6bHkjsYGIdyQ0xPDQxygtDpKu85GDbHQ+R488JOCdilJt0C4K0GnFkc3bP/5+TefTS55hFA6k1zbBbhDIMc41SZxfrhLoLdrdu2aqgoMc26fKA5ZHTNqvKa4BPisf0C4IJpq66rWx6GO82JFztnFKgsflxrmCh7805liUSid1j2C9PFCAHW4XQPjGKuaJppUFVHw7gc7HYpEStg3aWNZ+soSkWLUx4km8MeurGkSo5t2iZGFMEOq1oi0Kjb1V1mM42iGnaaLwe7Mnl0m6uaGDHCzyiJ6aoW7VZ03+GhaDdtZvlLVsIMtl2Pqs+uh+EuOUBJZFJXaN9SNcfQcHToFjd4pD9HZ0aDroHNCJyfXdFsw3Vdy8WwBuhQgufW1qj+ThUXB+Pov0MJmiZWcZgnmeFo2HVECQn1cNej+rDmoq8z4CyvtmfbFpvSsRc+4IijjWaYqoeRja7LB55t09AtyzM8D1urq0xaoE5fdC/KrBqx66m2sxE6ENcNkzaggRHkp8NNIEW35qiux+IeYs9Q8CBD7HyNpafD7lZw63iTJY1ACRRbEapCd/DtFOzoQPccxzBcE01VaRgxVROWW4MtvCzYCTajSp+DcPIMzXZUE8MKo0OJAJvN8zRTZXExkflwjQlo/E23UaqJ4bTUYcQVJggj17Wpnquj9yKmLgFD+DjM0xnDS6JDiKklwKHPTBwcDSMBYodRDuzVdAunq1SrxAhF2yUENbvka5rjeSZGYMIOpVoxgZkqmbqt6zqGtUeHk4DBJ7u6NVhnQqYEj8vqWLbpGDqeklszAjvy2SyDn6ZjJAgrSHjIo/KlzlWZpXsqgicwuyfrMi784pBlaV6uqrAR/My1+SkIQxKTyosSeDjl2QY7P3/lgqTJPsqYw/UemnjFtU064xg4RrXzC5IVgXhrsINeutvFMVWbWIYm4WD1NdD4XjcMk1X/wrzrE7QAmpZOp6NYdy0c76sZvJvvwhC6aBimoaqqiWL6NZF4k1ax7iiQ/m2ojuWoSKHKZ9CmHcQPgJYmiuYZVNszLQfFmHgGa9o7wKwNzTGo0owTHWMO5yQIBaraMm3bwEllNK9f7wINTJvOInSzhJGNeS5n3bLhlW14zGEWJZHaXN6WpoN5e5ZBWdPVfmHaW4HRqGiq69HJz8HxUpk3YTPN5DGID9BgSqZlaapu45ijj1BnHOvcY0en2uNX/oYE5SEHpyTVDVulOxqZ4/Myf4F7dsV0HV03cJyup5MvSHPl7a9JRvZrsg/BOWE9ZuTn4PjiTCtCrRdWduwJfE+hquxQxcOxsp5e+zX9Mg/2RRbk9EGf2USwbQWsCSxDY9MPTsBkoXLAg7rpzAWVrrI4cdOuF+IY7OE0jsHO85qu647GYtC/GneBMP9MA1Y9wzJxwulNpz82C0Ez+9gGVeIXWsZa29PWNARK9uOxvZ4mVXUYqPyBwdt0pSjbQY8Wmeu7t/QwGC/KDmo9rKssIIJpSD0AnFUUuvGCNYmn6g4dGkstDtdLEpBgDby34takdNsrXpQ8WEcp/TOKfXZeXDvUsM9g00TDoesARviUcW5+sgFm7GJZRGlPcBG0tAv0Krtcn+R5ypakNTjAq2foHgtNJ7WlBbQVytCj2z1XxYifcIGh4NZI001HcxyENbHHMauT4KzuY1J9S/8BtEzTPU13UCJojpGMCCGuqmuWWf14+gxtfF2na4OF4XI1xvkpuT8U1ff8n8BDILozYzcOEiv321PwWPcB/k+YDa7hsnBJDsJyO8aziNbkKYgfqp+aT8BQqqbjanQ2lTDZ76JsRTa5oVd/Pm+15+pX9otfZCSMNkA7NE+1mL8bhi9Nj3VwKFOKxxyQ+Hc5iUlQkOPnpig6c0tqfgW5J7GF1mHasoz5Ij5QJtXnQ9mZJ5iSM/S9X5RB+OCTR/AhBNX+XY8qD/iNAilOtnuh27KYigNazzJ3QMfTJaw4VWmyQKHiavlFa4x0SpQFPtVUH6GLOx3YLAkVhgXZpFIwuqeP1WiBaciOZdLad9Wl6v9Y0QKkdcf0mMuhtBEwpbZhSrWmmipOxvtZtV0prkLMLY3SdjFy/YH6CWj5clTdNlE8T67NlN0YpVUa9878cvY7zEdZNUzmEYVwHSqhRDDVmG7SDcty5K0ALc5l1CtEGQEPDy26k8PxdgSRBl5f6AZzW8NIdHONdcCOb6LHLvP6S2AIV1vX6WqlvTZ5UNVbuq17ho3hQzxMPkzJc1RQcSwo8fk21j+E7UeUejMLMr10NMdQVQzrF8yiwLRPi27LTRcjU8D1stTHNK2vwLeQLNqHhhFyoWKdBGF9Wng46cX033TjtQ8S4AbdNm22f5TNEXjMYdmWrZoY0ZZP9KL9OsrpO8o/DuQADLFkarap2yreqTAjFrO1WmEXArDdjcZc1i0VbZR0OCnwiO4s6ZPnuiwPJyY1RircRTEsZ5tjm5ZnaxgG1D1KdP4I9jBSGgtBorHoStisNvRrkbxizJbSMzGMibq8hFKdeQbt87qH4TbXZZUF4QMRqi/KS1M9FSUGb4/bDhbej8WFVm3Vw+/xAsYhumayuFi43eoQlxF4GmVhnKgCiLhnaKqp4rUn5VOaQ8+nVZP2eBfvto9xK8IAZuTm0s7keDbugnPIMpFFUNMNS7MMR4fvvXdBvn4KcrK6T+m/GkcL/kEgD4fhGZ5m6AJd/RIvJihPY7jvKEvT51iqLhCsqMevNmPt8APGkqAThOmIRAW/RA18JmJYLDuUJ7ArOdKqbSwqv6RD5Ynkp8yoonhKm5YOU6iPqep6Du15CF3vMtG6XhlR2OCltanZLKEOGtPkWbeqaIN+sTuU6/Rpf3SdOv+pcnUc+RHqY6XSVVfAoWNKiRofn7klgrSSaVomayVwgdgxzarcRXTsZZTbS+NWVd0q5i8rqF+Y5lB13jJNATuiq9ygrl+mppoai4QhkRrcvk8zVc90dEOgm06k5z/lASxhpGOaKp3EBPSy6xTTfVGyA0TmhA1NGEh1Wk8T8Cq6yrLc5XRfAs0NYlgu3cjpAtn2rhJstDqY2SxVwC1V5N58Mj9+YAwcL3RBtXRLIFTSdZZFACeoUIamodoi2sn1eTqOtnsBNw1NV1lgJ4ktfb/36a4LGj3QoJOiJ7H+7oOC2CbPqJzvodG4Nc9wDdcSCfpynSht54NI4EpK0PJsET+KqRyTFHbyZlAtTbOkri4nhn4ePMGuyl2D2ftK1G+6JGnffAyKCGj8Rych03Y9ljNxGbUCeDjtuLbqaQJGfxMUC7AnoWvxqFcC5wbz1B4/SjLoVOQ6pk2XHYFwL3O5ikydmmo5ms7OZeTRJWF2JAl3Q2ZRrV3XFjDwnEhUZLCb7HzZNGQqHIQdImUvfpbGsCY3bcOSqrTFSVqC/bUNqnDI3Dgka+bQA53KLde2bEPAp3YKP/g07tHlWzWokiGRX1YIxV5nSTVUy5Z5PMEoci8dYFx/XVctVRcwWZjEMIffq9kaM2wRSNcziWCZB2CzD4cqkoZpCUStvr41DNbgNDR0IXHo3lUku8t1fg9iK7PuUp3HNgR8fqdQBM81VGPUbMtxBfyqJ/B7yqMSut3SVMMWuXqefDghqIFpbM3TRcyVrzLNWYC3uPR3JM4INHg4C9LpWKrMBi+K2OcmNkJMmcuJq6kyV2lGNIwj+LGP5bmeSXdckisziYAx9TWbHdTbkquQftYMMZVbMzw6URq2zLPSE9UH8gJ0V7V0x2YptGVO53SUN3k5qr4Jc0Rnroq6ZUlgGu3D+LAmx88B2ENZNamaZtgCPtTTSeYRbL+g6bZhqqYURe2MZLEH5hCmLB3TsC1TwlgfYimwpDODJEd3PVWC2tanWp1LA/c4nsPmdwm7sDOW/KQSOCPR2YhtcyRMnGc0D1HMjEw20Cw4umrbqmvKuHDvcw2DhMQxcMhbDt2Be4vMnewSHnjlZNNmN40lBny4C+h/ugp06TaZzfQSdclpZmkMTBqtu/T/qA6yRPfc0Tf9yvYIfCGh2R7d/S4w8GtzDNj85NJZ1HaWmEZDsKmlbVrMPUPALG86SZ6JStFvgH4krmuzyB7aEuOJd08/WP/9UJR+TLZB+CKSxU6zLJ0lNJZhOTSJ+yZPE4FzY0d3PJbobgFttUufbQk496ocwCsiuud3RTLPC5AvDuwYgJQiBaC7Bdt2dU2Xsdu+XAS6cwTuajXP0g2RPMpAxs+W6sFWa7qu6CbtLIsxho9H12JbM00gn9ocri1zOtgBoU01C0+VcatzxrbM/XV+D0wpptuaaVjqEl1AwBHP8VR2NyGQj2kGS+BpEfO+cSnJBRaM9Q64f9Rsx3IpxQUGEQnXO6CPqq57mqaZy5AET0ieR2tSFQn/MYPm37PgAery6xmew2KqL8ETastk6aZr2SJZRaeTrIwx4LafDsvIusAiD78PNxzd1A1jCd11CzzS8DzdpdrHEvW4e1hvgGcENrOWVgXCKk4nyRKZgJdxi262HM1YYq8VJ8D1UXeZOZghw4qkz7HJTCFy5OKZTKFXZdg1ndGFmf7S9cczHMtYhKEFNVU0DJZQe4FdXEKSNH/x7w+bDQvqHMcp7HyIhcdg2VMW6Kd7ukkuUuayD71TM1jkDNvQF1g39xHdaj7A7L8VV2O5nZ0llOM0AgbWMFjWGU0gP9FkihkwqzibQ23TFgmONJ0jzExL0VXbcNh59RL1+BAWGix4n8K2GHTgLFOVYQGcP13b8kyHbtqWYekA7bY8ugrprkA+xuksGx89YOd0VLrPEIltNZsp/BSJZQ7WDZHQBvPJcs896B2Vo6uqpy6w1rNrP7r2AQcVixvG/F2XIJpHjxSbp2otwKH9NUfVmff6Anwb503QCqprVB01BKIQTuaZR3QNXWs27Jaa6k2u6tKRJZD4cTpV4AkTXUhdFpJyiUNPlo8SGryNnddpjkAsqzksqbILPEE2PHY2u8T1AaVpACcmXaVLk2MuoJNUWTFhrgwGC6lrC0Qjn84SehdnsZgLugzf4gGKfhiEO6B9nK4ZjkOVZRlenINUuXVHcYhKcDB6lbnb2O4S5w6ccZo+RFBDY9cwXXOxyi0jtpeHUnV125Pi1NmnegrEAeyyJktjLsOr84xplEBpahrto6ZhLGHJW3MALvOqabuWQMz1yTTBdgKK5ngW3eKZMpwLhlj6YQ7chVBlhKUYEgijN5codLzbluU6mowoIsNEC9hdkqlqnqdbAvHzr/Kkm46VkKWZYzqu4wqkvZhBsTG6YSmGfLIP7mMCO29U2HkoO29cpGYb2rUdzgN5oa9EuUDKObr5UumcoMnUVkf5Fy/7dP8CvIpSNJX+z2ZbF7nUBW3oLYP578mcylr1y7iW0b7Ko1nA1UPNZZdSnmMvMxob2llOVYUygqZY0nTPVV3dkOHReYE1G4Zrws+IoPoD1cfp7Od5msRTlxbzyqIZqOkYlqm7lkzFscMUfPlr6aZjWDJv01s8uwmzQRtyx7boTkdGaLxLfKn457JAmDCYrS+7c30V+ghD0PVUT/NMmcZLFwogOvN5LLyHJdMAtEWeMs6BnpmWaemezOu6Fk0Ry3XXMQxdE0k6Poep2H2Y5rAo9nTJXqb1C1L3XqDjDp0q2KZpmZotom/gKc1w6YxsmLL1y4ZpmR+gCTI1utLxkJvLqA8iGa5pZ1XpSiHxCKJF9DGID+CNkWa6VHvAvF+kk/y+3PAI4FFK25sEiV99Bwyz6lmqblio1ss1RxbTu88ReEJC98amiXnOXFMUqjmT7tlNz8DctndpgXRrU7cNzcF0vC3IdkvyVfFSlCR5jMjT6u72559vv9R/+V++foWlV1VdSzXothZxq3WFK1jhoP/zBHIHgeoUtn01XeatKHpXXERxRFH9OLgv2Af6F4+e2xhX1vk4eVj+ysISFCrbtl2LakmC+vJ8sjB9zqULuaELpIK/zLY2WG3YVqqnUmdyqn6EnnIZLq1qkSR5s5hXHwWy01HGnm2y+9BFCVcf4fHADYeZ6NmiUd9GWfNk7j6v1urfAlVMVVLLYjlawVyzJmXmt2h7T8gqyLLVJg8SwrJDNUkoq998+pt//K054YBlyGAZQemeSiBlE5h3UQYsfMM9TF/QmYsld854DeoxIbCsFQoL0mVqtsjWULirAM9DbU+llf4aXYUPT+AsYtuWy7xxX6O66fJ4H0ADc1qGa3psC7kIc7LfBfuQrP08pdMmMJkIC/Du0NoW0JfmcN6HndoGziR0jWEWtgL3QZc51zmFuZu2wvciTHWqi1CFeOTfAucTFq7MNlWBzLM47GGHpBZPzycQ2OYye64BBBuF9hSlTB8IcO4zNZdZN4ukyhygWaknJDzkEd/DVP9QgvU6J0WhVNZvoGHIgiQwIx3cqWOYL8ykWfNcmwXJwCdIvhUZ/0NpHgF2TVd1VU/gOGICQwKNWGcbquMKHZZMYMeHkcK+jMoIeGhn0a0S1eFx25kkuq2u6sTKCl231jEVr2xzQvZKxjNUH0VBtTTHZgmqNVyFviLO/1QE1HbFtT3N0V2BkJ/j7AqSR0Gs8EDOmyCkHSDIoWsTHUPMakHgEHycJ5vS+RaC/nmALf0a3Vx6nieSjfF696wvFKExOxzPQNdNhhsaen1guHQbpgp4U10dKbUaDb3goBqSY1ENScZYPpuEwntoQBGd6kGWq0oZ1Gc0k802ju6BO0FDVQ1NwB1pBs/7aM8sqkXnc5Zu07C1ZdahhGpvwVacta46dGzpnkhC7ems60Tk4rQtZrdhi/jWzmB91JrFOHuaR2cJSyCg/wzOZX4oSiUkbOIVVlRc5q+pu94ik9s3YJ4lOq/pnu0K+K7PnzKglht0U+LptD8s2XuhoaA1ix2CCrjhzGl7/gTbVMF2fJah0glY4A5iXj8V3wG4GsumIGD9N0T4maqt/A+utUITuHuua2uqgKfgRWowYz1Dc63/v7oz73EcR/P0Vynk36OQLR9hJ2pmsKiuadSiG92orF5ggVoIDJm21aFrJDmOHPR3X1I3JYqkDh41PcjKjJD0Pj/ex8uXm9OCwFN9pmJw3643VOWvafCr3SYriq038AjmTVEOaHaKeqsVxzJi1PNuvD7sz7vj7rRetgsm8cIbabeHw/m0Py0IYDCTuygXVvZIknjmcaLdAZ/QWnImj4OOpwtW6RtlwQiRwfnTWWu/R90X3hRTSIuayNftAubtEU3Csa+9QmbUYy5iPh2fN4eDsyAO4HTmSwYsBORfPxeAOxtnd9wflrhUzyPP/Fu0YJ3mdD5tds6S25gXJfjC8uJsNid8EnXtRG+3OQDMLDhz/2uHCvNmf14QC59HR2wWeWiQFsGZXcnpeYuDWy4IiiHGapXbXfADGb7MPIe43R22581xsyAmkiBs6bwSxNgHriileOw70x/kfNigP1ZvH1rmLE/j6GalaKgehxZI/JndRuHu+LxZ4O1IJ60d/+3Q99J49rVcqMl6Pm0P+9WbrNqn+pZY852+0RT3fNyeFkRtYcMtm9ee8ZkfNAdfb+ZF0o2NyWfl8/P+tNvsUK+qFnZB5qPp4+582u2cjazsx91RGM48de4874+b7WZFh4Ze2YwfqQct7OYyd6EedebbJfFh2YAwfFmUv3vndDzvDwsCbnJKZBAsoEPjfed58+xIaxg7ybds4npyDvvdfr/ingEFdO5BKLwEhC+WlpqIC26W2DrHPUo71EHLIsRR3BHhvHMdJxwWyHEWHNMRoJubcpvdGTWAK/rGkGze3Q/mDWl3aB5z2qw/eyRLHQiKSptDa+5VZNv95hmvK0jrlKvq8UD9sffpBXPDkB7QTGYnLZ/Lbch5bA6OOnreLwk9y4F7BLlf7znOc4E67ovDdrKawJIwuc8bxO43aFqN8lYWXZVyFp6qLAhysT2ez4fT7nnBhUqc0VbhoTM7VMv5dDjtl9y3xqbr7sTOXJFA85Tn3Yo7MdTR/wW++R4s3Z1mRm3bnNCY+rz6MmsNmoJ3a0mDU25pPR9WX1OtAV8+86W+jNs9ym3nebviNjatW+ksjcyi3GyOJ+zvJIuyumN97q1Jx+3h+byiX2Wv1QaeFYDPmdX5GSfeonB8nEIYx3kQg5mBzZztFo2+NucVXe16I8PBKvjc4Afn5/PufFx9x6/XLBILn7eZzv3b/RH309J6wAWedjtne9juNisecRvO5Oc2MxaaoTjO4XxYcC8np7JUrn85jgU489zGM5ooO0siGHJGN81JmOrQxvygdNj9c/98cKTVmZY1D96KE7Azu5f9ceOcDs+yRhKd00WfEQh9rzi16GeYZnbQ2md84djpsHq3c0uKhXh8sshaEBgNx/7FbpObBYEmWIDodx+fSyrSdvd8PjzjrlsKX+ZHrwvwUPZuntF0dfVheOMdlVmv8DOzro8gmHtceXfaHHfnrRLEmTtWKJc3+wXXYTAJs8CvK/b3S+yiyp6hWZd79YPZky/niONBHRfcNsEm7uwUlKXTeiQXMHPbwNo6JzTPfj6s6Bg9IYHnnY/ZODtU6521l0nLprKa75T/eKTlMsY8/5DD4bg/7VZ3fBrntKqbZ+Y2BjscXHIviXdRT7Q5bk7n0/OKZ0cJtrKvnL+SUdyMgqZBjqxCWQLOXfezdmgqgWZoe0nJRyuKF3jFjo4zFzVQ1dng4CXrl8W0XtEgFnvn+1EdD4fN+byVUMvTZrkXLHBTKza9DqfDbnVfqh7hkqOj2+0J9Zin0+rbDmP5PTOm8eF4dPaH1bcPeym5fOR+RmVydzqvvp1Ngs5jQx3MabNZffW8OLnAm6e5S843PJ/Oz2gyJJk7dXYuAvbcykN8AfLheEIzkP2CMLpiyNcU3HBEraLhX5LE2CcVh/NZ3bP9exCUHiKLa9bheN5tdscFYdbohCHwqoo1d38ZFVB8Lhv18uuxFXca2DfPwzU/hx9WuCedUV9A5nt2CgMIMuiiGfMtgFUTi5fkh88+gbnSnK3zvFuvD+NKq/1sBdU1brmzBB5wFPrNbsUQRTR9+ITXLbGqvZJxYeRzsxQ5+EqmAw6lqCLHbgk3l27JTB3OCU2MziuuxDN04ITHkS24auoHZ2naI0X7o+x2AiOi58RKW+fBWZK2xw0aVax43piRSZi1bLR5udQ8Oa9R2Dvn48ZZ02GIoSp1nPpQGldX59m5zd3xgA8hyFVWHGjtLpcJFUXaG3NVngp/GyVNRxebm4GEu/EsbbtnHC95t+LYciwH8bhNKOM6D85rQ57RKON5u2asE0Z+4SEpL5twZIM5Sop49M52QgDVEPjzpu748N7pvJ1yuTJI5kUp3eLwxmg6M2FWi6++xPex52Ewa1cRdZJoYHba/ev/ffm3L99++evf//LLT7/89n/db7/940+//M39+69/+/vPv/72y8/fvnz9gpDqXtm6vxdf/5/ff//9Swbe4OUbKhav/wekPl6wz/CPv+I/8AP4/77giOF/S6L6n1/rv8BrunPC29ZJdjvniv1vb8HWOdS//rf6L16c+MjK5fUvsVdMwwZf6hXV+sf/Kv/AyfCncsXuj0b+L5Q1KCP+988//eZ++9s/fv2pyI0f//MjDH6ocvbff/+yRS9++QFGXoy379EP/vHbf1mn37/853/8Hv1YFZsf0CtR9jWMLzBAT9zzPPlq2+/v709lhOYnLw7tLLO/5Y+LHz9BvBqCPoreTmCaf35DUuC/N4Xw9y/o0z/88OM1Di4w/SECIf5lOfesfod/6wew/h2OXV5GM29nqD88Uh/9Cj/21b7HIbST+8P+5odJ4Hs+Mlqw2G8HF7cdWQI8aHeKoXVNYXav12lpBuwRkuZWh0eGPuW+Ie0SsdjWxhiJM5xFwE+JiExj3FR8w59VkYB9Q2NkxVJIHR1dItiYnTEu75HlKPPL1+6o/S73YdfGGjHDoUIyHlfg5QgmuqliZBvl1A3UGNUxzWXXDJopDl05Di2iO0P5gCPWOIxFAE+3COApH5FujJeK1TFMN/CjV3zHXaYgLVk2ObyBf7vn5YvSOam2qHy1MBxFXxbXiA0qT3tLjPsTenJ1Fsr3qRzRW7hzq91cWekyYmOsHJV9cPYeSyw/NBtUnksILumbLJLB16kMMESTxsJ9sg5oIYeGYWcsr8q2TP44Y8wOlSvJgDu4OXZVIqqF8fKMT9K4fuTn7sW7eFKL9agpEbrg+iG30o2aGqMrr1By7yBw3y+xtJLPtDTGlgI/cPHxHjfJfYlkY3bGuF5ikF6KS2XTOJDINWaHyoVvKamm0j6UNoIZtSJS+mH4UFT4SUtjbOGHc3CvAcjubnZ/5Jf4Paom0BIXEARsUnk71UcSHdWCQN0keo4i+ZVUVZZZkdJ4V9cW38Xa4o44oCYNAY/qJQ/cJpi8613XB6JaGEuhYuSf+6HUoRDVyGgbUl6LK7PFGFjgsVRFTz7SwBCr5SodHF3c8sltwKiGSrIf7XI5mba0DB55fINRZ22Z+PVTFnh4fSaHzRM9nU9e2owH0V/XEldx2S2APbDUpHtX39jApZ4o4qbpaXXMUTNjpRYNKZCd0vkNR/hZr1h0kGhGqEC//vYzms+HSRzBqPS+Xpdl+P3RNdP6KRdxgyBesb50EoZqRaT79IIY394ho/zQzYxBlVd+VmHCpaTRwIIYioykGVjg7pyUz0ooySNGhIFkJA/NCBeoKGd+hJrWyJOdUENbYnjlFKF9UWrijVmchyo/PSkWR1D93mjKrb4pA5JlSxQvT0GU4XBASkGpVsUWKGW2faOWRlOzWEVUkNF0O0ws7NqU+5EyvHF7/NmoDyE8bZztYe8m9083gwH05IwcBWxOwi33U8ubhpXx9ozS50R+9IqmvOgnT8FlbbDex5nbdeWGc3UZm3vx0bdz7y5jICVicR7q6jkrYpGFWs1AVSYr2+RMWFkJyzbJgsW3Q6tMVoa9OZiyEpRhj4UJroQ/jISxGsMQFQz3Se3+wto0/a/zF4X6zpMji0N1gHliaYh44k/FnLbz+8ET33wkKY7+Al4y4rHBgz//1687569/3jp/7z03/GThsTN4qt955iixHonbupyuV04HHt51JP4yPeyOaLvVZZfgNp3M5sj5zHIYmqiGBtYX01vBG8nYX8q4SrycHXEiXq+az0yQX+rYiON8nExu33SBFyYGKmq4Jii5eEYKKbEm6Li6CZqNG6mlRZumJ07XXA1eV1DNJq7ICx8miqmwJuhIP+Nip85INV24SZqSPDZUUEU2QU225qrGiloycvWDrwTvSlSBIE0T00GboCcE6MXMS32UqUZWoCHhJHUp/G9DVVVk4mqgme01nNpewzw0UkeJJa7jmjzg3UQlDZi4llvipUaOOxuwKVp8IxvommuaEtfIeU1LJq7Gd4wsYRXWBB0XYKaQiktcSYC6IROV1FzTlLieka1xB22CHoiGptmKblAr6mnRJutxXx4rHsJaXVONN12XoUWPoJuuKstNVlXSTVFl7CpBB22KniJ6lZFyajJxNWFmZKdaYYnrSLzIyDypuSYoWXMvcEUh6cR1TvSCoe1zSzZNTebfIhCYmjtdPHFdqZmrG+nU1Y00Dpv7LowT02GboCj3jGyaa65pSlxzxbiz9KTQyP6myyauKDOzFcimtgLGjjRnjDOrU3BGVpsu2wRFabTiQZoV1VRc4koKr3cTpTRg4lreDF1Xe5u8robfcOPEyLW1Lpu4IhyswUQ1Ndc0JWgyZOR8oMvGUxRWJ+TM0dElmuyeZ4oKKpmQfx7lh4MfDX/Qj2yJfaJZDqJ+5A0cQ8kzECCPQ19FQ1rC4usdbcKszcSD0cUHUYSv2FKNSJrmYT5U7FL3AR+UPehBBmcZVNLp9zK4McvGq+4wUo3XmmXjZXnqKxn9kXitWQ5e4CtZde/R1VZ5aQfyh/p625q1WY3roK3MUm5bWZZp+b7hlSBEZBNmhcqqarzWLAfvM8PnTVY8iCwK2DEsUp2U89VWp5XXPI4D7w78iH30Y1isKVFgihDV6oQ36HUStAA2b5QkMMYZE+im8Oar7GxanVXbNOAYjBXpOaObWAT15nluksLq/m6NyEMQbqGaPPR+ieM8iPHBNNbwmwx9x+pdyCcV1MRWQC9Anz1EmdYugcRnKSWCd6kW6tsD84wegYwzluVxCm66kbsYDPRu8KJOZsqvlD32cQ5OusM0jVMvVtKQUNKbMC9aRPSgEuaFS3MC0kzJngOzMLcUk6uhZvIOBgcdGYE41IyScyAUZtI+sy3n9Xo//fXbL99YHd5Pxf0srNHa2DFUItm8MPOzIs6Yv2qArtFkK4TZmL5Z2hsyMAdA5ePV7Tc6iTsITOD8exEmGH6oWD+g0JL2BdL2pmRPcTRdb/RtQxIUh2n3wr0mzo51JmaYPFyQhm/PejgJ8+sPzS+p/8YelheB9JfPmpv7ChQMCUtRdmGynjQT9uXMm1sT8ksKIbGayhH21y8qaOzBC7HRCSzJLjFiyTmIUik/XSuRdsd4m7w0Ht5Ev3+hgTkaapopCtSckxQUMHI6kheT3BwBNc0UBYFRCoIZCqI3JVuoggpqmuldgliv17vOJNsq6P9o0ptukAo0sQ0wSkbLM7UlMEpGB2hqe2CUjmCejqIeGiOippk+ihoOdapQusuH0PWXFCZTbbJOoy4CL3ebGMLFuNQA6BZEGB3fr+bnoXsyAZ+AEZZQHBczgL7mEAfPTCHPpqK/mZLob/RUX2vG2zQH6oZzjdRqLNdFmNgi6YduQTjoPq0V0MY/RjOjWTUgD+ZJUHQ+mEs/dhp4vADpJaeATOwRTEj0sRMYnB7BAPS3yamuZkFTpJrOW9cc9GyDa6wWDs3RF6zKRVZdlz8QUfT9JIqETr9jQF2ZGGrFhYNEYRZn/GiSxnnsxYER3F2Y9Ur0HQQLizIOCKa8DCPsovBWxpk5+QIyaKUQfcqD4aq3TkylpZEw0S8+uEWoNVO6ztGDJhmYuDB8gamV3FV4uo7QEghM2OImvOxptYD2U0lb+0zMFESXWOX6TQ+ztc/2diiuEijf1Qfbp1irN+tvavqDVnOQIOVT6nsOnBTFOKiwb7cY86Lae3Gaw49wx5PbaSW0Sa5ZbRJmnvBhxzjQfNeZv/i/94k5SwxvVK7A9Ngr4+xeu3G0s1T6f44Qj9FMlmCBRMXp2gkyaiJRKRCikajGwkNFYcM/8lzH5KMhbuyznduUhPwdazvpYX17x/bDneOGvpeqnN33QHsQnPGo8/FhFf651gVeVToD9akpJBz0wH9Z/VLu6dgkBRNZd3fIBSyavPSR5JlVlCJ9tDQSJnoAL/poK+Nsl1dcIbUt89SkfQoBZHzzuMaGoQfBB9aMyoWsv2KV18rpw6WAiEy0tfG29tmYdR+ikbSLwN4TMGISzD+qgZcNrBBEDzQgzh/4uL2FX4WZtdUHz6OaK0ljv8ejmirJKCUiO2TtV4qjbre0PLl5j2Olrur9asIHW3XHoYistdy5rfdBLcuOheXah4YCJMeJpm9IR8kplQ+LDz0G3JISgzBX2nJFX1JfSir8ZrO1gpC004q/rrw41BLrvcoKYr0ikKAGNr+u1mSUn1NfFEq7veaihZHaWFRmlJeNSjPZULQwK5SRJH6HqYv6YnDrnUucVUaIzyksI4TduowMYHgjDOIF5X7UfA3iHtXka7hryTZqjy0IqCGwuA515LuoEryBXOWuBk0Qg0pOe0QWaV3iq/ZoADOnfpmkYYJ/sEkZQaFZoWcow8cu7xKqMLT4nI/C5qe02omy12XgldPq8SSNPZhlLpqk+kqdDanwQxo5TUw3rdSV60pyHSaTZJiXX5rhhzRrVMoAwqS4KWCFitl8S2XRboy2ESa7GNysbp4uhg/FxSlm0BM8E2WYlAskELcjJF9UWen6GmgskprItshq0duEOu5iTMgpndR9jhUaxdJzcbU5bPk5vEWjrkISEuo6SYDwWhTiC2aQT5h5Ny90tgRM0UAizVDi3mAEU6V+6KKKumhy2srSKEh8hY0Oqb5qLQmQabXJCPIJ82ziBRdcqx8o9yrgq6HBzWkrTNE0bUeTViGNqSlUrDmKyk1qV6U3gLCsLtsCbSrdAqZq4zsHcLoGA6V10FYYPz4uMACfyweO5XcU9vKlwbp7b83zcrt8sohzeQyL4KHftDL3SOQMRKrkUVeaK6VVMW7Nrx8qEoaX9I0ZKDIE/Seml/DyIwqKdyHHLs2VxygbyxKKRvVx+eWCkIVLRWt5hUaMct/a9LSAioLal0nRuRoJjoSzn5MS0dvgyN3UdMCfwBNvfMxUWXJgo0Vi9K0zm3P8sB5EITSFowhaKo4OFGioatYvaZgiJzDqB91rADIVd36OgLb2+bg4bK8m0tq0hECj3fpZR5sI/OhVybpbRyvuGtksUwqUHnTCvmCB0kNam55eoAL/hV2g0AOFiZ/+ui/GwEClQGTcpgDIGKX2E2LahbAwdL27r8JDsyCtDvE1Nhk3qeCnlETqJsFo8bgpXMU9IUDNOIbE61hmUOI9IQ0pSJplp6Kye2qJFBS6phY996LkIlMC7WV4iSml7Kk60UiWO5Hbc9FzKQivj0jNwLSD1zHL5lN3XQ/BN3pFzzB3UzVTRSJvU96tVtVTSucdPULG8mSfNP1MchXHUknGxqoIna7uo2+czarmpgyCkHofRp/rlvjK87e2ySYLLiFQTVbbZJOFmfJqW5nkcmmqDKRlNmWSKh8NVCY5/a36GpqK1NDCZU81WE67sK1PVjqSqmZrrYrQ6epnh9bZtKr83gjIMSe3HpuqOMsE20hM5T6boiOyBBrtFKyAa/Rg2Y42R1exdoSllPE0a5MCI2nVYJVNofGparbGKn/MpxgNiuRnMf5SDFbbFBjzKSarbfLHfIrBKpP80ZRirsokfzSlmCsVKfuKDmSQYNRDFyOjKcVsrVWR8YliuJFTHvTxiWK2kVuAqOMTxWi0+CQzrnf1EHL+ydoQyYJi1hdHMOJc8IqeDF/gJQ8yN3skSZz2n6f4i+DAhNxIzIHffBh4HgxgGdxGiRtVmUB2NxXsoVC7VGKzUPsbiwyVcRj5CY7SFak5/jhfZI9UQGOSgT9CLtIw5wWipm3lDz0DKxQljpuCqVG5R3bIONlbLZcCaJwMkowjo/6A56kJ2z9BRw9tXoGkeZ6NF0iDqmflxdoh4+Qkym8XKPGem6Shg8WrUV5oooAOFk9ACDwjFXS4eJ3WHWxNlNDl4ktwDkdDRXTI+DIOW8dQGR0yjoybmZX6JlypccgaNDx6A8FDUejlaR0ECSfUSQr5ZJZfvqT+2+CI97xO1u980L1CkD9SvQna4rRhfeiEgiP96k2FccVnKRuPOE7RlcHaQcW9wARGFxh5vnH5xqAUG8aXR+BCzXPQnjIqm0CeVe/lKYgQW4pedLEHFJ7ZmZZxPNR5atWFyV+kdDyQ/npzbaLmKwsJxk+WJpzfkG5Wa2usqrHbSie1tmapY1BObm3NUUZlm9f+1FnvJ3dFoWHEM08Ed5Hqu5qzLetovo8chJmkGE2v/zCCK9ZFegEElz+M4Bp27sxo8j5TCpBo1iZTCvzAHR5REjle3Msm/CUFw5xCkV1j16eIa+Oce2rQS+FVhU/dOGUNwCctD4C4ME1j3HNflIwiGeB0Hr4OVQNgBrrYLVHFowoXAxjA4xN+kfWS+sJz3lLJSwB5g/aCBj2nPjlqETaybncxZu69QAhPG2d72AtJbh/XqLyFsClQ89LhPXx5ZEJJUDypUX1h3yZR5mn+/g7exEp68aRGzYV9m0SZOSH3L/AdBK9CsuuHNSqvEewB0GrLyPgsL69JhNd051DTbPjYx237QXmUlsDYtJsl0POvSrzl+10LMm8XzHZDbtPBKIPxkfI2NxvAI49vkDaa7J+bLwhTGECQcatv/Xitz8FH2euXFZyp76V4JdLuqbC5mKuV9iR43HxuKhcwj5zoXAR8FGivuVkOvFcXvqlZuO43JIVcmwZmCwLzN9+oX0nun26GMtD7g6gmeef1LgmwvDiqFt7ow4m57SWBnQAXzbvfdAzHq6QllXaaz3FO4Sa0pxx/pDVVNhEKljaEdI+xcepMky7mqelhCQgZ6DekTI6xCeZNOTs2TxKNbWJxM0wNQ4hYs9tpcIibi/Bu1aRee/i6tqrJgrIFoKf02pQv6O+yZ8heowDl/rQSk/smFJHct2lYkwpBriLG9iwlK+QrwLsNfj/aKztFqncMyN+KxB7Dm5LP9Wv685qpanaeezH88LMcRh59ciy2JEx5tjNXeNC8OgbJ3iGxqvVJXUWpg0JbR0WCbDrtsGSJyNRVtubJpA6gWLOT8WmLyPYgKwGNSLlqx6WHtfoKGD96QQiG0QuG7Xv4GE6fqc0fetBNIf6hsmRGCuzatk3n4MWlr1/Rziy86dbh96OLn0Ivt/77AR9qk31omnFoNsCDSQs7XqhEJKyK0FmqroelMFoj98CSR9XQc97dDy5KGQmrPDrUuIFIA19rl0N4RR+wlF1LRFL2bHNINUEK8yEzr1BbWg6s82jvKi7i6DHeabdv9MnUuqrUbCPeKSTdI8h95e02YZWTduWzEcyxTeVpOLDOCjnsARUnYlrA2iCD6ZEkGvplwuqUgBb9f5Kj1TtIL+8g7U5L+55HMXqEGfyCHc8LjdaKT0heuqyF2IWx+lw+aZkZ27p61oujPI0DybGhWLR9gmnR1Tix2ftW5JXhnsTq2OHAuEieyF39ZYHSlnAne/ZSDkNSY7w8yigaboz9j7P3mD3PFLnozIslngFp0q3yqaaLqMt2hTLdQ1LkyjD8cfnlg62zKjcVyvRbGYYrDR/Oobxyw83uj/wSv3NujaKXiEH4oeFnyxhOIvEuhu+qK18U4034lTFNI79c4tgvWEBlJ7uy4k5L9jrIyNRkX+AiuGyYg5fxx4c4+d1HbX2CwJlRvqqT9OxKWHiNpf1LKnt5KjX6D9ZqdyTVAXHsCs0eifDTD6qikXAsdA9BKPmUHB9y9NwbhdN9T0GiHbahYBPHUZbjPS8cdlAnc5+DSZ3fU4hmSzLvo+cSEwxM2nqGpxG2iyDEWmyGGgDccLCpM6AduIPAZAWBf4vkRpHg9wpdBibtS+SGD4kzRy5qC8DmBBk87tEcLodpJPPKSD7wkIRNjrLiIfvmHj41SSFCHMYSdzFEgSsIQV43Be9GMNcgE7hRiXoDmS/zHNREAQSR8LhIH32PgjMukhugSWBANBaBaXz85mIorcw0mCn8+pvvcSCmDuglzcNyg9lxFdBQBNi1Ny59DDYzXlROPt0kDnSWlj4GkzkI41zi2iUXtrHPpAwvOHiGRswWgMepuT/pELBJk0x6wD8+LAHB5S3CSWjGbRi4tKlkDwsh3HTE0YLCm6dApq+lEG7DwJ5Zg4vc++L5E+uWgE36asLwoUfBI9bcgnUIOKTvqZ/rLLEdAqGVICPKAo2FHeoGX7IQ5O4dBgmUeWUkl51CwnYUzgK3cNA0gJ3KwqX3Al/vohwJweUNfZk3sgrR1ghcVvTidmfCHIMOI8j/Cj91F2sShNsS1vc1l6VK7+L4gGWWe0jwuAyPVQnt3Q4SCMj0KR1NkkpD828gFIIapL6OKdkAtsLg0WbR1gTaCkOAVtfwhoY8OtChbnkYAN2C8IiL5WMTiBsQHvHDD7Bn4FXiffHi1AQML4wy+k8QGNFqdFH49/uYAOyJlA3vDtD/OxsTgDsoQtRJHEg87DGRu4bhkiMzbumRaQQ7icOjLz2IDOBuQASuqjKBl3rOZUgbhwnILedJ4kFVcWYChkuOi5ALLv98ZLkbwBvwPuvrtk2QwqSbo+2axqGmPQYhdV2+SfrwNKd4ufyQcfoofJP1ZQ+8ogJzkzVSGCfpRDNt43RVTJN0fBw2Z+OE1FBiSoxqJoTbhI4rqxHwJA+PP0/dS/pixBirg8KhlhyZQBh5JEoBhdeE1aeR2wL6rHcTZmUVBYcVepe7AbA1Bp/WiAau4eDy/jMBrya0ah0SLrOOLdYhL3Wble7WZAJvS8Jj1uQqMiAecxfp8d6MWGO6Ca0x3V8vVwNgawweLb5E2pChA8HC4Q5CE/riioLDWl/xa8w62BCIp0DHsYEBNfXYwID0YATqQYQVhnH66b48rld8o1kQxCYs3o1QcbREaOqexTh6kQn1skfDY/fRHPdVxymTAXdLwmGOfROqZEXBiyUOTei9Kwoeqw6/yQEq1XVyQOplW4mB2SfQ1iACxCa0zg2HAO+zIbzPIrz1iWEDkDsogtSmrL0NeET5i6PEBvHXPDz+OPjc7jZGVMwOCo869d9ADl3geTAzYcgxBOIpqE+fG8DeQeFQpz7qRy/bowkuFAQLj9uINbtUaMUuuwMTfPFqDD6tcziawVuB8Il3ZvDuxGgPRozzWhAesRF7sWK7r4UHP/DuJow8CBYR7sItKHv4uREbUzQkERVx/Oobk/wNjAB57uMVBkPIWxgOeRsEST84wcLj9kNDoBsQDnF1a5kByB0SDrMh/ieCHif4MddLTehuuihi1Ca0HF0UIerMhG3DLopQwMrBeSM04+GdNdLuzokYbXGvzfKoVuWwhe9MdmEEXgKoc5m4VTAGNklV5dL1Cj+RPT91Jd8xMEPeKOEcndlnFEefWvc5RxV22f4I53GwkGlncUrV+J3cj3AYjiTONA+0O7lB55qmKUnRQCb3pV4JPUcTyTVNE655qJnHS3F6R14UXUM2MW3lyQQztLQsouyaXR4IdtFzP+XzZYBtfWGAKBIGSBOVRDn8yDPjWjM23zyNJrYEfMZ5Wk1rydl8YhrRi6nOJfuOnAZFjFz7KZsOuvhpmvJ5A7aQO/QTdpGrNzJYFT4zBBA4ggr876ZU4wZFkDxPH54h45SWRYzdoKnkxDnjGwgepqC3LEKrMrOu3UF9SZRfF9695MeogEAQuuXXFIbZKQ0WF+NQIGbF15kmVV1BqaTiy2goEEJSSYcPLTk1mjkUOOVpS09OfiXK4O3Wu/Js+MxnlsPwzYfvvOBN337+859//pW3nlo+5f76228KM7EUarda7BLDJmk4TW35sMLs5WAL9A4dfcZg1zSrdQ68m/0yH8mLIzcALxnzikwfP1HcpMCuE5VvfAgiMKw//R3iAD1XeM/LLe5dkXZHiU3C2gQPO3xe86TcojOdXLTfIG9ILU8yCGVaOV+q72Eu39SVCiS3PYbGzMrysfY+ewN09JFE+Mt3FdzAM1EEyTW9aMI39KpbJAW7XBYP6s3GDqvdw+EKX3Y7YJLGeezFjBsCv/u3FwhZTTxIEnbTfk3Rf3Fq8UY75eIrb7RTErnIrNt8uV63ldYf1Alll9ZtZN1urFfXk9gcMs64gvp2lgMcV+vFRGVdtlnaAggl3gy4QFgNNkeV7E2NxSWRP8Klvl00TCbKasBm5RYa/bwAmSH9F+RXh01MG4zuIPLgxU1j1OPIvBByiioalZgexNFND0NaQRrVTF+p4HHz6R0eeY86DqNjFUsSlIeHc4wKtAz7XrymK+VKhXZHgD3KNywTQso01VxhZfTaO1I+hIoNHk1y43lfLawwj1+hts6oGPX2QeYuUYilwmA1zkO68+Gl1P2SVT1ngcsFCc2s8rCA0kpTzhEqEHuciOc+X72oNtPp8PO9SOH3rD+rGCjFz1g1jAa52L49gODFB8LPQ6mBvwWAoVjA7+LZoj5b+AN+7svcDxPgprCs1p7A0Dlu2GsFeBwAoouFxjOXAKaZdUshjKwkfoepdYMRTEEOL2qbjQLbFidjLgoVH7N0TKZLGX377MVUmPogsIr7hK7IcmFVB/UoCBMfWyym0OjPh+Khbck9JGAC12Wscj5S2xCQxbyDMKmI6GCmMYhUwmr2p7jBJephF0GoaDTNj/ciMy7ihHawBpmGH15vgf9ihIAWZZqEFz/Cx/8M65aoVBPzBo2Gwc08aSNc08RFMMd45qkbA5smr5nVmCWOjjVNWp4+stzyIG7mDZM3jjZN4neZt0tP0PNd4HrpsZbHCAEdlnn1xwgVzFk+uyAV38bTZiOEkDiT64RhtX1ANH3z/AMBsWfCH+Xc4fGSqdWM7dqkcWZ+4UfVlrGGcN72/XAJE0/QOP6EY6uclD2Vtq+rHC6sKLbewCNQOHMuJLWrhSJgzEwe+YBpgubqsOTf3jwzh4Svch77QJG/VvZIklhm0IaZ8gZ07K4BzTSt0l3fghGaCEDFCzs9VQyeqTq2x93r1jg1JNVUTc7JRE0k1VRNlwxYbzD1r5/GCaOgzVGX+bfISG0E2IJ8M7NYjgJOH1uyvAG7+9cws6BKj48yEdrN6w6AQNdW7fh7aBQeQeUddUs9RiPSO5euDPAjh9FFZnAbMQ0UHBERpf9sEOPjEkUpxXMhfaWIR8XevcjTOLpZKZrZxaEFEl+fDirK9MpfHzvmXlrve2ms9cp6eoLU/HYBOHZd/ewt6OrgJ7tlvCWW5DO1dO31qdSufc7mm+rFKhJUeH1qbL6miZuBM2uSpbW0cKGYknAnHIYKVwlJ+I55dkmPH6kHLezfqnDXs1faewycLeYX3QWjh8Au2UGguRR3AURTVtu6DSWJxZdqipe0EgumseQ7TkWSdvR6UxIXX8WHnpV4ip0D2wXgo2rF5C+z3f1A+eSkRmyMC5RPEBQ1Loeoz5N43leknA5QRKrXA/XW3qcXaOvRaBxM8NIDQxtvxzwb8xHkfu1QoQ22DyGAnNy1jeUJALZbZSnJwtM0yQHq2MhUEM58H/tiyo3nyhlEEgRM2K5TiS7cPoPYKteb78HS71XzpKiPwsRPwbuluYHrIbDDC3zmWg4NkMRDCoGer7PIpbXnIzmY4IH/koJUW+vcMc/uRoBnBeBTX4NBALDLbxznQQy0jTS79iduJ2kbHFNJJi/a31QeWKS2yzQcdrlW7C7eK9RiHuJ4DUNjm9Yxz654lYd4jm8y0Fb7+hC8qE71Af7ysKbkmPycMdwojaCIPHgr4tLoF9AlEYS/fKIf+V4R7MLP8NU8Sp1+x5SMYk3fQ7txXDNv1WFrS3aEeLr2W2JTCJi5dytO0H586qnzJXAPgMeb+dGrTlzS/vRCVH6S44KRZNYr/Mys6yMIVG89Nx61PQb2dhHxtOKMoRLzGy6/biK+X2IXNRsZmsu66BEN0+r6Hzwm4b2wsoRaj+QC1G+M1f9g8SzIGz31gcs0vSkoG2lOkLxiQlo++UjL1SzFCVAat0dIBKb1xDtWdZm0MSI6QJwDKDo69YpbsD8vO38tK2wVaI9AgFbD2jbBKrK0TSs2F3jFXurKV9gYJbmLNKc5GoQKpiYDsYGhxWG2jN3JgBHZUgF63JnLYMADBEFi1QFCqMyCUUIoGaS+rtALiui2GxKrc0bXS/dJU7vmNb3Q85qi4oghNxQ5a4bvKj4iWXnyY6O8xYcWTXBlJXV2Lnrdc6sDUWZoG6cSlHVNwQ2HmS76LjM0jSDNmOUHtAh5fcc6jU0Lsm/TGKZLDQHntpayLdDgioNM2oTxFQ4FFxeusg8F3zxagvSHWjn8sMI9PwIpcSbjBWT+8OOUt1IYQJBBN0PtTQCrXo/64nA/c2jxCajKuCJ5bZSCdpNE9pDHpsqzR9mp8U3p0RBZv2BkTH1YRmneNCd0zMmeGkkwh7oKpGQSlnhLrGqbXHbukNb0ZgvJMp4fQ2aZtYWyhbJyHjSGjKgVt4RbE0pSmYleK1KU9LU5IzKg/hg3G7rU0poiBK6yLeqY098YdWDYrVGPWmbNwKZoYV5Wz42+PSPqRkPDrRwEt8wMSR2nDvuhKEs6Fo3IlA4PN1t67NKaLWInT2H7RbOrvyGjUbFbtDEdMmtS16aiqkQchDShLnWBuJWpTy+tNuFlF4WVqGNOf93pwLCrTI9aZk2hrdWtnA+tJSPqBV7841WHinWNhF/rLlTin+Q/SF93f8Udsvpr9tAQSFa8RK36GMVMCsElhE/3PAzWMkZ8sjJJbCXXtv9U7igjuwF4gQHxk5cYpJef4jBBb7zggx6feH00vew3my34unnC//tfG+cH/KPt0Wl/tEMv48t1++/Ca7pzwtvWSXY757rdOPtbsHUO6GlUyvsPe3H4VF7l+IR++1SOTtFgCKZfi/rw5Dqb82aze3a2p6aW/hjGFxh8vcDMS/0EC/2PH+3hz8ryRSQI+tmPuIr9E3o5+vuXf/1/ZlvVNA===END_SIMPLICITY_STUDIO_METADATA
# END OF METADATA