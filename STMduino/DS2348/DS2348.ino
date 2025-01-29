// AVEC TENSION

#include "DS2438.h"

#define ONE_WIRE_BUS 2

OneWire   oneWire(ONE_WIRE_BUS);
DS2438    bm(&oneWire);

float capa_totale = 4.0;  // Capacité nominale de la batterie en Ah
float capa_restante = 0.0;
float capa_percent = 0.0;

// Table de correspondance Tension (V) → État de charge (SoC %)
float voltageTable[] = {4.20, 3.80, 3.60, 3.40, 3.00, 2.50};  // Tension (V)
float socTable[] = {100, 60, 50, 30, 10, 0};                  // Capacité en %

/**
 * Fonction d'interpolation linéaire entre deux points.
 */
float interpolate(float value, float x1, float x2, float y1, float y2) {
  return y1 + ((value - x1) / (x2 - x1)) * (y2 - y1);
}

/**
 * Fonction pour estimer la capacité restante en fonction de la tension.
 */
float estimateSoC(float voltage) {
  for (int i = 0; i < 5; i++) {  // Parcours des segments de la table
    if (voltage <= voltageTable[i] && voltage >= voltageTable[i + 1]) {
      return interpolate(voltage, voltageTable[i], voltageTable[i + 1], socTable[i], socTable[i + 1]);
    }
  }
  // En dehors des limites, retourne 0% ou 100%
  if (voltage > voltageTable[0]) return 100.0;  // Batterie pleine
  if (voltage < voltageTable[5]) return 0.0;    // Batterie vide
  return -1;  // Erreur
}

void setup() {
  Serial.begin(115200);
  Serial.println(__FILE__);
  Serial.print("DS2438_LIB_VERSION: ");
  Serial.println(DS2438_LIB_VERSION);
  Serial.println();

  bm.begin();
  Serial.println(bm.isConnected());

  Serial.println("\nMesure de la batterie...");
}

void loop() {
  // Lecture des valeurs du DS2438
  bm.readVDD();
  float tension = bm.getVDD();  // Tension batterie (V)

   bm.setResistor(0.05);
  bm.enableCurrentMeasurement();
  delay(30);
  float courant = bm.readCurrent();  // Courant mesuré (A)

  bm.readTemperature();
  float temperature = bm.readTemperature();  // Température (°C)

  // Estimation de l'état de charge (SoC %)
  float soc = estimateSoC(tension);

  // Calcul de la capacité restante en Ah
  capa_restante = (soc / 100.0) * capa_totale;
  capa_percent = soc;

  // Affichage des résultats
  Serial.println("=== Données de la Batterie ===");

  Serial.print("Tension : ");
  Serial.print(tension);
  Serial.println(" V");

  Serial.print("Courant : ");
  Serial.print(courant);
  Serial.println(" A");

  Serial.print("Température : ");
  Serial.print(temperature);
  Serial.println(" °C");
  
  Serial.print("Capacité restante : ");
  Serial.print(capa_restante);
  Serial.println(" Ah");
  
  Serial.print("État de charge estimé : ");
  Serial.print(capa_percent);
  Serial.println(" %");

  Serial.println();

  delay(2000);
}
