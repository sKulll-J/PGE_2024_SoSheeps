/*
  RadioLib LoRaWAN Starter Example

  ! Please refer to the included notes to get started !

  This example joins a LoRaWAN network and will send
  uplink packets. Before you start, you will have to
  register your device at https://www.thethingsnetwork.org/
  After your device is registered, you can run this example.
  The device will join the network and start uploading data.

  Running this examples REQUIRES you to check "Resets DevNonces"
  on your LoRaWAN dashboard. Refer to the network's 
  documentation on how to do this.

  For default module settings, see the wiki page
  https://github.com/jgromes/RadioLib/wiki/Default-configuration

  For full API reference, see the GitHub Pages
  https://jgromes.github.io/RadioLib/

  For LoRaWAN details, see the wiki page
  https://github.com/jgromes/RadioLib/wiki/LoRaWAN

*/

#include "radio.h"
#include <DFRobot_GNSS.h>

#define DEBUG // enable debugging messages in serial monitor

// Radio module and LoRaWAN instanciations
  SPIClass etx_spi( MOSI_PIN, MISO_PIN, SCLK_PIN );
  SPISettings spi_Settings(2000000, MSBFIRST, SPI_MODE0);
  SX1276 radio = new Module(CS_PIN, G0_PIN, RST_PIN, G1_PIN, etx_spi, spi_Settings);
  LoRaWANNode node(&radio, &Region, subBand);

// GPS instanciation
  DFRobot_GNSS_I2C gnss(&Wire ,GNSS_DEVICE_ADDR);

// how often to send an uplink - consider legal & FUP constraints - see notes
const uint32_t uplinkIntervalSeconds = 5UL * 60UL;    // minutes x seconds

void encodeCoordinates(double latitude, double longitude, uint8_t* payload);

/*==================================  MAIN Program  ==================================
======================================================================================*/
void setup() {
  #ifdef DEBUG
    Serial.begin(115200);
    while(!Serial);
    delay(5000);  // Give time to switch to the serial monitor
    Serial.println(F("\n---\nSetup ... "));
  #endif
  
  radio_init(etx_spi, spi_Settings, radio, node);

  Wire.setSDA(PB8); // GPS SDA
  Wire.setSCL(PB9); // GPS SCL
  Wire.begin();

  if(!gnss.begin()){
    #ifdef DEBUG
      Serial.println(F("no GPS device\n"));
    #endif
  }
  else {
    #ifdef DEBUG
      Serial.println(F("GPS ready\n"));
    #endif
    gnss.enablePower();
  }
  Serial.println(F("Ready!\n"));
}

void loop() {
  #ifdef DEBUG
    Serial.println(F("Sending uplink"));
  #endif
  // acquire GPS coordinates
  gnss.setRgbOn();
  sLonLat_t lat = gnss.getLat();
  sLonLat_t lon = gnss.getLon();
  gnss.setRgbOff();

  // Build payload byte array
  uint8_t uplinkPayload[8];
  encodeCoordinates(lat.latitude, lon.lonitude, uplinkPayload);
  
  // Perform an uplink
  int16_t state = node.sendReceive(uplinkPayload, sizeof(uplinkPayload));    
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);

  // Check if a downlink was received 
  // (state 0 = no downlink, state 1/2 = downlink in window Rx1/Rx2)
  if(state > 0) {
    Serial.println(F("Received a downlink"));
  } else {
    Serial.println(F("No downlink received"));
  }

  #ifdef DEBUG
    Serial.print(F("Next uplink in "));
    Serial.print(uplinkIntervalSeconds);
    Serial.println(F(" seconds\n"));
  #endif

  // Wait until next uplink - observing legal & TTN FUP constraints
  delay(uplinkIntervalSeconds * 1000UL);  // delay needs milli-seconds
}

/*==================================  Functions  ====================================
====================================================================================*/
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

  #ifdef DEBUG
  // Print the payload for verification
  Serial.print("Payload: ");
  for (int i = 0; i < 8; i++) {
      Serial.print(payload[i], HEX);
      if (i < 7) Serial.print(" ");
  }
  Serial.println();
  #endif

}
