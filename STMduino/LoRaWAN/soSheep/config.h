#pragma once

#define DEBUG 1 // enable serial monitor print

// joinEUI - previous versions of LoRaWAN called this AppEUI
// for development purposes you can use all zeros - see Radiolib wiki for details
#define RADIOLIB_LORAWAN_JOIN_EUI  0x0000000000000000

// the Device EUI & two keys can be generated on the TTN console 
#ifndef RADIOLIB_LORAWAN_DEV_EUI   // Replace with your Device EUI
//#define RADIOLIB_LORAWAN_DEV_EUI    0x70B3D57ED006D44A
#define RADIOLIB_LORAWAN_DEV_EUI    0x70B3D57ED006E00F
#endif

#ifndef RADIOLIB_LORAWAN_APP_KEY   // Replace with your App Key 
//#define RADIOLIB_LORAWAN_APP_KEY   0x4D, 0x96, 0x29, 0x2D, 0xC2, 0x07, 0x9A, 0xE6, 0x84, 0x78, 0xB5, 0x90, 0x77, 0x39, 0x8E, 0x29
#define RADIOLIB_LORAWAN_APP_KEY  0x07, 0x80, 0x05, 0xAF, 0x69, 0x5E, 0x66, 0x73, 0xF0, 0xA5, 0x82, 0x19, 0xC9, 0x70, 0x0A, 0x71
#endif

#ifndef RADIOLIB_LORAWAN_NWK_KEY   // Put your Nwk Key here
//#define RADIOLIB_LORAWAN_NWK_KEY   0xE6, 0x9F, 0xED, 0x8E, 0xFC, 0x44, 0xA7, 0x1C, 0xE4, 0x5F, 0x48, 0x78, 0xB8, 0xF3, 0x5A, 0x9C
#define RADIOLIB_LORAWAN_NWK_KEY     0x54, 0xB7, 0xB6, 0xC8, 0xA1, 0xBE, 0x45, 0xB9, 0x00, 0x01, 0xE8, 0x87, 0xB5, 0x15, 0x20, 0xB0
#endif
