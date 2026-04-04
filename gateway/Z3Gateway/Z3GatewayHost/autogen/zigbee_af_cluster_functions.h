/*******************************************************************************
 * @file zigbee_af_cluster_functions.h
 * @brief Cluster action callback definitions
 *******************************************************************************
 * # License
 * <b>Copyright 2020 Silicon Laboratories Inc. www.silabs.com</b>
 *******************************************************************************
 *
 * The licensor of this software is Silicon Laboratories Inc. Your use of this
 * software is governed by the terms of Silicon Labs Master Software License
 * Agreement (MSLA) available at
 * www.silabs.com/about-us/legal/master-software-license-agreement. This
 * software is distributed to you in Source Code format and is governed by the
 * sections of the MSLA applicable to Source Code.
 *
 ******************************************************************************/
//
// *** Generated file. Do not edit! ***
//

#include "af.h"


void emberAfColorControlClusterServerInitCallback (uint8_t endpoint);
void emberAfIasZoneClusterClientInitCallback (uint8_t endpoint);
void emberAfIdentifyClusterServerInitCallback (uint8_t endpoint);
void emberAfIdentifyClusterServerAttributeChangedCallback (uint8_t endpoint, EmberAfAttributeId attributeId);
void emberAfLevelControlClusterServerInitCallback (uint8_t endpoint);
void emberAfOnOffClusterServerInitCallback (uint8_t endpoint);
void emberAfOtaBootloadClusterServerInitCallback (uint8_t endpoint);
void emberAfTimeClusterServerInitCallback (uint8_t endpoint);
EmberAfStatus emberAfTimeClusterServerPreAttributeChangedCallback (uint8_t endpoint, EmberAfAttributeId attributeId, EmberAfAttributeType attributeType, uint8_t size, uint8_t * value);

// Array of cluster function (aka cluster action callbacks) structures.
// Last entry is a dummy, otherwise an empty array would fail IAR builds.
#define GENERATED_FUNCTION_STRUCTURES_ARRAY  { \
  {\
    768u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfColorControlClusterServerInitCallback\
  },\
  {\
    1280u,\
    (CLUSTER_MASK_CLIENT | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfIasZoneClusterClientInitCallback\
  },\
  {\
    3u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfIdentifyClusterServerInitCallback\
  },\
  {\
    3u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_ATTRIBUTE_CHANGED_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfIdentifyClusterServerAttributeChangedCallback\
  },\
  {\
    8u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfLevelControlClusterServerInitCallback\
  },\
  {\
    6u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfOnOffClusterServerInitCallback\
  },\
  {\
    25u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfOtaBootloadClusterServerInitCallback\
  },\
  {\
    10u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_INIT_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfTimeClusterServerInitCallback\
  },\
  {\
    10u,\
    (CLUSTER_MASK_SERVER | CLUSTER_MASK_PRE_ATTRIBUTE_CHANGED_FUNCTION),\
    (EmberAfGenericClusterFunction)emberAfTimeClusterServerPreAttributeChangedCallback\
  },\
  { 0x8000u,\
    0x00u,\
    (EmberAfGenericClusterFunction)((void *)0)\
  }\
}


// The following structure is not used anywhere in the code, its purpose is 
// compile-time detection of duplicate cluster action callbacks.
// Only a single instance of a given callback type (e.g. default_response_function)
// can exist for a given cluster and side (client/server).
// A compilation error in this structure indicates a duplicate "cluster_functions"
// template contribution.

struct unused_structure {
int clust_768_server_init_function; 
int clust_1280_client_init_function; 
int clust_3_server_init_function; 
int clust_3_server_attribute_changed_function; 
int clust_8_server_init_function; 
int clust_6_server_init_function; 
int clust_25_server_init_function; 
int clust_10_server_init_function; 
int clust_10_server_pre_attribute_changed_function;
};

