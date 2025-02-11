/*
  RadioLib LoRaWAN ABP Example

  ABP = Activation by Personalisation, an alternative
  to OTAA (Over the Air Activation). OTAA is preferable.

  This example will send uplink packets to a LoRaWAN network. 
  Before you start, you will have to register your device at 
  https://www.thethingsnetwork.org/
  After your device is registered, you can run this example.
  The device will join the network and start uploading data.

  LoRaWAN v1.0.4/v1.1 requires the use of persistent storage.
  As this example does not use persistent storage, running this 
  examples REQUIRES you to check "Resets frame counters"
  on your LoRaWAN dashboard. Refer to the notes or the 
  network's documentation on how to do this.
  To comply with LoRaWAN's persistent storage, refer to
  https://github.com/radiolib-org/radiolib-persistence

  For default module settings, see the wiki page
  https://github.com/jgromes/RadioLib/wiki/Default-configuration

  For full API reference, see the GitHub Pages
  https://jgromes.github.io/RadioLib/

  For LoRaWAN details, see the wiki page
  https://github.com/jgromes/RadioLib/wiki/LoRaWAN

*/

#include "radio.h"
#include <DFRobot_GNSS.h>

// GPS instanciation
DFRobot_GNSS_I2C gnss(&Wire ,GNSS_DEVICE_ADDR);

void encodeCoordinates(double latitude, double longitude, uint8_t* payload);
void GPS_init();

/*==================================  MAIN Program  ==================================
======================================================================================*/
void setup() {
  Serial.begin(115200);
  while(!Serial);
  delay(5000);  // Give time to switch to the serial monitor

  Serial.println("\nSetup ... ");
  radio_init();
  GPS_init();
  Serial.println(F("Ready!\n"));
}


void loop() {
  uint8_t uplinkPayload[8];
  uint8_t downlinkPayload[10];
  size_t  downlinkSize;  

  /* acquire GPS coordinates
  sLonLat_t lat = gnss.getLat();
  sLonLat_t lon = gnss.getLon();*/

  // Build payload byte array
  double lat = 43.4821567;
  double lon = 89.1572446;

  encodeCoordinates(lat, lon, uplinkPayload);
  //encodeCoordinates(lat.latitude, lon.lonitude, uplinkPayload);
  
  // Perform an uplink
  Serial.println(F("Sending uplink"));
  //int16_t state = node.sendReceive(uplinkPayload, sizeof(uplinkPayload), 8, downlinkPayload, &down_len);    
  int16_t state = node.sendReceive(uplinkPayload, sizeof(uplinkPayload), 1, downlinkPayload, &downlinkSize, false);
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);
  
  // Check if a downlink was received 
  // (state 0 = no downlink, state 1/2 = downlink in window Rx1/Rx2)
  if(state > 0) {
    Serial.println(F("Received a downlink"));
    Serial.println(F("Downlink data: "));
    arrayDump(downlinkPayload, downlinkSize);
  } else {
    Serial.println(F("No downlink received"));
  }

  Serial.print(F("Next uplink in "));
  Serial.print(uplinkIntervalSeconds);
  Serial.println(F(" seconds\n"));
  
  // Wait until next uplink - observing legal & TTN FUP constraints
  delay(uplinkIntervalSeconds * 1000UL);  // delay needs milli-seconds
}

/*==================================  Functions  ====================================
====================================================================================*/
void GPS_init(){
  Wire.setSDA(PB9);
  Wire.setSCL(PB8);
  Wire.begin(); 
  if(!gnss.begin()){
    Serial.println(F("no GPS device\n"));
  }
  else {
    Serial.println(F("GPS ready\n"));
    gnss.enablePower();
  }
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

  // Print the payload for verification
  Serial.print("Payload: ");
  for (int i = 0; i < 8; i++) {
      Serial.print(payload[i], HEX);
      if (i < 7) Serial.print(" ");
  }
  Serial.println();
}