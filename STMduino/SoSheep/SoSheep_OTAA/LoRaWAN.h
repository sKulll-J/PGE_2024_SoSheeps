#pragma once

extern uint64_t joinEUI;
extern uint64_t devEUI;
extern uint8_t appKey[];
extern uint8_t nwkKey[];

// joinEUI - previous versions of LoRaWAN called this AppEUI
// for development purposes you can use all zeros - see Radiolib wiki for details
#define RADIOLIB_LORAWAN_JOIN_EUI  0x0000000000000000

// the Device EUI & two keys can be generated on the TTN console, fill as needed
#ifndef RADIOLIB_LORAWAN_DEV_EUI    // Device EUI
  #define RADIOLIB_LORAWAN_DEV_EUI    0x----------------
#endif
#ifndef RADIOLIB_LORAWAN_APP_KEY   // App Key 
  #define RADIOLIB_LORAWAN_APP_KEY    0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--
#endif
#ifndef RADIOLIB_LORAWAN_NWK_KEY    // Nwk Key
  #define RADIOLIB_LORAWAN_NWK_KEY    0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--, 0x--
#endif

// regional choices: EU868, US915, AU915, AS923, AS923_2, AS923_3, AS923_4, IN865, KR920, CN500
const LoRaWANBand_t Region = EU868;
const uint8_t subBand = 0;  // For US915, change this to 2, otherwise leave on 0