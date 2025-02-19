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
#include "GPS.h"
#include "BMS.h"

/* -- Global variables --------------------------------------------------------------- */
uint32_t uplinkIntervalSeconds;

float SoC = 0.0 ;     // état de charge initial
float tension = 0.0 ; // Tension initiale

/*==================================  MAIN Program  ==================================
======================================================================================*/

void setup() {
  Serial.begin(115200);
  while(!Serial);
  delay(5000);  // Give time to switch to the serial monitor
  Serial.println(F("\n---\nSetup ... "));    

  radio_init();
  GPS_init();
  
  Serial.println(F("Ready!"));
}

void loop() {
  int SLEEP = 5;
  
  Serial.println(F("\n---\nSending uplink"));
  uint8_t uplinkPayload[8];
  uint8_t downlinkPayload[10];
  size_t  downlinkSize;  
  
  //acquire GPS coordinates 
  //sLonLat_t lat, lon ;
  //locate(&lat, &lon) ;
  
  double latt = 43.5592760;
  double lonn = 1.4694470;

  // Build payload byte array
  //encodeCoordinates(lat.latitude, lon.lonitude, uplinkPayload);
  encodeCoordinates(latt, lonn, uplinkPayload);

  // send GPS coordinates
  int16_t state = node.sendReceive(uplinkPayload, sizeof(uplinkPayload));   
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);
  delay(5UL*1000UL);

  // send sleep time request
  uint8_t cmdPayload = 24;
  state = node.sendReceive(&cmdPayload, sizeof(cmdPayload), 1, downlinkPayload, &downlinkSize, false);
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);

  // Check if a downlink was received 
  // (state 0 = no downlink, state 1/2 = downlink in window Rx1/Rx2)
  if(state > 0) {
    Serial.println(F("Received a downlink"));
    Serial.println(F("Downlink data: "));
    arrayDump(downlinkPayload, downlinkSize);
  }

  Serial.print(F("Next uplink in "));
  Serial.print(uplinkIntervalSeconds);
  Serial.println(F(" seconds\n---\n"));
  
  // Wait until next uplink - observing legal & TTN FUP constraints
  delay(uplinkIntervalSeconds * 1000UL);  // delay needs milli-seconds  
  
}
