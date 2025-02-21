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

#include "STM32LowPower.h"
#include "config.h"
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
  #if DEBUG
    Serial.begin(115200);
    while(!Serial);
    delay(5000);  // Give time to switch to the serial monitor
    Serial.println(F("---\nSetup ... "));    
  #endif
  
  radio_init();
  GPS_init();
  BMS_init(&tension, &SoC);

  #if DEBUG
    Serial.println(F("Ready!"));
  #endif
}

void loop() {  
  uint8_t battery = getBatteryCharge();

  //acquire GPS coordinates 
  sLonLat_t position ;
  locate(&position) ;

  #if DEBUG
    Serial.println(F("\n---\nSending uplink"));
  #endif

  uint8_t uplinkPayload[10];
  uint8_t downlinkPayload[10];
  size_t  downlinkSize;  

  // Build payload byte array
  encodeCoordinates(position.latitude, position.lonitude, get_nbSat(), battery, uplinkPayload);

  // send GPS coordinates
  int16_t state = node.sendReceive(uplinkPayload, sizeof(uplinkPayload), 1, downlinkPayload, &downlinkSize, false);   
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);

  // Check if a downlink was received 
    // (state 0 = no downlink, state 1/2 = downlink in window Rx1/Rx2)
    if(state > 0) {
      #if DEBUG
        Serial.println(F("Received a downlink"));
        Serial.println(F("Downlink data: "));
        arrayDump(downlinkPayload, downlinkSize);
      #endif
    }
  
  // Change sleep time
  CoordGPS Point {
    position.latitude, position.lonitude
  };

  if ( estDansPolygone(Point, predefinedZone.sommets, predefinedZone.vertexCount) == 1 ){
    Serial.println(F("inside"));
    uplinkIntervalSeconds = 5 * 60UL;
  }
  else{
    Serial.println(F("outside"));
    uplinkIntervalSeconds = 2 * 60UL;
  }
  
  #if DEBUG
    Serial.print(F("Next uplink in "));
    Serial.print(uplinkIntervalSeconds);
    Serial.println(F(" seconds\n---\n"));
  #endif

  // Wait until next uplink - observing legal & TTN FUP constraints
  delay(uplinkIntervalSeconds * 1000UL);  // delay needs milli-seconds  
  
}
