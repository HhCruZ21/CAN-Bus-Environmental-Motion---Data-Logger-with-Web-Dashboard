# 🚌 CAN Bus Environmental & Motion Data Logger with Web Dashboard

> **CANLOG-01** — A portfolio embedded-systems project demonstrating end-to-end data acquisition over CAN bus, MQTT/TLS bridging, and live web visualisation.

![STM32](https://img.shields.io/badge/STM32-NUCLEO--G070RB-03234B?style=flat-square&logo=stmicroelectronics)
![ESP32](https://img.shields.io/badge/ESP32-Arduino-E7352C?style=flat-square&logo=espressif)
![Python](https://img.shields.io/badge/Python-3-3776AB?style=flat-square&logo=python)
![MQTT](https://img.shields.io/badge/MQTT-TLS-660066?style=flat-square)
![SQLite](https://img.shields.io/badge/SQLite-Database-003B57?style=flat-square&logo=sqlite)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

> 📷 *Hardware photo — to be added during Phase 1 bring-up.*

---

## 📋 Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Hardware Requirements](#2-hardware-requirements)
- [3. Software Architecture](#3-software-architecture)
- [4. Quick Start](#4-quick-start)
- [5. Repository Structure](#5-repository-structure)
- [6. Interface Specifications](#6-interface-specifications)
- [7. Development Phases and Milestones](#7-development-phases-and-milestones)
- [8. Glossary](#8-glossary)

---

## 1. Project Overview

CANLOG-01 is a system that acquires environmental and inertial sensor data on a STM32 microcontroller, transmits it over a CAN bus, bridges it to Wi-Fi via an ESP32, and persists and visualises it on a Raspberry Pi running Linux.

The project is designed to produce direct evidence for the following recurring job-description themes:

`CAN protocol` · `bare-metal STM32 C/C++` · `RTOS-free firmware` · `MQTT over TLS` · `Linux network services` · `sensor integration` · `web dashboard UI`

### 1.1 Goals

| Priority | Goal |
|----------|------|
| 🥇 **Primary** | Demonstrate end-to-end embedded systems competency from hardware bring-up through cloud-style data delivery. |
| 🥈 **Secondary** | Produce a well-documented, testable repository that can be shown to prospective employers as a complete professional artefact. |
| 🥉 **Tertiary** | Gain hands-on experience with CAN bus, MQTT/TLS, SQLite persistence, and a modern web UI framework (SolidJS or plain TypeScript). |
| 🔭 **Future — Yocto** | Raspberry Pi OS is sufficient for now; custom Linux distribution deferred. |
| 🔭 **Future — Cloud** | Local Mosquitto broker on the Pi replaces AWS IoT Core or Azure for now. |
| 🔭 **Future — ML/CV** | No machine learning or computer vision applied to sensor data in this version. |

### 1.2 Key Quality Targets

| ID | Requirement |
|----|-------------|
| NFR-01 | System runs continuously for **24 hours** without hang or reboot under normal conditions |
| NFR-02 | Sensor-to-dashboard end-to-end latency **≤ 3 seconds** on local Wi-Fi |
| NFR-03 | No CAN frame silently dropped — any TX error flagged in a fault frame |
| NFR-04 | MQTT traffic uses **TLS 1.2 minimum** between ESP32 and Pi |
| NFR-05 | Firmware compiles with **zero warnings** at `-Wall -Wextra`; no dynamic memory allocation |

---

## 2. Hardware Requirements

### 2.1 Bill of Materials — Owned

| Component | Part / Module | Role in System | Interface |
|-----------|--------------|----------------|-----------|
| MCU node | `NUCLEO-G070RB` | Sensor acquisition + CAN TX | I²C, SPI, UART, CAN |
| CAN module | `MCP2515 + TJA1050` | CAN controller + transceiver | SPI → CAN bus |
| Environment sensor | `BME280` | Temperature, humidity, pressure | I²C (0x76) |
| IMU sensor | `MPU-6050` | 3-axis accel + 3-axis gyro | I²C (0x68) |
| Wi-Fi gateway | `ESP32 dev board` | CAN RX + MQTT bridge | CAN RX, Wi-Fi |
| Debug tool | `Logic analyser (8-ch)` | CAN, I²C, SPI capture | Clip leads |
| Actuator | `5V relay module` | Threshold alert output | GPIO from NUCLEO |
| Power module | `AMS1117 3.3V` | Stable 3.3V rail for sensors | Power |
| USB-TTL adapter | `3.3V / 5V` | STM32 debug UART to PC | USB |

### 2.2 Bill of Materials — To Purchase (~€60–70)

| Component | Qty | Est. Cost | Purpose |
|-----------|-----|-----------|---------|
| Raspberry Pi 4 (2 GB) | 1 | ~€45 | Linux server: MQTT broker, SQLite, web server |
| MCP2515 CAN module (second) | 1 | ~€8 | CAN receiver node on ESP32 side |
| 120 Ω resistor | 2 | ~€0.50 | CAN bus termination at both ends |
| MicroSD 16 GB Class 10 | 1 | ~€8 | Raspberry Pi OS storage |
| SSD1306 OLED 128×64 *(optional)* | 1 | ~€5 | Local readout on NUCLEO node |

---

### 2.3 Hardware Topology

```
┌─────────────────────────────────────────────────────────────┐
│                        Node A                               │
│  BME280 ──┐                                                 │
│           ├── I²C (400 kHz) ──► NUCLEO-G070RB ──► MCP2515  │
│  MPU-6050 ┘                         │         SPI (10 MHz)  │
│                                     │                       │
│                              SPI + bxCAN                    │
└─────────────────────────────────────┼───────────────────────┘
                                      │ CAN bus (twisted pair)
                               120Ω ──┤── 120Ω
                                      │
┌─────────────────────────────────────┼───────────────────────┐
│                        Node B       ▼                       │
│                      MCP2515 ──► ESP32 ──► Wi-Fi            │
│                      SPI (10 MHz)            │              │
└──────────────────────────────────────────────┼─────────────┘
                                               │ MQTT / TLS (port 8883)
┌──────────────────────────────────────────────┼─────────────┐
│                   Raspberry Pi               ▼             │
│           Mosquitto broker ──► Python subscriber           │
│                                      │                     │
│                                  SQLite DB                 │
│                                      │                     │
│                          Flask REST API (port 5000)        │
│                          Web server / dashboard (port 8080)│
└────────────────────────────────────────────────────────────┘
```

- **BME280** and **MPU-6050** share the **I²C bus** (SCL/SDA) at 400 kHz fast mode.
- **MCP2515** connects to NUCLEO via **SPI** (SCK, MOSI, MISO, CS, INT).
- CAN nodes wired via **twisted pair** with **120 Ω termination** at each end.
- **ESP32** publishes over Wi-Fi to a **Mosquitto MQTT broker** on the Raspberry Pi.
- **Logic analyser** attaches via clip leads to I²C, SPI, or CAN lines for debugging.

For full pin-by-pin wiring tables see [`/docs/hardware_setup.md`](docs/hardware_setup.md).

---

### 2.4 Power Requirements

| Node | Voltage | Current | Source |
|------|---------|---------|--------|
| `NUCLEO-G070RB` + sensors | 3.3V / 5V | ~150 mA | USB from PC or 5V adapter |
| `ESP32` dev board | 3.3V / 5V | ~240 mA *(Wi-Fi active)* | USB or shared 5V rail |
| `Raspberry Pi 4` | 5V | ~600 mA idle / 1.2A load | Official Pi USB-C PSU |
| `5V relay module` | 5V | ~70 mA when active | Shared 5V rail |

> **Note:** Node A and Node B GNDs must be connected together even when
> powered from separate USB supplies. CAN differential signalling requires
> a common ground reference.

---

## 3. Software Architecture

> The system is divided into four software layers, each running on a distinct hardware node. All layers communicate through defined interfaces. For the full architecture narrative and design decision log see [`/docs/architecture.md`](docs/architecture.md).

### 3.1 Layer Overview

| Layer | Node | Language | Responsibility |
|-------|------|----------|----------------|
| 🔧 **Firmware (bare-metal)** | NUCLEO-G070RB | `C (C99)` | Sensor acquisition, CAN frame TX, relay control |
| 📡 **Gateway firmware** | ESP32 | `C / Arduino-C++` | CAN RX, MQTT publish over TLS, Wi-Fi management |
| 🗄️ **Backend service** | Raspberry Pi | `Python 3` | MQTT subscribe, SQLite persistence, REST API |
| 🖥️ **Frontend dashboard** | Browser (served by Pi) | `TypeScript / SolidJS` | Live + historical data visualisation |

---

### 3.2 STM32 Firmware (Node A)

<details>
<summary><strong>3.2.1 Peripheral Initialisation Requirements</strong></summary>

- **I²C1** — 400 kHz fast mode. BME280 @ `0x76`, MPU-6050 @ `0x68`.
- **SPI1** — 10 MHz for MCP2515. Chip-select on GPIO output, INT line on EXTI input.
- **bxCAN** — 500 kbit/s, normal mode. Loopback mode used only during unit testing.
- **TIM6** — 1-second periodic interrupt to trigger sensor reads.
- **USART2** — 115200 baud virtual COM via ST-Link for debug `printf` output.
- **GPIO** — 5V relay control output (active-high).

</details>

<details>
<summary><strong>3.2.2 Sensor Driver Requirements</strong></summary>

- **BME280** — Official Bosch compensation formula. Resolution: `0.01 °C` / `0.01 %RH` / `0.01 hPa`.
- **MPU-6050** — Raw 16-bit ADC via I²C. Accel ±2 g, gyro ±250 °/s. Scale factors applied. No DMP.
- Both sensors polled on 1-second timer interrupt — non-blocking (polling I²C ready flags).
- On I²C NAK: set fault flag + transmit dedicated CAN error frame. **Do not hang.**

</details>

<details>
<summary><strong>3.2.3 CAN Transmission Requirements</strong></summary>

- Transmit **one frame/second** per sensor type (2 data frames + 1 heartbeat = 3 frames/sec total).
- Standard **11-bit CAN IDs** — allocation in [Section 6.1](#61-can-id-allocation).
- Fixed **DLC = 8 bytes**. Unused bytes padded with `0x00`.
- Software transmit queue of **≥ 8 frames** to absorb bursts.
- Relay threshold: temperature > **40 °C** → assert relay GPIO. Hysteresis: **±2 °C**.

</details>

---

### 3.3 ESP32 Gateway Firmware (Node B)

<details>
<summary><strong>Expand requirements</strong></summary>

- Initialise MCP2515 via SPI at 10 MHz — accept **all** CAN frames (no hardware filter).
- Parse and deserialise CAN frame payload per [`/docs/can_frame_spec.md`](docs/can_frame_spec.md).
- Connect to local Wi-Fi SSID — credentials in provisioning header, **not hard-coded**.
- MQTT connection to Pi broker on port `8883` over TLS (self-signed CA acceptable).
- Publish each CAN frame as MQTT message per topic hierarchy in [`/docs/mqtt_topics.md`](docs/mqtt_topics.md).
- Reconnection with **exponential back-off** (base 2s, max 60s) for Wi-Fi and MQTT.
- Log all CAN frames + MQTT publishes via Serial at `115200` baud for debugging.

</details>

---

### 3.4 Raspberry Pi Backend (Python)

<details>
<summary><strong>Expand requirements</strong></summary>

- **Mosquitto** broker: port `1883` (plain, localhost) + port `8883` (TLS, network).
- **Python 3 subscriber**: connects to `localhost:1883`, persists every message to SQLite.
- **SQLite schema**: tables `sensor_bme280`, `sensor_mpu6050`, `relay_events`, `node_status`.
- **REST API** (Flask or FastAPI) on port `5000` — endpoints in [Section 6.3](#63-rest-api-endpoints).
- **Web server** serving SolidJS bundle or plain HTML on port `8080`.
- All services managed via **systemd unit files** — start on boot automatically.

</details>

---

### 3.5 Web Dashboard (Frontend)

<details>
<summary><strong>Expand requirements</strong></summary>

- Single-page application — static bundle served directly from the Pi.
- **Live panel**: polls REST API every **2 seconds** — temperature, humidity, pressure, IMU as numeric cards.
- **Historical chart**: line charts per measurement over last **1 hour** (configurable) via Chart.js.
- **Alert log**: last **20 relay trigger events** with timestamp and reason.
- Responsive layout — readable at **1024 px** desktop width. Mobile: nice-to-have.
- No authentication required for this project version.

</details>

---

## 4. Quick Start

> ⚠️ *Build instructions will be completed at the end of Phase 1 (firmware) and Phase 3 (backend/frontend) once the toolchain is confirmed. Placeholder steps are shown below.*

### 4.1 Flash Node A — STM32 Firmware

```bash
# Open in STM32CubeIDE
File → Import → Existing Projects → firmware/node_a/

# Build and flash via ST-Link
Project → Build All
Run → Debug (or Run)
```

### 4.2 Flash Node B — ESP32 Firmware

```bash
# Open in Arduino IDE 2.x
# Board: ESP32 Dev Module  Port: /dev/ttyUSB0 (or COMx)

# Copy provisioning template and fill in your Wi-Fi + broker details
cp firmware/node_b/provisioning.h.example firmware/node_b/provisioning.h

# Flash
Sketch → Upload
```

### 4.3 Set Up Raspberry Pi Backend

```bash
# On the Raspberry Pi
cd /opt
git clone https://github.com/<your-username>/canlog01.git
cd canlog01/backend

# Create virtual environment and install dependencies
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env: set DB_PATH, LOG_PATH, BROKER_HOST

# Initialise database
python3 -c "import db; db.init_schema()"

# Enable and start all services
sudo cp /opt/canlog01/backend/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable canlog-subscriber canlog-api canlog-web
sudo systemctl start canlog-subscriber canlog-api canlog-web
```

### 4.4 Build and Deploy Frontend

```bash
cd frontend
npm install
npm run build
# Built bundle output to frontend/dist/
# Web server (canlog-web.service) serves dist/ on port 8080
```

### 4.5 Verify the Pipeline

```bash
# On the Pi — subscribe to all MQTT topics
mosquitto_sub --cafile /etc/mosquitto/certs/ca.crt \
              -h localhost -p 8883 -t "canlog/#" -v

# Check SQLite is receiving data
sqlite3 /var/lib/canlog/canlog.db \
  "SELECT * FROM sensor_bme280 ORDER BY id DESC LIMIT 5;"

# Open dashboard in browser
http://<pi-ip>:8080
```

### 4.6 Run Tests

```bash
# Host-side unit tests (no hardware required)
make -C tests/unit

# Integration tests
cd tests/integration && pytest -v

# Full CI run
bash ci/run_tests.sh
```

---

## 5. Repository Structure

```
CANLOG-01/
├── README.md                        # This file
├── firmware/
│   ├── node_a/                      # STM32 CubeIDE project: drivers, CAN TX, relay logic
│   └── node_b/                      # ESP32 Arduino project: CAN RX, MQTT bridge, TLS
├── backend/                         # Python subscriber, Flask API, SQLite schema
├── frontend/                        # SolidJS / TypeScript dashboard + build script
├── tests/
│   ├── unit/                        # Unity C unit tests (host-runnable, no hardware)
│   └── integration/                 # Python MQTT mock + SQLite verification
├── debug_logs/                      # PulseView .sr, Wireshark .pcapng captures + index README
├── diagrams/                        # System architecture SVG/PNG, CAN bus topology
├── ci/                              # run_tests.sh / GitHub Actions workflow
└── docs/
    ├── architecture.md              # System narrative, data flow, design decisions
    ├── can_frame_spec.md            # Full CAN frame byte-layout specification
    ├── mqtt_topics.md               # MQTT topic hierarchy + JSON payload schemas
    └── hardware_setup.md            # Wiring diagrams, pinout tables, photos
```

> Hardware debug evidence (PulseView and Wireshark captures) is stored in
> `/debug_logs/` with a companion `README.md` explaining each file.
> These are collected during Phase 1–2 hardware bring-up.

---

## 6. Interface Specifications

### 6.1 CAN ID Allocation

> All frames use standard **11-bit IDs**, **DLC = 8 bytes**, **little-endian** byte order.
> Full byte-layout tables for every frame ID are in [`/docs/can_frame_spec.md`](docs/can_frame_spec.md).

| CAN ID | Frame Type | Producer | Rate |
|--------|-----------|----------|------|
| `0x100` | BME280 environmental data (temp / humidity / pressure) | Node A | 1 Hz |
| `0x101` | MPU-6050 accelerometer (Ax, Ay, Az raw ADC) | Node A | 1 Hz |
| `0x102` | MPU-6050 gyroscope (Gx, Gy, Gz raw ADC) | Node A | 1 Hz |
| `0x10F` | Heartbeat / node status | Node A | 1 Hz |
| `0x200` | Relay state change event | Node A | On event |
| `0x7FF` | Error / fault frame | Any node | On event |

---

### 6.2 MQTT Topic Hierarchy

> All topics follow `canlog/{node_id}/{data_type}`. All payloads are JSON UTF-8.
> Full payload schemas and QoS rationale are in [`/docs/mqtt_topics.md`](docs/mqtt_topics.md).

| Topic | QoS | Retained | Key Payload Fields |
|-------|-----|----------|--------------------|
| `canlog/node_a/bme280` | 1 | No | `ts`, `temp_c`, `humidity_pct`, `pressure_hpa`, `seq` |
| `canlog/node_a/accel` | 1 | No | `ts`, `ax_raw`, `ay_raw`, `az_raw`, `seq` |
| `canlog/node_a/gyro` | 1 | No | `ts`, `gx_raw`, `gy_raw`, `gz_raw`, `seq` |
| `canlog/node_a/heartbeat` | 0 | **Yes** | `ts`, `fw_version`, `uptime_s`, `status_flags` |
| `canlog/node_a/relay` | 2 | **Yes** | `ts`, `state`, `reason`, `temp_trigger_c` |
| `canlog/node_a/fault` | 1 | No | `ts`, `fault_code`, `fault_code_name`, `description` |

---

### 6.3 REST API Endpoints

> Base URL: `http://<pi-ip>:5000`. All responses: `{ "ok": true, "data": [...] }`.

| Method | Endpoint | Description | Query Params |
|--------|----------|-------------|-------------|
| `GET` | `/api/bme280/latest` | Most recent BME280 reading | — |
| `GET` | `/api/bme280/history` | BME280 readings over time window | `from`, `to` (ISO-8601), `limit` (default 500) |
| `GET` | `/api/imu/latest` | Most recent accel + gyro reading | — |
| `GET` | `/api/imu/history` | IMU readings over time window | `from`, `to`, `limit` |
| `GET` | `/api/relay/events` | Last N relay trigger / release events | `limit` (default 20) |
| `GET` | `/api/status` | Node heartbeat and system health | — |

---

## 7. Development Phases and Milestones

| Phase | Timeline | Deliverables | Exit Criteria |
|-------|----------|--------------|---------------|
| 🔧 **Phase 1:** Firmware bring-up | Months 1–2 | I²C drivers verified. CAN TX frames `0x100`, `0x101`, `0x102`. Relay threshold active. UART debug output. | Logic analyser confirms I²C. CAN frames visible on second node. Unit tests passing on host. |
| 📡 **Phase 2:** Gateway & broker | Months 3–4 | ESP32 receiving CAN via MCP2515. MQTT over TLS to Pi. Python writing to SQLite. systemd services boot. | Correct decoded JSON for all frame types. SQLite populating. Wireshark TLS capture in repo. |
| 🖥️ **Phase 3:** Dashboard & REST API | Months 5–6 | REST API live + historical data. Dashboard cards updating every 2s. 1-hour chart. Relay event log. | Browser shows plausible values. Chart renders. FR-10 through FR-12 verified manually. |
| ✅ **Phase 4:** Testing, hardening, docs | Months 7–8 | Full unit + integration test suite passing. All captures in repo. Complete docs. Build instructions finalised. | All Must Have FRs verified. NFR-01 (24-hour run) demonstrated. Repo in final structure. |

---

## 8. Glossary

| Term | Definition |
|------|------------|
| `bxCAN` | Basic eXtended CAN — the CAN peripheral integrated into STM32 microcontrollers. |
| `CAN` | Controller Area Network — a robust serial bus originally designed for automotive applications. |
| `DLC` | Data Length Code — the field in a CAN frame specifying the number of data bytes (0–8). |
| `DMP` | Digital Motion Processor — on-chip processor in the MPU-6050 for sensor fusion *(not used)*. |
| `EXTI` | External Interrupt — STM32 hardware mechanism for edge-triggered GPIO interrupts. |
| `HAL` | Hardware Abstraction Layer — STM32CubeIDE-generated driver library. |
| `MCP2515` | Microchip SPI-to-CAN controller IC. Pairs with a TJA1050 or similar CAN transceiver. |
| `MQTT` | Message Queuing Telemetry Transport — lightweight publish/subscribe protocol over TCP. |
| `QoS` | Quality of Service — MQTT delivery guarantee (0: fire-and-forget, 1: at least once, 2: exactly once). |
| `SNTP` | Simple Network Time Protocol — used by ESP32 to synchronise real-time clock over the network. |
| `SQLite` | Lightweight file-based SQL database used for sensor data persistence on the Raspberry Pi. |
| `TJA1050` | NXP CAN bus transceiver IC — converts differential CAN signals to TTL logic levels. |
| `TLS` | Transport Layer Security — cryptographic protocol used to secure MQTT traffic. |

---



<div align="center">

*CANLOG-01 · Confidential – Project Use Only · v1.0*

</div>