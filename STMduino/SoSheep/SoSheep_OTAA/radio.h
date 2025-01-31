#pragma once

#include <RadioLib.h>
#include <SPI.h>
#include "LoRaWAN.h"

#define MOSI_PIN  PB5   //MOSI Pin
#define MISO_PIN  PB4   //MISO Pin
#define SCLK_PIN  PB3   //Clock Pin

#define CS_PIN    PA8   //Chip Select 
#define RST_PIN   PB1

#define G0_PIN    PB13
#define G1_PIN    PB14

// RFM9x initialization function
void radio_init(SPIClass etx_spi, SPISettings spi_Settings, SX1276 radio, LoRaWANNode node );

// ============================================================================
// Below is to support the sketch - only make changes if the notes say so ...

// result code to text - these are error codes that can be raised when using LoRaWAN
// however, RadioLib has many more - see https://jgromes.github.io/RadioLib/group__status__codes.html for a complete list
String stateDecode(const int16_t result);

// helper function to display any issues
void debug(bool failed, const __FlashStringHelper* message, int state, bool halt);

// helper function to display a byte array
void arrayDump(uint8_t *buffer, uint16_t len);
