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
//#include <EEPROM.h>

// GPS instanciation
DFRobot_GNSS_I2C gnss(&Wire ,GNSS_DEVICE_ADDR);

uint32_t uplinkIntervalSeconds;
int ADR = 0 ; // EEPROM address to store the SLEEP time

// Function prototypes
void encodeCoordinates(double latitude, double longitude, uint8_t* payload);
void GPS_init();

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
  //SLEEP = EEPROM.read(ADR); 
  
  Serial.println(F("\n---\nSending uplink"));
  uint8_t uplinkPayload[8];
  uint8_t downlinkPayload[10];
  size_t  downlinkSize;  
  
  //acquire GPS coordinates 
  /*
  sLonLat_t lat = gnss.getLat();
  sLonLat_t lon = gnss.getLon();
  */
  
  double latt = 43.5592760;
  double lonn = 10.4694470;

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

    if (!mod_in(downlinkPayload, downlinkSize)){ 
      // sheeps breaking out !!!
      Serial.println(F("sheep breaking out!!!"));
      if(SLEEP != 15){
        SLEEP = 15;
        //EEPROM.write(ADR, SLEEP);
      } 
      uplinkIntervalSeconds = SLEEP * 60UL;
    } else{
      // all good
      Serial.println(F("all good"));
      if(SLEEP != 60){
        SLEEP = 60;
        //EEPROM.write(ADR, SLEEP);
      }
      uplinkIntervalSeconds = SLEEP * 60UL;
    }
  } else {
    // no changes - need to store sleep time in NVRAM
    Serial.println(F("No downlink received"));
    uplinkIntervalSeconds = SLEEP * 60UL;
  }

  Serial.print(F("Next uplink in "));
  Serial.print(uplinkIntervalSeconds);
  Serial.println(F(" seconds\n---\n"));
  
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