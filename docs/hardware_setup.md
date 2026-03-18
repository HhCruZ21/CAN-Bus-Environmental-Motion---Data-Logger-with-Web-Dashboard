# Hardware Setup — CANLOG-01

> **Document status:** Draft v1.0 · Pre-development  
> **Last updated:** 2026-03  
> **Relates to:** `architecture.md`, `/docs/can_frame_spec.md`, `README.md`

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Components and Identification](#2-components-and-identification)
- [3. Voltage and Logic Level Reference](#3-voltage-and-logic-level-reference)
- [4. Node A — NUCLEO-G070RB Wiring](#4-node-a--nucleo-g070rb-wiring)
  - [4.1 BME280 (I²C)](#41-bme280-i2c)
  - [4.2 MPU-6050 (I²C)](#42-mpu-6050-i2c)
  - [4.3 MCP2515 CAN Module (SPI)](#43-mcp2515-can-module-spi)
  - [4.4 5V Relay Module (GPIO)](#44-5v-relay-module-gpio)
  - [4.5 SSD1306 OLED (optional, I²C)](#45-ssd1306-oled-optional-i2c)
  - [4.6 Debug UART](#46-debug-uart)
- [5. Node B — ESP32 Wiring](#5-node-b--esp32-wiring)
  - [5.1 MCP2515 CAN Module (SPI)](#51-mcp2515-can-module-spi)
- [6. CAN Bus Wiring](#6-can-bus-wiring)
- [7. Raspberry Pi Setup](#7-raspberry-pi-setup)
- [8. Full System Pinout Summary](#8-full-system-pinout-summary)
- [9. Power Supply Plan](#9-power-supply-plan)
- [10. Hardware Verification Checklist](#10-hardware-verification-checklist)
- [11. Common Wiring Mistakes](#11-common-wiring-mistakes)
- [12. Photo Log](#12-photo-log)

---

## 1. Overview

The physical system consists of three boards and one bus:

- **Node A** — NUCLEO-G070RB with two I²C sensors, one SPI CAN module,
  one relay module, and an optional OLED display.
- **Node B** — ESP32 dev board with one SPI CAN module.
- **CAN bus** — twisted-pair wire connecting the TJA1050 transceivers
  on both nodes, terminated with 120 Ω resistors at each end.
- **Raspberry Pi 4** — connected to the local Wi-Fi network; no direct
  wire connection to Node A or Node B.

```
┌──────────────────────────────────────────────────────────────────┐
│  Node A                                                          │
│                                                                  │
│  BME280 ──┐                                                      │
│           ├─ I²C (SCL PB8, SDA PB9) ──► NUCLEO-G070RB           │
│  MPU-6050─┘                                │                    │
│                              SPI1 (PA5/6/7/PB6) + EXTI (PA9)    │
│                                            │                    │
│                                        MCP2515                  │
│                                        + TJA1050                │
│                                            │                    │
│  5V relay ◄── GPIO PB5 (active HIGH)       │                    │
│  OLED SSD1306 ◄── I²C (optional)           │                    │
└────────────────────────────────────────────┼────────────────────┘
                                             │ CAN_H / CAN_L
                                    120Ω ────┤──── 120Ω
                                             │
┌────────────────────────────────────────────┼────────────────────┐
│  Node B                                    │                    │
│                                        MCP2515                  │
│                                        + TJA1050                │
│                              SPI (GPIO 18/19/23/5) + INT (GPIO4) │
│                                            │                    │
│                                       ESP32 dev board           │
│                                            │                    │
│                                     Wi-Fi 802.11 b/g/n          │
└────────────────────────────────────────────┼────────────────────┘
                                             │ MQTT / TLS
                                             ▼
                                    Raspberry Pi 4
                                  (local Wi-Fi network)
```

---

## 2. Components and Identification

| Ref | Component | What to look for | Marking / ID |
|-----|-----------|-----------------|--------------|
| U1 | NUCLEO-G070RB | Green ST dev board, 64-pin LQFP chip | `STM32G070RBT6` on chip |
| U2 | ESP32 dev board | 38-pin wide module or 30-pin narrow | `ESP32-WROOM-32` or similar |
| U3 | BME280 breakout | Small blue/green board, 4–6 pins | `BME280` printed on IC |
| U4 | MPU-6050 breakout | Blue board labelled GY-521 | `MPU-6050` on IC |
| U5 | MCP2515 module (Node A) | Module with 2 ICs: MCP2515 + TJA1050 | Crystal usually 8 MHz |
| U6 | MCP2515 module (Node B) | Same module as U5 | Second identical unit |
| U7 | 5V relay module | Blue board with relay coil + LED | `SRD-05VDC-SL-C` or similar |
| U8 | SSD1306 OLED (optional) | 0.96" white/blue display, 4 pins | `SSD1306` on controller chip |
| U9 | Raspberry Pi 4 | Green board, USB-C power, 4× USB-A | `Raspberry Pi 4 Model B` |
| R1, R2 | 120 Ω resistors | Standard through-hole 1/4W | Brown-red-brown-gold colour bands |
| PSU1 | AMS1117 3.3V module | Small LDO regulator module | `AMS1117-3.3` |

> **MCP2515 crystal frequency:** Most off-the-shelf MCP2515 modules use
> an **8 MHz** crystal. Some use 16 MHz. Check the crystal marking before
> calculating CAN bit timing registers (CNF1/CNF2/CNF3). Using the wrong
> crystal frequency in firmware will produce incorrect bus speed and no
> communication.

---

## 3. Voltage and Logic Level Reference

| Node / Component | VCC | Logic high | Logic low | Notes |
|-----------------|-----|-----------|-----------|-------|
| NUCLEO-G070RB (3.3V domain) | 3.3V | 2.0V min | 0.8V max | All GPIO pins are 3.3V output |
| BME280 breakout | 3.3V | — | — | Module includes 3.3V LDO + pull-ups |
| MPU-6050 breakout (GY-521) | 3.3V | — | — | Module includes 3.3V LDO + pull-ups |
| MCP2515 module | 5V or 3.3V | — | — | **Check module variant** — some need 5V, others 3.3V |
| TJA1050 transceiver | 5V | — | — | CAN bus differential; logic side tolerant of 3.3V if RXD pull-up tied to 3.3V |
| ESP32 (3.3V domain) | 3.3V | 2.4V min | 0.8V max | GPIO pins 3.3V only — not 5V tolerant |
| 5V relay module | 5V (coil) | 3.3V min (IN pin) | — | Most relay modules trigger correctly at 3.3V HIGH on IN pin |

> **Critical:** ESP32 GPIO pins are **not 5V tolerant**. Never connect a
> 5V logic signal directly to an ESP32 GPIO. The MCP2515 module on Node B
> must be selected or wired to use 3.3V logic on its SPI interface, or a
> level shifter must be added.

> **I²C pull-ups:** The BME280 and MPU-6050 breakout boards (GY-521 and
> typical BME280 modules) include on-board 4.7 kΩ pull-up resistors to
> their VCC rail. Do **not** add additional external pull-ups — two sets
> of pull-ups in parallel will lower the effective pull-up resistance and
> can cause I²C signal integrity issues at 400 kHz.

---

## 4. Node A — NUCLEO-G070RB Wiring

The NUCLEO-G070RB morpho connector row labels (CN7, CN10) are used below.
Refer to the NUCLEO-G070RB user manual (UM2324) Figure 8 for connector
layout if needed.

### 4.1 BME280 (I²C)

| BME280 pin | NUCLEO pin | Signal | Notes |
|-----------|-----------|--------|-------|
| VCC | 3.3V (CN7-16) | Power | Use AMS1117 3.3V rail or NUCLEO 3.3V |
| GND | GND (CN7-20) | Ground | Common ground with all other components |
| SCL | PB8 (CN7-1) | I2C1_SCL | 400 kHz fast mode; pull-up on module |
| SDA | PB9 (CN7-2) | I2C1_SDA | Pull-up on module |
| SDO | GND | Address select | Pulls I²C address to 0x76. Tie to 3.3V for 0x77 |
| CSB | 3.3V | SPI/I²C select | Must be HIGH to force I²C mode |

> **Address:** With SDO tied to GND, BME280 responds at `0x76`. Verify
> with an I²C scan in firmware before writing the driver. If the address
> reads as `0x77`, SDO is floating or tied high.

---

### 4.2 MPU-6050 (I²C)

| MPU-6050 (GY-521) pin | NUCLEO pin | Signal | Notes |
|----------------------|-----------|--------|-------|
| VCC | 3.3V (CN7-16) | Power | Shared 3.3V rail |
| GND | GND (CN7-20) | Ground | Common ground |
| SCL | PB8 (CN7-1) | I2C1_SCL | Shared bus with BME280 |
| SDA | PB9 (CN7-2) | I2C1_SDA | Shared bus with BME280 |
| AD0 | GND | Address select | AD0 LOW → address 0x68. HIGH → 0x69 |
| INT | Not connected | Interrupt | Not used in v1.0 (polling mode) |
| XDA, XCL | Not connected | Aux I²C | Not used (DMP disabled) |

> **Address conflict check:** BME280 is at 0x76, MPU-6050 at 0x68. No
> conflict. Run an I²C scan at startup to confirm both devices ACK before
> proceeding with driver initialisation.

---

### 4.3 MCP2515 CAN Module (SPI)

| MCP2515 module pin | NUCLEO pin | Signal | Notes |
|-------------------|-----------|--------|-------|
| VCC | 5V (CN7-18) or 3.3V | Power | Match to module variant voltage |
| GND | GND (CN7-20) | Ground | Common ground |
| CS | PB6 (CN10-17) | SPI1_CS (GPIO out) | Active LOW; software controlled |
| SO (MISO) | PA6 (CN10-13) | SPI1_MISO | Master In Slave Out |
| SI (MOSI) | PA7 (CN10-15) | SPI1_MOSI | Master Out Slave In |
| SCK | PA5 (CN10-11) | SPI1_SCK | 10 MHz |
| INT | PA9 (CN10-21) | EXTI9 | Falling edge; MCP2515 asserts LOW on RX ready |
| CAN_H | CAN bus wire 1 | CAN_H | Twisted pair to Node B |
| CAN_L | CAN bus wire 2 | CAN_L | Twisted pair to Node B |

> **INT pin:** Configure as `GPIO_MODE_IT_FALLING` in CubeIDE. Enable
> EXTI9_5 interrupt in NVIC. The MCP2515 INT line is open-drain —
> the NUCLEO's internal pull-up should be enabled on PA9.

---

### 4.4 5V Relay Module (GPIO)

| Relay module pin | NUCLEO / Supply pin | Signal | Notes |
|-----------------|---------------------|--------|-------|
| VCC | 5V (CN7-18) | Coil power | Relay coil needs 5V; do not use 3.3V |
| GND | GND (CN7-20) | Ground | Common ground |
| IN | PB5 (CN10-29) | GPIO output, active HIGH | 3.3V HIGH from NUCLEO is sufficient to trigger most optocoupled relay modules |
| COM | Load circuit common | — | Connect to one side of the load circuit |
| NO | Normally open terminal | — | Connect to load; closes when relay active |
| NC | Normally closed terminal | — | Not used in v1.0 |

> **Flyback protection:** Most commercial relay modules include an
> onboard flyback diode across the coil. Confirm this before powering
> up — a missing flyback diode can inject voltage spikes back into the
> GPIO supply rail.

> **Load circuit:** The relay is switching a test load only in v1.0
> (e.g. an LED + resistor). Do not switch mains voltage without
> appropriate safety precautions and isolation.

---

### 4.5 SSD1306 OLED (optional, I²C)

| OLED pin | NUCLEO pin | Signal | Notes |
|----------|-----------|--------|-------|
| VCC | 3.3V | Power | Some modules accept 3.3–5V; confirm datasheet |
| GND | GND | Ground | Common ground |
| SCL | PB8 (CN7-1) | I2C1_SCL | Third device on shared I²C bus |
| SDA | PB9 (CN7-2) | I2C1_SDA | |

> **I²C address:** SSD1306 default address is `0x3C`. No conflict with
> BME280 (0x76) or MPU-6050 (0x68). If the module has an address jumper,
> confirm it is set to 0x3C before adding the driver.

> This peripheral is optional for v1.0. Implement only after all other
> firmware is stable — OLED writes consume I²C bus time.

---

### 4.6 Debug UART

The NUCLEO-G070RB ST-Link provides a virtual COM port over USB. No
additional wiring is required.

| Signal | Pin | Config |
|--------|-----|--------|
| USART2_TX | PA2 (routed to ST-Link) | 115200 baud, 8N1 |
| USART2_RX | PA3 (routed to ST-Link) | Not used for output |

Connect the NUCLEO USB cable to a PC. Open a serial terminal
(PuTTY, minicom, or CubeIDE console) at **115200 baud, 8N1, no flow
control** to view debug output.

---

## 5. Node B — ESP32 Wiring

Pin numbers below refer to GPIO numbers on a standard 38-pin
ESP32-WROOM-32 dev board. Physical pin positions vary by board
manufacturer — always verify against the silkscreen.

### 5.1 MCP2515 CAN Module (SPI)

| MCP2515 module pin | ESP32 GPIO | Signal | Notes |
|-------------------|-----------|--------|-------|
| VCC | 3.3V | Power | Use 3.3V variant MCP2515 module, or verify compatibility |
| GND | GND | Ground | Common ground |
| CS | GPIO 5 | SPI CS (GPIO out) | Active LOW; software controlled |
| SO (MISO) | GPIO 19 | SPI MISO | |
| SI (MOSI) | GPIO 23 | SPI MOSI | |
| SCK | GPIO 18 | SPI SCK | 10 MHz |
| INT | GPIO 4 | Input, falling edge ISR | Enable internal pull-up |
| CAN_H | CAN bus wire 1 | CAN_H | Twisted pair from Node A |
| CAN_L | CAN bus wire 2 | CAN_L | Twisted pair from Node A |

> **SPI library:** Using Arduino's `SPI.begin(18, 19, 23, 5)` with the
> MCP_CAN library. The `MCP_CAN` constructor takes the CS pin number:
> `MCP_CAN CAN(5)`.

> **Boot strapping pins:** GPIO 0, 2, 12, and 15 affect ESP32 boot mode.
> Avoid using these for SPI or INT signals. GPIO 4, 5, 18, 19, 23 are
> safe general-purpose pins.

---

## 6. CAN Bus Wiring

The CAN bus is a two-wire differential bus. Correct wiring is essential —
a wiring error is the most common reason CAN communication fails to start.

### 6.1 Wire the bus

```
Node A TJA1050              Node B TJA1050
   CAN_H ────────────────────── CAN_H
   CAN_L ────────────────────── CAN_L
      │                              │
    120 Ω                          120 Ω
   (R1)                            (R2)
   CAN_H to CAN_L               CAN_H to CAN_L
```

- Use **twisted pair** wire — twisted pairs reject common-mode noise.
  A standard Cat5e patch cable pair (any two adjacent conductors) works
  for bench testing at 500 kbit/s over short distances (< 1 m).
- **Two termination resistors, one at each end of the bus.** Not one in
  the middle, not three. R1 is placed at Node A. R2 is placed at Node B.
- Measure resistance between CAN_H and CAN_L with both nodes powered
  **off** — you should read **60 Ω** (two 120 Ω in parallel). A reading
  of 120 Ω means one terminator is missing. Open circuit means both are
  missing or the wiring is broken.

### 6.2 Bus length and speed

At 500 kbit/s, the maximum theoretical bus length is approximately 100 m.
For a bench test with < 1 m of wire, bus length is not a concern.

### 6.3 Verify bus voltage with a multimeter

With both nodes powered on and CAN active, measure DC voltage:

| Measurement | Expected (dominant bit) | Expected (recessive/idle) |
|------------|------------------------|--------------------------|
| CAN_H to GND | ~3.5V | ~2.5V |
| CAN_L to GND | ~1.5V | ~2.5V |
| CAN_H to CAN_L (differential) | ~2.0V | ~0V |

A flat 2.5V on both lines with no differential swinging means the bus
is stuck recessive — a node is not driving, or the MCP2515 is not in
normal mode.

---

## 7. Raspberry Pi Setup

The Raspberry Pi is connected only via Wi-Fi — no GPIO or UART wires
to Node A or Node B.

### 7.1 Initial OS setup

1. Flash **Raspberry Pi OS (64-bit, Lite)** to the 16 GB microSD using
   Raspberry Pi Imager.
2. In Imager advanced settings: enable SSH, set hostname to `canlog-pi`,
   set username/password, configure Wi-Fi SSID and password.
3. Insert microSD, power on with official USB-C PSU, wait 60 s.
4. SSH in: `ssh <username>@canlog-pi.local`

### 7.2 Static IP (recommended)

Assign a static IP to the Pi on your router's DHCP reservation table
using the Pi's MAC address. This avoids the MQTT broker IP changing and
requiring a firmware re-flash on the ESP32.

Note the static IP — it must match `BROKER_IP` in
`firmware/node_b/config.h`.

### 7.3 Required packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y mosquitto mosquitto-clients python3-pip python3-venv \
                    sqlite3 nginx openssl
```

### 7.4 Confirm Mosquitto is running

```bash
sudo systemctl status mosquitto
# Should show: active (running)

mosquitto_pub -h localhost -p 1883 -t test -m hello
mosquitto_sub -h localhost -p 1883 -t test -C 1
# Should print: hello
```

---

## 8. Full System Pinout Summary

### Node A — NUCLEO-G070RB

| NUCLEO pin | GPIO | Peripheral | Connected to | Direction |
|-----------|------|-----------|--------------|-----------|
| CN7-1 | PB8 | I2C1_SCL | BME280 SCL, MPU-6050 SCL, OLED SCL | Bidirectional |
| CN7-2 | PB9 | I2C1_SDA | BME280 SDA, MPU-6050 SDA, OLED SDA | Bidirectional |
| CN10-11 | PA5 | SPI1_SCK | MCP2515 SCK | Output |
| CN10-13 | PA6 | SPI1_MISO | MCP2515 SO | Input |
| CN10-15 | PA7 | SPI1_MOSI | MCP2515 SI | Output |
| CN10-17 | PB6 | GPIO out | MCP2515 CS (active LOW) | Output |
| CN10-21 | PA9 | EXTI9 | MCP2515 INT (active LOW) | Input |
| CN10-29 | PB5 | GPIO out | Relay module IN (active HIGH) | Output |
| CN7-18 | — | 5V | MCP2515 VCC, Relay VCC | Power out |
| CN7-16 | — | 3.3V | BME280 VCC, MPU-6050 VCC, OLED VCC | Power out |
| CN7-20 | — | GND | All component GND | Ground |
| PA2 | PA2 | USART2_TX | ST-Link (virtual COM) | Output |
| PD0 | PD0 | bxCAN_RX | TJA1050 RXD | Input |
| PD1 | PD1 | bxCAN_TX | TJA1050 TXD | Output |

### Node B — ESP32 dev board

| ESP32 GPIO | Peripheral | Connected to | Direction |
|-----------|-----------|--------------|-----------|
| GPIO 18 | SPI SCK | MCP2515 SCK | Output |
| GPIO 19 | SPI MISO | MCP2515 SO | Input |
| GPIO 23 | SPI MOSI | MCP2515 SI | Output |
| GPIO 5 | GPIO out | MCP2515 CS (active LOW) | Output |
| GPIO 4 | GPIO in | MCP2515 INT (active LOW) | Input |
| 3.3V | — | MCP2515 VCC | Power out |
| GND | — | MCP2515 GND | Ground |

---

## 9. Power Supply Plan

All three nodes should be powered independently to avoid ground loops
and ensure each node can be reset individually during debugging.

| Node | Supply | Recommended source | Max current |
|------|--------|--------------------|-------------|
| NUCLEO-G070RB + sensors | 5V via USB-A | PC USB port or USB charger | ~500 mA |
| ESP32 dev board | 5V via USB-A | Separate PC USB port or charger | ~500 mA |
| Raspberry Pi 4 | 5V 3A via USB-C | Official Raspberry Pi PSU | 3A |

> **Common ground:** Even with separate power supplies, the GND of Node A
> and Node B must be connected together (a single wire between any GND pin
> on each board). The CAN bus differential signalling requires a common
> reference potential. Without a shared ground, the TJA1050 differential
> receiver will see an indeterminate common-mode voltage and may not
> decode frames correctly.

> **Do not power the NUCLEO from a shared 5V rail with the relay coil.**
> Relay coil switching generates voltage transients. Use the NUCLEO's
> own USB power for the microcontroller logic and a separate 5V rail
> (or the relay module's own onboard supply) for the relay coil.

---

## 10. Hardware Verification Checklist

Work through this list in order before writing or flashing any firmware.
Each step must pass before moving to the next.

### Step 1 — Power rails

- [ ] Measure 3.3V rail with multimeter — confirm 3.3V ±5% (3.135–3.465V)
- [ ] Measure 5V rail — confirm 5.0V ±5% (4.75–5.25V)
- [ ] All component GNDs tied together and to a common reference

### Step 2 — NUCLEO USB / ST-Link

- [ ] NUCLEO connected to PC via USB-B cable
- [ ] ST-Link driver installed (Windows) or recognised (Linux: `dmesg | grep STLink`)
- [ ] CubeIDE can connect to the target: Run → Debug → confirm green status bar
- [ ] Virtual COM port appears (COMx on Windows, `/dev/ttyACM0` on Linux)
- [ ] Serial terminal at 115200 baud prints "Hello" from a minimal test project

### Step 3 — I²C bus scan

- [ ] Flash a minimal I²C scan firmware that iterates all addresses 0x00–0x7F
- [ ] BME280 responds at `0x76` — logged to UART
- [ ] MPU-6050 responds at `0x68` — logged to UART
- [ ] No unexpected devices (address conflicts) on the bus

### Step 4 — BME280 raw read

- [ ] Read calibration registers (0x88–0x9F, 0xA1, 0xE1–0xE7) — non-zero
- [ ] Read burst 0xF7–0xFC — 6 bytes, non-zero
- [ ] Apply Bosch compensation — temperature within ±2°C of a reference thermometer
- [ ] Humidity and pressure within plausible range for your location

### Step 5 — MPU-6050 raw read

- [ ] Write `0x00` to PWR_MGMT_1 (0x6B) to wake device
- [ ] Read WHO_AM_I register (0x75) — must return `0x68`
- [ ] Read accel registers (0x3B–0x40) — Az ≈ +16384 when board is flat
- [ ] Read gyro registers (0x43–0x48) — all ≈ 0 when board is still

### Step 6 — MCP2515 SPI (Node A)

- [ ] SPI clock visible on logic analyser at 10 MHz — verify with PulseView
- [ ] Reset command (0xC0) sent; read CANSTAT register — returns `0x80` (config mode)
- [ ] Configure bit timing for 500 kbit/s (CNF1/CNF2/CNF3 values per crystal frequency)
- [ ] Set loopback mode — transmit one frame — receive same frame on same node
- [ ] Confirm MCP2515 exits config mode and enters normal mode (CANSTAT = `0x00`)

### Step 7 — MCP2515 SPI (Node B, ESP32)

- [ ] Same verification as Step 6 but on ESP32
- [ ] ESP32 Arduino SPI initialised — confirm CS, MOSI, MISO, SCK on correct pins
- [ ] Read CANSTAT register from ESP32 — returns `0x80` in config mode

### Step 8 — CAN bus end-to-end

- [ ] 60 Ω between CAN_H and CAN_L with both nodes powered off (two 120 Ω in parallel)
- [ ] Node A transmits frame 0x100 in normal mode
- [ ] Node B receives frame 0x100 — INT pin asserts, SPI RX buffer readable
- [ ] PulseView CAN decode on CAN_H/CAN_L shows correct ID, DLC, data

### Step 9 — Relay

- [ ] Set PB5 HIGH in firmware — relay clicks audibly, LED on module illuminates
- [ ] Set PB5 LOW — relay releases
- [ ] Confirm no voltage spike on 3.3V rail during switching (check with oscilloscope if available)

### Step 10 — Raspberry Pi connectivity

- [ ] SSH access to Pi confirmed
- [ ] Mosquitto running on port 1883
- [ ] Pi reachable from ESP32's network segment (`ping <pi-ip>` from a PC on same network)
- [ ] TLS certificates generated and Mosquitto configured on port 8883
- [ ] ESP32 connects to Wi-Fi and subscribes/publishes to broker successfully

---

## 11. Common Wiring Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| I²C SCL and SDA swapped | Both sensors fail I²C scan | Swap SCL and SDA wires |
| MCP2515 CS not driven LOW during SPI transfer | SPI reads return 0xFF | Ensure CS goes LOW before first byte and HIGH after last byte |
| MCP2515 using 16 MHz crystal but firmware configured for 8 MHz | CAN bus speed wrong; no communication | Check crystal marking; update CNF1/CNF2/CNF3 |
| Only one CAN termination resistor | Intermittent CAN errors, high error frame count | Add second 120 Ω at the other end of the bus |
| Node A and Node B GNDs not connected | CAN bus common-mode voltage incorrect; no frames received | Add a GND wire between any GND pin on each board |
| ESP32 SPI MISO/MOSI swapped | MCP2515 reads 0xFF; no config mode | Swap MISO and MOSI pins in `SPI.begin()` call |
| Relay IN pin pulled LOW by module (active LOW relay) | Relay stays on by default; GPIO HIGH turns it off | Check relay module active level; invert GPIO logic in `relay_control.c` |
| BME280 in SPI mode (CSB floating) | I²C scan shows no device at 0x76 | Tie CSB to 3.3V (HIGH) to force I²C mode |
| Two sets of I²C pull-ups (module + external) | I²C timing errors at 400 kHz | Remove external pull-ups; rely on module pull-ups |
| ESP32 GPIO 0 used for SPI CS | ESP32 fails to boot when CS is held LOW at power-on | Move CS to GPIO 5; avoid boot-strapping pins |

---

## 12. Photo Log

> 📷 **Photos to be added during Phase 1 (Months 1–2) hardware bring-up.**

Photos should be added to `/docs/img/` and linked here once the hardware
is assembled and verified.

| Photo | Description | Status |
|-------|-------------|--------|
| `full_bench.jpg` | Full bench setup — all three nodes visible | _Pending_ |
| `node_a_wired.jpg` | NUCLEO-G070RB with all sensors and MCP2515 attached | _Pending_ |
| `node_b_wired.jpg` | ESP32 with MCP2515 attached | _Pending_ |
| `can_bus_termination.jpg` | Close-up of twisted pair and 120 Ω resistors at both ends | _Pending_ |
| `relay_module.jpg` | Relay module wired to NUCLEO GPIO | _Pending_ |
| `pulseview_i2c.png` | PulseView screenshot of I²C BME280 read transaction | _Pending_ |
| `pulseview_spi.png` | PulseView screenshot of MCP2515 SPI frame load | _Pending_ |
| `pulseview_can.png` | PulseView screenshot of CAN frame 0x100 on bus | _Pending_ |

---

*CANLOG-01 · Hardware Setup · v1.0 · MIT License*
