#pragma once

#include <RadioLib.h>
#include "LoRaWAN.h"

// RFM9x pin configuration
#define MOSI_PIN  PB5  
#define MISO_PIN  PB4   
#define SCLK_PIN  PB3   

#define CS_PIN    PA8   
#define RST_PIN   PB1

#define G0_PIN    PB13
#define G1_PIN    PB14

// result code to text - these are error codes that can be raised when using LoRaWAN
// however, RadioLib has many more - see https://jgromes.github.io/RadioLib/group__status__codes.html for a complete list
String stateDecode(const int16_t result);

// helper function to display any issues
void debug(bool failed, const __FlashStringHelper* message, int state, bool halt);

// helper function to display a byte array
void arrayDump(uint8_t *buffer, uint16_t len);

// initialization function in setup()
void radio_init(SPIClass etx_spi, SPISettings spi_Settings, SX1276 radio, LoRaWANNode node );

