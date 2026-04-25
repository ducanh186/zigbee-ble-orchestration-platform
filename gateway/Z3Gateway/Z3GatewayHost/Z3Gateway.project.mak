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
 '-DSL_COMPONENT_CATALOG_PRESENT=1' \
 '-DPLATFORM_HEADER="platform-header.h"' \
 '-DEZSP_HOST=1' \
 '-DGATEWAY_APP=1' \
 '-DUC_BUILD=1' \
 '-DEZSP_ASH=1' \
 '-DEZSP_UART=1' \
 '-DUSE_ZAP_CONFIG=1' \
 '-DEZSP_APPLICATION_HAS_MFGLIB_HANDLER=1' \
 '-DCONFIGURATION_HEADER="app/framework/util/config.h"'

ASM_DEFS += \
 '-DSL_COMPONENT_CATALOG_PRESENT=1' \
 '-DPLATFORM_HEADER="platform-header.h"' \
 '-DEZSP_HOST=1' \
 '-DGATEWAY_APP=1' \
 '-DUC_BUILD=1' \
 '-DEZSP_ASH=1' \
 '-DEZSP_UART=1' \
 '-DUSE_ZAP_CONFIG=1' \
 '-DEZSP_APPLICATION_HAS_MFGLIB_HANDLER=1' \
 '-DCONFIGURATION_HEADER="app/framework/util/config.h"'

INCLUDES += \
 -Iconfig \
 -Iautogen \
 -I. \
 -Iapp \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/scenarios/z3/Z3Gateway \
 -I$(SDK_PATH)/platform/service/cli/inc \
 -I$(SDK_PATH)/platform/service/cli/src \
 -I$(SDK_PATH)/platform/CMSIS/Core/Include \
 -I$(SDK_PATH)/platform/emlib/inc \
 -I$(SDK_PATH)/platform/emlib/host/inc \
 -I$(SDK_PATH)/platform/common/inc \
 -I$(SDK_PATH)/platform/service/iostream/inc \
 -I$(SDK_PATH)/platform/service/legacy_common_ash/inc \
 -I$(SDK_PATH)/platform/service/legacy_hal/inc \
 -I$(SDK_PATH)/util/third_party/printf \
 -I$(SDK_PATH)/util/third_party/printf/inc \
 -I$(SDK_PATH)/util/silicon_labs/silabs_core \
 -I$(SDK_PATH)/util/silicon_labs/silabs_core/event_queue \
 -I$(SDK_PATH)/util/silicon_labs/silabs_core/memory_manager \
 -I$(SDK_PATH)/platform/service/system/inc \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic \
 -I$(SDK_PATH)/protocol/zigbee/app/util/serial \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/service-function \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning \
 -I$(SDK_PATH)/. \
 -I$(SDK_PATH)/protocol/zigbee \
 -I$(SDK_PATH)/protocol/zigbee/app/ezsp-host \
 -I$(SDK_PATH)/protocol/zigbee/app/util/ezsp \
 -I$(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework \
 -I$(SDK_PATH)/protocol/zigbee/stack \
 -I$(SDK_PATH)/protocol/zigbee/stack/platform/host \
 -I$(SDK_PATH)/protocol/zigbee/stack/include \
 -I$(SDK_PATH)/platform/radio/mac \
 -I$(SDK_PATH)/platform/service/token_manager/inc \
 -I$(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-client \
 -I$(SDK_PATH)/protocol/zigbee/stack/gp \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-common \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/common \
 -I$(SDK_PATH)/platform/service/legacy_host/inc \
 -I$(SDK_PATH)/protocol/zigbee/stack/config \
 -I$(SDK_PATH)/protocol/zigbee/stack/zll \
 -I$(SDK_PATH)/protocol/zigbee/stack/core \
 -I$(SDK_PATH)/platform/service/legacy_printf/inc \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/manufacturing-library-cli \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-common \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-simple \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/scan-dispatch \
 -I$(SDK_PATH)/protocol/zigbee/stack/security \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/signature-decode \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness \
 -I$(SDK_PATH)/protocol/zigbee/app/xncp-test-harness \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/time-server \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/include \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/util \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/security \
 -I$(SDK_PATH)/protocol/zigbee/app/util/counters \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/cli \
 -I$(SDK_PATH)/protocol/zigbee/app/util/common \
 -I$(SDK_PATH)/protocol/zigbee/app/util/security \
 -I$(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl-framework-core

ifeq ($(findstring clang,$(shell $(CC) --version)),)
  GROUP_START = -Wl,--start-group
  GROUP_END = -Wl,--end-group
endif

PROJECT_LIBS = \


C_FLAGS += \
 -std=c99 \
 -Wall \
 -Wextra \
 -Os \
 -Wno-unused-parameter \
 -Wno-missing-field-initializers \
 -Wno-missing-braces

CXX_FLAGS += \
 -std=c++11 \
 -Wall \
 -Wextra \
 -Os \
 -Wno-unused-parameter \
 -Wno-missing-field-initializers \
 -Wno-missing-braces

ASM_FLAGS += \

LD_FLAGS += \


####################################################################
# 3rd Party System Library Support                                 #
####################################################################

SYS_LIBS = \
 pthread \
 c \
 m


ifneq ($(SYS_LIBS),)
  PKG_TOOL := $(shell command -v pkg-config || command -v pkgconf)
  ifneq ($(PKG_TOOL),)
    PKG_LIBS := $(strip $(foreach pkg,$(SYS_LIBS),$(shell $(PKG_TOOL) --exists $(pkg) && echo $(pkg))))
    ifneq ($(PKG_LIBS),)
      PKG_FLAGS := $(if $(filter -static, $(LD_FLAGS)), --static)
      C_FLAGS += $(shell ${PKG_TOOL} --cflags $(PKG_FLAGS) $(PKG_LIBS))
      PROJECT_LIBS += $(shell ${PKG_TOOL} --libs $(PKG_FLAGS) $(PKG_LIBS))
    endif
  endif
endif

PROJECT_LIBS += $(addprefix -l,$(filter-out $(PKG_LIBS),$(SYS_LIBS)))

LIBS += $(GROUP_START) $(PROJECT_LIBS) $(GROUP_END)

LIB_FILES += $(filter %.a, $(PROJECT_LIBS))

####################################################################
# Pre/Post Build Rules                                             #
####################################################################
pre-build:
	# No pre-build defined

post-build: $(OUTPUT_DIR)/$(PROJECTNAME)
	# No post-build defined

####################################################################
# SDK Build Rules                                                  #
####################################################################
$(OUTPUT_DIR)/sdk/platform/common/src/sl_assert.o: $(SDK_PATH)/platform/common/src/sl_assert.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/common/src/sl_assert.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/common/src/sl_assert.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_assert.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_assert.o

$(OUTPUT_DIR)/sdk/platform/common/src/sl_slist.o: $(SDK_PATH)/platform/common/src/sl_slist.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/common/src/sl_slist.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/common/src/sl_slist.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_slist.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_slist.o

$(OUTPUT_DIR)/sdk/platform/common/src/sl_string.o: $(SDK_PATH)/platform/common/src/sl_string.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/common/src/sl_string.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/common/src/sl_string.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_string.d
OBJS += $(OUTPUT_DIR)/sdk/platform/common/src/sl_string.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli.o: $(SDK_PATH)/platform/service/cli/src/sl_cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_arguments.o: $(SDK_PATH)/platform/service/cli/src/sl_cli_arguments.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli_arguments.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli_arguments.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_arguments.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_arguments.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_command.o: $(SDK_PATH)/platform/service/cli/src/sl_cli_command.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli_command.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli_command.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_command.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_command.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_input.o: $(SDK_PATH)/platform/service/cli/src/sl_cli_input.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli_input.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli_input.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_input.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_input.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_io.o: $(SDK_PATH)/platform/service/cli/src/sl_cli_io.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli_io.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli_io.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_io.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_io.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_threaded_host.o: $(SDK_PATH)/platform/service/cli/src/sl_cli_threaded_host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli_threaded_host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli_threaded_host.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_threaded_host.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_threaded_host.o

$(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_tokenize.o: $(SDK_PATH)/platform/service/cli/src/sl_cli_tokenize.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/cli/src/sl_cli_tokenize.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/cli/src/sl_cli_tokenize.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_tokenize.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/cli/src/sl_cli_tokenize.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream.o: $(SDK_PATH)/platform/service/iostream/src/sl_iostream.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/iostream/src/sl_iostream.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/iostream/src/sl_iostream.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream.o

$(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_stdio.o: $(SDK_PATH)/platform/service/iostream/src/sl_iostream_stdio.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/iostream/src/sl_iostream_stdio.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/iostream/src/sl_iostream_stdio.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_stdio.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/iostream/src/sl_iostream_stdio.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_common_ash/src/ash-common.o: $(SDK_PATH)/platform/service/legacy_common_ash/src/ash-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_common_ash/src/ash-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_common_ash/src/ash-common.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_common_ash/src/ash-common.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_common_ash/src/ash-common.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/crc.o: $(SDK_PATH)/platform/service/legacy_hal/src/crc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_hal/src/crc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_hal/src/crc.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/crc.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/crc.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/ember-printf-convert.o: $(SDK_PATH)/platform/service/legacy_hal/src/ember-printf-convert.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_hal/src/ember-printf-convert.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_hal/src/ember-printf-convert.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/ember-printf-convert.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/ember-printf-convert.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/micro_host.o: $(SDK_PATH)/platform/service/legacy_hal/src/micro_host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_hal/src/micro_host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_hal/src/micro_host.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/micro_host.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/micro_host.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/random.o: $(SDK_PATH)/platform/service/legacy_hal/src/random.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_hal/src/random.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_hal/src/random.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/random.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/random.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/system-timer.o: $(SDK_PATH)/platform/service/legacy_hal/src/system-timer.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_hal/src/system-timer.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_hal/src/system-timer.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/system-timer.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_hal/src/system-timer.o

$(OUTPUT_DIR)/sdk/platform/service/legacy_host/src/token.o: $(SDK_PATH)/platform/service/legacy_host/src/token.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/legacy_host/src/token.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/legacy_host/src/token.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/legacy_host/src/token.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/legacy_host/src/token.o

$(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_init.o: $(SDK_PATH)/platform/service/system/src/sl_system_init.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/system/src/sl_system_init.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/system/src/sl_system_init.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_init.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_init.o

$(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_process_action.o: $(SDK_PATH)/platform/service/system/src/sl_system_process_action.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/system/src/sl_system_process_action.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/system/src/sl_system_process_action.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_process_action.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/system/src/sl_system_process_action.o

$(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_def.o: $(SDK_PATH)/platform/service/token_manager/src/sl_token_def.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/platform/service/token_manager/src/sl_token_def.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/platform/service/token_manager/src/sl_token_def.c
CDEPS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_def.d
OBJS += $(OUTPUT_DIR)/sdk/platform/service/token_manager/src/sl_token_def.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ash/ash-host-ui.o: $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash/ash-host-ui.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash/ash-host-ui.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash/ash-host-ui.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ash/ash-host-ui.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ash/ash-host-ui.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ash/ash-host.o: $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash/ash-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash/ash-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ash/ash-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ash/ash-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ash/ash-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-io.o: $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-io.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-io.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-io.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-io.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-io.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-queues.o: $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-queues.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-queues.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-queues.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-queues.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-queues.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-ui.o: $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-ui.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-ui.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/ezsp-host/ezsp-host-ui.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-ui.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/ezsp-host/ezsp-host-ui.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/core-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/cli/core-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/cli/core-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/cli/core-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/core-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/core-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/network-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/cli/network-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/cli/network-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/cli/network-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/network-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/network-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/option-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/cli/option-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/cli/option-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/cli/option-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/option-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/option-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/security-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/cli/security-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/cli/security-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/cli/security-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/security-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/security-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/zcl-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/cli/zcl-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/cli/zcl-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/cli/zcl-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/zcl-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/zcl-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/zdo-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/cli/zdo-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/cli/zdo-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/cli/zdo-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/zdo-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/cli/zdo-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_common.o: $(SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_host_cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_host_cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_host_cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/common/zigbee_app_framework_host_cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_host_cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/common/zigbee_app_framework_host_cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/ezsp/ezsp-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/ezsp/ezsp-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/ezsp/ezsp-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/ezsp/ezsp-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/ezsp/ezsp-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/ezsp/ezsp-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/file-descriptor-dispatch/file-descriptor-dispatch.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/gateway/gateway-support.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/ncp-configuration/ncp-configuration.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/ncp-configuration/ncp-configuration.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/ncp-configuration/ncp-configuration.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin-host/ncp-configuration/ncp-configuration.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/ncp-configuration/ncp-configuration.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin-host/ncp-configuration/ncp-configuration.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/address-table/address-table-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table/address-table-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table/address-table-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table/address-table-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/address-table/address-table-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/address-table/address-table-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/address-table/address-table.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table/address-table.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table/address-table.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/address-table/address-table.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/address-table/address-table.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/address-table/address-table.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/basic/basic-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic/basic-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic/basic-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic/basic-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/basic/basic-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/basic/basic-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/basic/basic.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic/basic.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic/basic.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/basic/basic.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/basic/basic.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/basic/basic.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/color-control-server/color-control-server.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/concentrator/concentrator-support.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-ota-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-ota-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-ota-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/counters/counters-ota-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-ota-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/counters/counters-ota-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/debug-print/sl_zigbee_debug_print.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ez-mode.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ezmode-commissioning-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ezmode-commissioning-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ezmode-commissioning-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ezmode-commissioning-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ezmode-commissioning-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ezmode-commissioning/ezmode-commissioning-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/green-power-client/green-power-client.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-client/green-power-client.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-client/green-power-client.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-client/green-power-client.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/green-power-client/green-power-client.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/green-power-client/green-power-client.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/green-power-common/green-power-common.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-common/green-power-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-common/green-power-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/green-power-common/green-power-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/green-power-common/green-power-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/green-power-common/green-power-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ias-zone-client/ias-zone-client.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify-feedback/identify-feedback.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify-feedback/identify-feedback.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify-feedback/identify-feedback.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify-feedback/identify-feedback.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify-feedback/identify-feedback.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify-feedback/identify-feedback.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/identify/identify.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/identify/identify.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/level-control/level-control-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control/level-control-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control/level-control-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control/level-control-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/level-control/level-control-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/level-control/level-control-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/level-control/level-control.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control/level-control.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control/level-control.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/level-control/level-control.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/level-control/level-control.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/level-control/level-control.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/manufacturing-library-cli/manufacturing-library-cli-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/manufacturing-library-cli/manufacturing-library-cli-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/manufacturing-library-cli/manufacturing-library-cli-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/manufacturing-library-cli/manufacturing-library-cli-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/manufacturing-library-cli/manufacturing-library-cli-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/manufacturing-library-cli/manufacturing-library-cli-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator-security/network-creator-security.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-creator/network-creator.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-creator/network-creator.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-v2.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-v2.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-v2.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering-v2.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-v2.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering-v2.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/network-steering/network-steering.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/network-steering/network-steering.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/on-off/on-off-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off/on-off-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off/on-off-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off/on-off-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/on-off/on-off-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/on-off/on-off-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/on-off/on-off.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off/on-off.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off/on-off.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/on-off/on-off.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/on-off/on-off.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/on-off/on-off.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-common/ota-common.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-common/ota-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-common/ota-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-common/ota-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-common/ota-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-common/ota-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server-policy/ota-server-policy.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-dynamic-block-period.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-dynamic-block-period.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-dynamic-block-period.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-dynamic-block-period.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-dynamic-block-period.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-dynamic-block-period.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-page-request.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-page-request.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-page-request.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server-page-request.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-page-request.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server-page-request.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-server/ota-server.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-server/ota-server.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-common/ota-storage-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem/ota-storage-linux.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem/ota-storage-linux.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem/ota-storage-linux.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem/ota-storage-linux.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem/ota-storage-linux.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/ota-storage-posix-filesystem/ota-storage-linux.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/poll-control-client/poll-control-client.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-default-configuration.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-default-configuration.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-default-configuration.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting-default-configuration.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-default-configuration.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting-default-configuration.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/reporting/reporting.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/reporting/reporting.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/scan-dispatch/scan-dispatch.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/scan-dispatch/scan-dispatch.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/scan-dispatch/scan-dispatch.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/scan-dispatch/scan-dispatch.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/scan-dispatch/scan-dispatch.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/scan-dispatch/scan-dispatch.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/simple-metering-client/simple-metering-client.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/stack-diagnostics/stack-diagnostics.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/stack-diagnostics/stack-diagnostics.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/stack-diagnostics/stack-diagnostics.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/stack-diagnostics/stack-diagnostics.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/stack-diagnostics/stack-diagnostics.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/stack-diagnostics/stack-diagnostics.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/read-write-attributes.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/read-write-attributes.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/read-write-attributes.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/read-write-attributes.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/read-write-attributes.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/read-write-attributes.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/test-harness-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/test-harness-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/test-harness-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/test-harness-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/test-harness-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/test-harness-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/test-harness.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/test-harness.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/test-harness.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/test-harness/test-harness.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/test-harness.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/test-harness/test-harness.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/time-server/time-server.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/time-server/time-server.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/time-server/time-server.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/time-server/time-server.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/time-server/time-server.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/time-server/time-server.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast/trust-center-nwk-key-update-broadcast.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast/trust-center-nwk-key-update-broadcast.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast/trust-center-nwk-key-update-broadcast.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast/trust-center-nwk-key-update-broadcast.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast/trust-center-nwk-key-update-broadcast.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-broadcast/trust-center-nwk-key-update-broadcast.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-periodic/trust-center-nwk-key-update-periodic.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-periodic/trust-center-nwk-key-update-periodic.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-periodic/trust-center-nwk-key-update-periodic.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-periodic/trust-center-nwk-key-update-periodic.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-periodic/trust-center-nwk-key-update-periodic.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-periodic/trust-center-nwk-key-update-periodic.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast/trust-center-nwk-key-update-unicast.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast/trust-center-nwk-key-update-unicast.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast/trust-center-nwk-key-update-unicast.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast/trust-center-nwk-key-update-unicast.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast/trust-center-nwk-key-update-unicast.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/trust-center-nwk-key-update-unicast/trust-center-nwk-key-update-unicast.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/update-tc-link-key/update-tc-link-key.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl-framework-core/zcl-framework-core-cb.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl-framework-core/zcl-framework-core-cb.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl-framework-core/zcl-framework-core-cb.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl-framework-core/zcl-framework-core-cb.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl-framework-core/zcl-framework-core-cb.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl-framework-core/zcl-framework-core-cb.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-custom-cluster-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-custom-cluster-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-custom-cluster-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-custom-cluster-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-custom-cluster-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-custom-cluster-cli.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-global-cli.o: $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-global-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-global-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-global-cli.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-global-cli.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/plugin/zcl_cli/zigbee-zcl-global-cli.o

# Using local app.c (with Coordinator code) instead of SDK default
$(OUTPUT_DIR)/project/app.o: app.c
	@$(POSIX_TOOL_PATH)echo 'Building app.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app.c
CDEPS += $(OUTPUT_DIR)/project/app.d
OBJS += $(OUTPUT_DIR)/project/app.o

$(OUTPUT_DIR)/project/main.o: $(SDK_PATH)/protocol/zigbee/app/framework/scenarios/z3/Z3Gateway/main.c
	@$(POSIX_TOOL_PATH)echo 'Building main.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/scenarios/z3/Z3Gateway/main.c
CDEPS += $(OUTPUT_DIR)/project/main.d
OBJS += $(OUTPUT_DIR)/project/main.o

# ===== Coordinator app modules =====
$(OUTPUT_DIR)/project/app/app_state.o: app/app_state.c
	@$(POSIX_TOOL_PATH)echo 'Building app/app_state.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/app_state.c
CDEPS += $(OUTPUT_DIR)/project/app/app_state.d
OBJS += $(OUTPUT_DIR)/project/app/app_state.o

$(OUTPUT_DIR)/project/app/app_utils.o: app/app_utils.c
	@$(POSIX_TOOL_PATH)echo 'Building app/app_utils.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/app_utils.c
CDEPS += $(OUTPUT_DIR)/project/app/app_utils.d
OBJS += $(OUTPUT_DIR)/project/app/app_utils.o

$(OUTPUT_DIR)/project/app/app_log.o: app/app_log.c
	@$(POSIX_TOOL_PATH)echo 'Building app/app_log.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/app_log.c
CDEPS += $(OUTPUT_DIR)/project/app/app_log.d
OBJS += $(OUTPUT_DIR)/project/app/app_log.o

$(OUTPUT_DIR)/project/app/net_mgr.o: app/net_mgr.c
	@$(POSIX_TOOL_PATH)echo 'Building app/net_mgr.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/net_mgr.c
CDEPS += $(OUTPUT_DIR)/project/app/net_mgr.d
OBJS += $(OUTPUT_DIR)/project/app/net_mgr.o

$(OUTPUT_DIR)/project/app/telemetry_rx.o: app/telemetry_rx.c
	@$(POSIX_TOOL_PATH)echo 'Building app/telemetry_rx.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/telemetry_rx.c
CDEPS += $(OUTPUT_DIR)/project/app/telemetry_rx.d
OBJS += $(OUTPUT_DIR)/project/app/telemetry_rx.o

$(OUTPUT_DIR)/project/app/cmd_handler.o: app/cmd_handler.c
	@$(POSIX_TOOL_PATH)echo 'Building app/cmd_handler.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/cmd_handler.c
CDEPS += $(OUTPUT_DIR)/project/app/cmd_handler.d
OBJS += $(OUTPUT_DIR)/project/app/cmd_handler.o

$(OUTPUT_DIR)/project/app/device_monitor.o: app/device_monitor.c
	@$(POSIX_TOOL_PATH)echo 'Building app/device_monitor.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/device_monitor.c
CDEPS += $(OUTPUT_DIR)/project/app/device_monitor.d
OBJS += $(OUTPUT_DIR)/project/app/device_monitor.o

# --- Phase 1/2 additions: parser, registry, dispatcher, device modules ---
$(OUTPUT_DIR)/project/app/sb_command.o: app/sb_command.c
	@$(POSIX_TOOL_PATH)echo 'Building app/sb_command.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/sb_command.c
CDEPS += $(OUTPUT_DIR)/project/app/sb_command.d
OBJS += $(OUTPUT_DIR)/project/app/sb_command.o

$(OUTPUT_DIR)/project/app/device_registry.o: app/device_registry.c
	@$(POSIX_TOOL_PATH)echo 'Building app/device_registry.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/device_registry.c
CDEPS += $(OUTPUT_DIR)/project/app/device_registry.d
OBJS += $(OUTPUT_DIR)/project/app/device_registry.o

$(OUTPUT_DIR)/project/app/device_dispatch.o: app/device_dispatch.c
	@$(POSIX_TOOL_PATH)echo 'Building app/device_dispatch.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/device_dispatch.c
CDEPS += $(OUTPUT_DIR)/project/app/device_dispatch.d
OBJS += $(OUTPUT_DIR)/project/app/device_dispatch.o

$(OUTPUT_DIR)/project/app/light_ctrl.o: app/light_ctrl.c
	@$(POSIX_TOOL_PATH)echo 'Building app/light_ctrl.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/light_ctrl.c
CDEPS += $(OUTPUT_DIR)/project/app/light_ctrl.d
OBJS += $(OUTPUT_DIR)/project/app/light_ctrl.o

$(OUTPUT_DIR)/project/app/switch_logic.o: app/switch_logic.c
	@$(POSIX_TOOL_PATH)echo 'Building app/switch_logic.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ app/switch_logic.c
CDEPS += $(OUTPUT_DIR)/project/app/switch_logic.d
OBJS += $(OUTPUT_DIR)/project/app/switch_logic.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-node.o: $(SDK_PATH)/protocol/zigbee/app/framework/security/af-node.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/security/af-node.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/security/af-node.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-node.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-node.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-security-common.o: $(SDK_PATH)/protocol/zigbee/app/framework/security/af-security-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/security/af-security-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/security/af-security-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-security-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-security-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-trust-center.o: $(SDK_PATH)/protocol/zigbee/app/framework/security/af-trust-center.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/security/af-trust-center.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/security/af-trust-center.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-trust-center.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/af-trust-center.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/crypto-state.o: $(SDK_PATH)/protocol/zigbee/app/framework/security/crypto-state.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/security/crypto-state.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/security/crypto-state.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/crypto-state.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/security/crypto-state.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/service-function/sl_service_function.o: $(SDK_PATH)/protocol/zigbee/app/framework/service-function/sl_service_function.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/service-function/sl_service_function.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/service-function/sl_service_function.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/service-function/sl_service_function.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/service-function/sl_service_function.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/signature-decode/sl_signature_decode.o: $(SDK_PATH)/protocol/zigbee/app/framework/signature-decode/sl_signature_decode.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/signature-decode/sl_signature_decode.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/signature-decode/sl_signature_decode.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/signature-decode/sl_signature_decode.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/signature-decode/sl_signature_decode.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-common.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/af-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/af-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/af-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-event.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/af-event.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/af-event.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/af-event.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-event.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-event.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/af-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/af-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/af-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/af-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-size.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-size.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-size.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-size.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-size.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-size.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-storage.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-storage.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-storage.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-storage.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-storage.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-storage.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-table.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-table.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-table.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/attribute-table.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-table.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/attribute-table.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/client-api.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/client-api.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/client-api.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/client-api.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/client-api.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/client-api.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/global-callback.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/global-callback.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/global-callback.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/global-callback.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/global-callback.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/global-callback.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/global-other-callback.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/global-other-callback.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/global-other-callback.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/global-other-callback.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/global-other-callback.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/global-other-callback.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/message.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/message.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/message.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/message.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/message.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/message.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/multi-network.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/multi-network.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/multi-network.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/multi-network.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/multi-network.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/multi-network.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/print-formatter.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/print-formatter.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/print-formatter.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/print-formatter.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/print-formatter.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/print-formatter.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/print.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/print.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/print.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/print.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/print.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/print.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/process-cluster-message.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/process-cluster-message.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/process-cluster-message.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/process-cluster-message.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/process-cluster-message.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/process-cluster-message.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/process-global-message.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/process-global-message.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/process-global-message.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/process-global-message.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/process-global-message.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/process-global-message.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/service-discovery-common.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/service-discovery-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/service-discovery-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/service-discovery-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/service-discovery-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/service-discovery-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/service-discovery-host.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/service-discovery-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/service-discovery-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/service-discovery-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/service-discovery-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/service-discovery-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/time-util.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/time-util.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/time-util.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/time-util.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/time-util.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/time-util.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/util.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/util.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/util.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/util.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/util.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/util.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/zcl-util.o: $(SDK_PATH)/protocol/zigbee/app/framework/util/zcl-util.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/framework/util/zcl-util.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/framework/util/zcl-util.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/zcl-util.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/framework/util/zcl-util.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/common/library.o: $(SDK_PATH)/protocol/zigbee/app/util/common/library.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/common/library.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/common/library.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/common/library.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/common/library.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-callbacks.o: $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-callbacks.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-callbacks.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-callbacks.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-callbacks.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-callbacks.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-enum-decode.o: $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-enum-decode.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-enum-decode.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-enum-decode.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-enum-decode.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-enum-decode.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-frame-utilities.o: $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-frame-utilities.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-frame-utilities.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp-frame-utilities.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-frame-utilities.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp-frame-utilities.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp.o: $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/ezsp/ezsp.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/ezsp.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/serial-interface-uart.o: $(SDK_PATH)/protocol/zigbee/app/util/ezsp/serial-interface-uart.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/ezsp/serial-interface-uart.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/ezsp/serial-interface-uart.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/serial-interface-uart.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/ezsp/serial-interface-uart.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/security/security-address-cache.o: $(SDK_PATH)/protocol/zigbee/app/util/security/security-address-cache.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/security/security-address-cache.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/security/security-address-cache.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/security/security-address-cache.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/security/security-address-cache.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/serial/linux-serial.o: $(SDK_PATH)/protocol/zigbee/app/util/serial/linux-serial.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/serial/linux-serial.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/serial/linux-serial.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/serial/linux-serial.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/serial/linux-serial.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/serial/sl_zigbee_command_interpreter.o: $(SDK_PATH)/protocol/zigbee/app/util/serial/sl_zigbee_command_interpreter.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/serial/sl_zigbee_command_interpreter.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/serial/sl_zigbee_command_interpreter.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/serial/sl_zigbee_command_interpreter.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/serial/sl_zigbee_command_interpreter.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/zigbee-framework/zigbee-device-common.o: $(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework/zigbee-device-common.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework/zigbee-device-common.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework/zigbee-device-common.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/zigbee-framework/zigbee-device-common.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/zigbee-framework/zigbee-device-common.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/zigbee-framework/zigbee-device-host.o: $(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework/zigbee-device-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework/zigbee-device-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/app/util/zigbee-framework/zigbee-device-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/zigbee-framework/zigbee-device-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/app/util/zigbee-framework/zigbee-device-host.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration-host-access.o: $(SDK_PATH)/protocol/zigbee/stack/config/ember-configuration-host-access.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/stack/config/ember-configuration-host-access.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/stack/config/ember-configuration-host-access.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration-host-access.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/config/ember-configuration-host-access.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/gp/gp-util.o: $(SDK_PATH)/protocol/zigbee/stack/gp/gp-util.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/stack/gp/gp-util.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/stack/gp/gp-util.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/gp/gp-util.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/gp/gp-util.o

$(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager-host.o: $(SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager-host.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager-host.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/protocol/zigbee/stack/security/zigbee-security-manager-host.c
CDEPS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager-host.d
OBJS += $(OUTPUT_DIR)/sdk/protocol/zigbee/stack/security/zigbee-security-manager-host.o

$(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/event_queue/event-queue.o: $(SDK_PATH)/util/silicon_labs/silabs_core/event_queue/event-queue.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/util/silicon_labs/silabs_core/event_queue/event-queue.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/util/silicon_labs/silabs_core/event_queue/event-queue.c
CDEPS += $(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/event_queue/event-queue.d
OBJS += $(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/event_queue/event-queue.o

$(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/memory_manager/sl_malloc.o: $(SDK_PATH)/util/silicon_labs/silabs_core/memory_manager/sl_malloc.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/util/silicon_labs/silabs_core/memory_manager/sl_malloc.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/util/silicon_labs/silabs_core/memory_manager/sl_malloc.c
CDEPS += $(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/memory_manager/sl_malloc.d
OBJS += $(OUTPUT_DIR)/sdk/util/silicon_labs/silabs_core/memory_manager/sl_malloc.o

$(OUTPUT_DIR)/sdk/util/third_party/printf/printf.o: $(SDK_PATH)/util/third_party/printf/printf.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/util/third_party/printf/printf.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/util/third_party/printf/printf.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/printf/printf.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/printf/printf.o

$(OUTPUT_DIR)/sdk/util/third_party/printf/src/iostream_printf.o: $(SDK_PATH)/util/third_party/printf/src/iostream_printf.c
	@$(POSIX_TOOL_PATH)echo 'Building $(SDK_PATH)/util/third_party/printf/src/iostream_printf.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ $(SDK_PATH)/util/third_party/printf/src/iostream_printf.c
CDEPS += $(OUTPUT_DIR)/sdk/util/third_party/printf/src/iostream_printf.d
OBJS += $(OUTPUT_DIR)/sdk/util/third_party/printf/src/iostream_printf.o

$(OUTPUT_DIR)/project/autogen/sl_cli_command_table.o: autogen/sl_cli_command_table.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_cli_command_table.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_cli_command_table.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_cli_command_table.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_cli_command_table.o

$(OUTPUT_DIR)/project/autogen/sl_cli_instances.o: autogen/sl_cli_instances.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_cli_instances.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_cli_instances.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_cli_instances.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_cli_instances.o

$(OUTPUT_DIR)/project/autogen/sl_cluster_service_gen.o: autogen/sl_cluster_service_gen.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sl_cluster_service_gen.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sl_cluster_service_gen.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sl_cluster_service_gen.d
OBJS += $(OUTPUT_DIR)/project/autogen/sl_cluster_service_gen.o

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

$(OUTPUT_DIR)/project/autogen/sli_cli_hooks.o: autogen/sli_cli_hooks.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/sli_cli_hooks.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/sli_cli_hooks.c
CDEPS += $(OUTPUT_DIR)/project/autogen/sli_cli_hooks.d
OBJS += $(OUTPUT_DIR)/project/autogen/sli_cli_hooks.o

$(OUTPUT_DIR)/project/autogen/zap-cli.o: autogen/zap-cli.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zap-cli.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zap-cli.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zap-cli.d
OBJS += $(OUTPUT_DIR)/project/autogen/zap-cli.o

$(OUTPUT_DIR)/project/autogen/zap-cluster-command-parser.o: autogen/zap-cluster-command-parser.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zap-cluster-command-parser.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zap-cluster-command-parser.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zap-cluster-command-parser.d
OBJS += $(OUTPUT_DIR)/project/autogen/zap-cluster-command-parser.o

$(OUTPUT_DIR)/project/autogen/zap-event.o: autogen/zap-event.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zap-event.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zap-event.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zap-event.d
OBJS += $(OUTPUT_DIR)/project/autogen/zap-event.o

$(OUTPUT_DIR)/project/autogen/zigbee_common_callback_dispatcher.o: autogen/zigbee_common_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_common_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_common_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_common_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_common_callback_dispatcher.o

$(OUTPUT_DIR)/project/autogen/zigbee_host_callback_dispatcher.o: autogen/zigbee_host_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_host_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_host_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_host_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_host_callback_dispatcher.o

$(OUTPUT_DIR)/project/autogen/zigbee_stack_callback_dispatcher.o: autogen/zigbee_stack_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_stack_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_stack_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_stack_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_stack_callback_dispatcher.o

$(OUTPUT_DIR)/project/autogen/zigbee_zcl_callback_dispatcher.o: autogen/zigbee_zcl_callback_dispatcher.c
	@$(POSIX_TOOL_PATH)echo 'Building autogen/zigbee_zcl_callback_dispatcher.c'
	@$(POSIX_TOOL_PATH)mkdir -p $(@D)
	$(ECHO)$(CC) $(CFLAGS) -c -o $@ autogen/zigbee_zcl_callback_dispatcher.c
CDEPS += $(OUTPUT_DIR)/project/autogen/zigbee_zcl_callback_dispatcher.d
OBJS += $(OUTPUT_DIR)/project/autogen/zigbee_zcl_callback_dispatcher.o

# Automatically-generated Simplicity Studio Metadata
# Please do not edit or delete these lines!
# SIMPLICITY_STUDIO_METADATA=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END_SIMPLICITY_STUDIO_METADATA
# END OF METADATA