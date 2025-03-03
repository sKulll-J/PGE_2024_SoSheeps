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

char uplinkPayload[30];
uint8_t downlinkPayload[10];
size_t  downlinkSize;

String buildLoRaWANPayload(double latitude, double longitude, unsigned long timestamp);

/*==================================  MAIN Program  ==================================
======================================================================================*/

void setup() {
  Serial.begin(115200);
  while(!Serial);
  delay(5000);  // Give time to switch to the serial monitor
  Serial.println(F("\n---\nSetup ... "));    
  radio_init();
  Serial.println(F("Ready!"));

  Serial.println(F("Uplink: 1"));
  int16_t state_0 = node.sendReceive("1", 1, downlinkPayload, &downlinkSize, false);   
  debug(state_0 < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state_0, false);
  if(state_0 > 0) {
    Serial.println(F("Downlink reçue"));
    Serial.println(F("Downlink: "));
    arrayDump(downlinkPayload, downlinkSize);
  }
  else{
    Serial.println(F("Pas de downlink reçue"));
  }

  Serial.println(F("attente 1min 30"));
  delay(1UL*60UL + 30UL);
}

void loop() {
  Serial.println(F("\n---\n Test coordonnées dans la salle"));
  //coordonnées dans la salle H0
  double latt = 43.5592760;
  double lonn = 1.4694470;
  unsigned long timestamp = millis();

  // Build payload byte array
  buildLoRaWANPayload(latt, lonn, timestamp, uplinkPayload);

  // send payload coordinates
  int16_t state = node.sendReceive(uplinkPayload, 1, downlinkPayload, &downlinkSize, false);   
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);

  // Check if a downlink was received 
  // (state 0 = no downlink, state 1/2 = downlink in window Rx1/Rx2)
  if(state > 0) {
    Serial.println(F("Downlink reçue"));
    Serial.println(F("Downlink: "));
    arrayDump(downlinkPayload, downlinkSize);
  }
  else{
    Serial.println(F("Pas de downlink reçue"));
  }

  Serial.print(F("attente 2min"));
  delay(2UL*60UL*1000UL);

  Serial.println(F("\n---\n Test coordonnées en dehors de la salle"));
  //coordonnées en dehors de la salle H0
  latt = 23.5592760;
  lonn = 15.4694470;
  timestamp = millis();

  // Build payload byte array
  buildLoRaWANPayload(latt, lonn, timestamp, uplinkPayload);

  // send payload coordinates
  state = node.sendReceive(uplinkPayload, 1, downlinkPayload, &downlinkSize, false);   
  debug(state < RADIOLIB_ERR_NONE, F("Error in sendReceive"), state, false);
  
  if(state > 0) {
    Serial.println(F("Downlink reçue"));
    Serial.println(F("Downlink: "));
    arrayDump(downlinkPayload, downlinkSize);
  }
  else{
    Serial.println(F("Pas de downlink reçue"));
  }
  // Wait until next uplink - observing legal & TTN FUP constraints
  delay(2UL*60UL* 1000UL);  // delay needs milli-seconds  
  
}

/*==================================   Fonctions  ====================================
======================================================================================*/
void buildLoRaWANPayload(double latitude, double longitude, unsigned long timestamp, char* payload) {
  strcpy(payload, "5:");  // Start the payload with "5:"
  char temp[30];
  
  dtostrf(latitude, 9, 7, temp);  // Convert latitude to a string
  strcat(payload, temp);
  strcat(payload, ":");

  dtostrf(longitude, 9, 7, temp);  // Convert longitude to a string
  strcat(payload, temp);
  strcat(payload, ":20:");

  strcat(payload, String(timestamp).c_str());  // Add the timestamp
}