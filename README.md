# Automatic Plant Watering System

An autonomous, sensor-driven irrigation system built with MATLAB and the Grove Beginner Kit for Arduino. This project utilizes a finite-state machine logic to maintain soil moisture, with adaptive watering durations based on indoor air quality ($eCO_2$ levels).

### Screenshots
![Screenshot 1](https://raw.githubusercontent.com/tasdidnoor/Assets/main/Plant%20Watering/README.png)
![Screenshot 2](https://raw.githubusercontent.com/tasdidnoor/Assets/main/Plant%20Watering/README2.png)
![Screenshot 3](https://raw.githubusercontent.com/tasdidnoor/Assets/main/Plant%20Watering/README3.png)

## Features
- **Reactive Control:** Automatically waters plants when soil is dry.
- **Air Quality Integration:** Adjusts watering bursts based on $eCO_2$ levels (using SGP30) to prevent fungal growth in high $CO_2$ environments.
- **Real-time Telemetry:** Live animated graphs of moisture levels in MATLAB.
- **Data Logging:** Automatically records moisture (V and %), $eCO_2$ levels, and system status to `moisture_log.csv` (see `sample_moisture_log.csv` for an example).
- **Safety First:** Dedicated physical Emergency Stop button.
- **Calibration-Ready:** Includes scripts for mapping sensor voltage to moisture percentages.

## Hardware Requirements
- **Microcontroller:** Arduino (Compatible with Grove Beginner Kit)
- **Sensors:**
  - Soil Moisture Sensor (Analog)
  - SGP30 Gas Sensor ($eCO_2/TVOC$)
- **Actuators:**
  - Water Pump (via MOSFET board)
- **Interface:**
  - Physical Button (Emergency Stop)

### Wiring Diagram (Default Pins)
| Component | Pin | type |
| :--- | :--- | :--- |
| Soil Moisture Sensor | `A1` | Analog |
| SGP30 Sensor | `I2C` | I2C |
| Water Pump (MOSFET) | `D2` | Digital Out |
| Emergency Stop Button| `D6` | Digital In |

## Software Requirements
- **MATLAB** (R2021a or newer recommended)
- **MATLAB Support Package for Arduino Hardware**

## Usage
1. Connect your Arduino and sensors according to the pin table above.
2. Ensure `sgp30.m` and `volt2mois.m` are in the same directory as the main script.
3. Open `PlantWateringSystem.m` in MATLAB.
4. Run the script. The system will initialize the Arduino connection and begin monitoring.

## Testing & Calibration
- Run `Testvolt2mois.m` to verify the moisture conversion logic.
- Use the calibration curve generated in the main script to adjust the `Dry_Soil` and `Wet_Soil` thresholds for your specific plant/soil type.

## Acknowledgments
- **SGP30 Library:** The `sgp30.m` class was developed by **Eric Prandovszky** (prandov@yorku.ca), version 0.8.1.
- **Hardware:** Developed using the Grove Beginner Kit for Arduino.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
