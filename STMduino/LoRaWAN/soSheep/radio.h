#pragma once

#include "config.h"
#include <SPI.h>
#include <RadioLib.h>

// Radio module pins
#define MOSI_PIN  PB5   
#define MISO_PIN  PB4
#define SCLK_PIN  PB3   
#define CS_PIN    PA8   

#define RST_PIN   PB1

#define G0_PIN    PB13
#define G1_PIN    PB14

// SPI Bus config
SPIClass etx_spi( MOSI_PIN, MISO_PIN, SCLK_PIN );
SPISettings spi_Settings(2000000, MSBFIRST, SPI_MODE0);

// setting the radio model and pin configuration : RFM96W + SPI configuration
SX1276 radio = new Module(CS_PIN, G0_PIN, RST_PIN, G1_PIN, etx_spi, spi_Settings);

// regional choices: EU868, US915, AU915, AS923, AS923_2, AS923_3, AS923_4, IN865, KR920, CN500
const LoRaWANBand_t Region = EU868;
const uint8_t subBand = 0;  // For US915, change this to 2, otherwise leave on 0

// ============================================================================
// Below is to support the sketch - only make changes if the notes say so ...

// copy over the EUI's & keys in to the something that will not compile if incorrectly formatted
uint64_t joinEUI =   RADIOLIB_LORAWAN_JOIN_EUI;
uint64_t devEUI  =   RADIOLIB_LORAWAN_DEV_EUI;
uint8_t appKey[] = { RADIOLIB_LORAWAN_APP_KEY };
uint8_t nwkKey[] = { RADIOLIB_LORAWAN_NWK_KEY };

// create the LoRaWAN node
LoRaWANNode node(&radio, &Region, subBand);

// result code to text - these are error codes that can be raised when using LoRaWAN
// however, RadioLib has many more - see https://jgromes.github.io/RadioLib/group__status__codes.html for a complete list
String stateDecode(const int16_t result) {
  switch (result) {
  case RADIOLIB_ERR_NONE:
    return "ERR_NONE";
  case RADIOLIB_ERR_CHIP_NOT_FOUND:
    return "ERR_CHIP_NOT_FOUND";
  case RADIOLIB_ERR_PACKET_TOO_LONG:
    return "ERR_PACKET_TOO_LONG";
  case RADIOLIB_ERR_RX_TIMEOUT:
    return "ERR_RX_TIMEOUT";
  case RADIOLIB_ERR_CRC_MISMATCH:
    return "ERR_CRC_MISMATCH";
  case RADIOLIB_ERR_INVALID_BANDWIDTH:
    return "ERR_INVALID_BANDWIDTH";
  case RADIOLIB_ERR_INVALID_SPREADING_FACTOR:
    return "ERR_INVALID_SPREADING_FACTOR";
  case RADIOLIB_ERR_INVALID_CODING_RATE:
    return "ERR_INVALID_CODING_RATE";
  case RADIOLIB_ERR_INVALID_FREQUENCY:
    return "ERR_INVALID_FREQUENCY";
  case RADIOLIB_ERR_INVALID_OUTPUT_POWER:
    return "ERR_INVALID_OUTPUT_POWER";
  case RADIOLIB_ERR_NETWORK_NOT_JOINED:
	  return "RADIOLIB_ERR_NETWORK_NOT_JOINED";
  case RADIOLIB_ERR_DOWNLINK_MALFORMED:
    return "RADIOLIB_ERR_DOWNLINK_MALFORMED";
  case RADIOLIB_ERR_INVALID_REVISION:
    return "RADIOLIB_ERR_INVALID_REVISION";
  case RADIOLIB_ERR_INVALID_PORT:
    return "RADIOLIB_ERR_INVALID_PORT";
  case RADIOLIB_ERR_NO_RX_WINDOW:
    return "RADIOLIB_ERR_NO_RX_WINDOW";
  case RADIOLIB_ERR_INVALID_CID:
    return "RADIOLIB_ERR_INVALID_CID";
  case RADIOLIB_ERR_UPLINK_UNAVAILABLE:
    return "RADIOLIB_ERR_UPLINK_UNAVAILABLE";
  case RADIOLIB_ERR_COMMAND_QUEUE_FULL:
    return "RADIOLIB_ERR_COMMAND_QUEUE_FULL";
  case RADIOLIB_ERR_COMMAND_QUEUE_ITEM_NOT_FOUND:
    return "RADIOLIB_ERR_COMMAND_QUEUE_ITEM_NOT_FOUND";
  case RADIOLIB_ERR_JOIN_NONCE_INVALID:
    return "RADIOLIB_ERR_JOIN_NONCE_INVALID";
  case RADIOLIB_ERR_N_FCNT_DOWN_INVALID:
    return "RADIOLIB_ERR_N_FCNT_DOWN_INVALID";
  case RADIOLIB_ERR_A_FCNT_DOWN_INVALID:
    return "RADIOLIB_ERR_A_FCNT_DOWN_INVALID";
  case RADIOLIB_ERR_DWELL_TIME_EXCEEDED:
    return "RADIOLIB_ERR_DWELL_TIME_EXCEEDED";
  case RADIOLIB_ERR_CHECKSUM_MISMATCH:
    return "RADIOLIB_ERR_CHECKSUM_MISMATCH";
  case RADIOLIB_ERR_NO_JOIN_ACCEPT:
    return "RADIOLIB_ERR_NO_JOIN_ACCEPT";
  case RADIOLIB_LORAWAN_SESSION_RESTORED:
    return "RADIOLIB_LORAWAN_SESSION_RESTORED";
  case RADIOLIB_LORAWAN_NEW_SESSION:
    return "RADIOLIB_LORAWAN_NEW_SESSION";
  case RADIOLIB_ERR_NONCES_DISCARDED:
    return "RADIOLIB_ERR_NONCES_DISCARDED";
  case RADIOLIB_ERR_SESSION_DISCARDED:
    return "RADIOLIB_ERR_SESSION_DISCARDED";
  }
  return "See https://jgromes.github.io/RadioLib/group__status__codes.html";
}

// helper function to display any issues
#if DEBUG
void debug(bool failed, const __FlashStringHelper* message, int state, bool halt) {
  if(failed) {
    #if DEBUG
      Serial.print(message);
      Serial.print(" - ");
      Serial.print(stateDecode(state));
      Serial.print(" (");
      Serial.print(state);
      Serial.println(")");
    #endif
    while(halt) { delay(1); }
  }
}
#endif


// helper function to display a byte array
void arrayDump(uint8_t *buffer, uint16_t len) {
  for(uint16_t c = 0; c < len; c++) {
    char b = buffer[c];
    if(b < 0x10) { Serial.print('0'); }
    Serial.print(b, HEX);
  }
  Serial.println();
}

// radio initialization function
void radio_init(){
  etx_spi.setSCLK(SCLK_PIN);
  etx_spi.setMOSI(MOSI_PIN);
  etx_spi.setMISO(MISO_PIN);
  etx_spi.begin(); 
  pinMode(CS_PIN, OUTPUT); 
  digitalWrite(CS_PIN, HIGH);


  #if DEBUG
    Serial.println(F("Initialise the radio"));
  #endif

  int16_t state = radio.begin();
    #if DEBUG
      debug(state != RADIOLIB_ERR_NONE, F("Initialise radio failed"), state, true);
    #endif
  
  // Setup the OTAA session information
  state = node.beginOTAA(joinEUI, devEUI, nwkKey, appKey);
    #if DEBUG
      debug(state != RADIOLIB_ERR_NONE, F("Initialise node failed"), state, true);
    #endif
  
  #if DEBUG
    Serial.println(F("Join ('login') the LoRaWAN Network"));
  #endif

  state = node.activateOTAA();
    #if DEBUG
      debug(state != RADIOLIB_LORAWAN_NEW_SESSION, F("Join failed"), state, true);
    #endif
}

// Function to encode double coordinates into a uint8_t array
void encodeCoordinates(double latitude, double longitude, uint8_t* payload) {
  int32_t lat = latitude * 1e7;
  int32_t lon = longitude * 1e7;

  // Encode latitude into the payload array (4 bytes)
  payload[0] = (lat >> 24) & 0xFF;
  payload[1] = (lat >> 16) & 0xFF;
  payload[2] = (lat >> 8) & 0xFF;
  payload[3] = lat & 0xFF;

  // Encode longitude into the payload array (4 bytes)
  payload[4] = (lon >> 24) & 0xFF;
  payload[5] = (lon >> 16) & 0xFF;
  payload[6] = (lon >> 8) & 0xFF;
  payload[7] = lon & 0xFF;
  
  #if DEBUG // Print the payload for verification
    Serial.print("Payload: ");
    for (int i = 0; i < 8; i++) {
      Serial.print(payload[i], HEX);
      if (i < 7) Serial.print(" ");
    }
    Serial.println();
  #endif
}

void encodeCoordinates(double latitude, double longitude, uint8_t nb_sat, uint8_t batt_level, uint8_t* payload) {
  int32_t lat = latitude * 1e7;
  int32_t lon = longitude * 1e7;

  // Encode latitude into the payload array (4 bytes)
  payload[0] = (lat >> 24) & 0xFF;
  payload[1] = (lat >> 16) & 0xFF;
  payload[2] = (lat >> 8) & 0xFF;
  payload[3] = lat & 0xFF;

  // Encode longitude into the payload array (4 bytes)
  payload[4] = (lon >> 24) & 0xFF;
  payload[5] = (lon >> 16) & 0xFF;
  payload[6] = (lon >> 8) & 0xFF;
  payload[7] = lon & 0xFF;

  // Encode satellites number
  payload[8] = nb_sat ;
  
  // Encode battery level
  payload[9] = batt_level ;
  
  #if DEBUG // Print the payload for verification
    Serial.print("Payload: ");
    for (int i = 0; i < 8; i++) {
      Serial.print(payload[i], HEX);
      if (i < 7) Serial.print(" ");
    }
    Serial.println();
  #endif
}

// downlink decoder function
bool mod_in(uint8_t *buffer, uint16_t len) {
  for (uint16_t c = 0; c < len; c++) {
    if (buffer[c] == 0x01) {
      return true;
    }
    else if (buffer[c] == 0x00) 
      return false;
  }
  return true;
}

