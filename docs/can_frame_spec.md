# CAN Frame Specification — CANLOG-01

> **Document status:** Draft v1.0 · Pre-development  
> **Last updated:** 2026-03  
> **Relates to:** `architecture.md`, `/firmware/node_a/Core/Inc/can_frame.h`, `/firmware/node_b/can_parser.h`

---

## Table of Contents

- [1. General Conventions](#1-general-conventions)
- [2. CAN ID Allocation](#2-can-id-allocation)
- [3. Frame Definitions](#3-frame-definitions)
  - [3.1 0x100 — BME280 Environmental Data](#31-0x100--bme280-environmental-data)
  - [3.2 0x101 — MPU-6050 Accelerometer](#32-0x101--mpu-6050-accelerometer)
  - [3.3 0x102 — MPU-6050 Gyroscope](#33-0x102--mpu-6050-gyroscope)
  - [3.4 0x10F — Heartbeat / Node Status](#34-0x10f--heartbeat--node-status)
  - [3.5 0x200 — Relay State Change](#35-0x200--relay-state-change)
  - [3.6 0x7FF — Error / Fault Frame](#36-0x7ff--error--fault-frame)
- [4. Fixed-Point Encoding Reference](#4-fixed-point-encoding-reference)
- [5. Sequence Number Behaviour](#5-sequence-number-behaviour)
- [6. Status Flags Bitmap](#6-status-flags-bitmap)
- [7. Fault Code Reference](#7-fault-code-reference)
- [8. Encoding Examples](#8-encoding-examples)
- [9. Decoding Checklist](#9-decoding-checklist)

---

## 1. General Conventions

| Property | Value |
|----------|-------|
| CAN standard | ISO 11898-1, classical CAN (not CAN FD) |
| ID format | Standard 11-bit (base frame format) |
| Bus speed | 500 kbit/s |
| DLC | Fixed 8 bytes for all frames |
| Byte order | **Little-endian** (LSB at lower byte address) unless noted |
| Padding | Unused bytes set to `0x00` |
| Producer node | NUCLEO-G070RB (Node A) for all frames except 0x7FF (any node) |
| Physical layer | Twisted pair + TJA1050 transceiver, 120 Ω termination at both ends |

> **Little-endian rule:** For a multi-byte field, byte `N` holds the
> least-significant 8 bits and byte `N+1` holds the next 8 bits.  
> Example: `int16_t value = 0x1234` → byte 0 = `0x34`, byte 1 = `0x12`.

---

## 2. CAN ID Allocation

| CAN ID (hex) | Frame type | Producer | Update rate | DLC |
|-------------|-----------|----------|-------------|-----|
| `0x100` | BME280 environmental data | Node A | 1 Hz | 8 |
| `0x101` | MPU-6050 accelerometer (Ax, Ay, Az) | Node A | 1 Hz | 8 |
| `0x102` | MPU-6050 gyroscope (Gx, Gy, Gz) | Node A | 1 Hz | 8 |
| `0x10F` | Heartbeat / node status | Node A | 1 Hz | 8 |
| `0x200` | Relay state change event | Node A | On event | 8 |
| `0x7FF` | Error / fault frame | Any node | On event | 8 |

IDs `0x103`–`0x10E`, `0x201`–`0x7FE` are **reserved** for future use.  
ID `0x7FF` is the highest standard ID and has the **lowest bus arbitration
priority** — intentional, as fault frames are non-time-critical.

---

## 3. Frame Definitions

### 3.1 `0x100` — BME280 Environmental Data

Produced once per second. Contains temperature, relative humidity, and
barometric pressure encoded as fixed-point integers (see
[Section 4](#4-fixed-point-encoding-reference)).

| Byte(s) | Field | Type | Scale / Units | Raw range | Decoded range |
|---------|-------|------|---------------|-----------|---------------|
| 0–1 | Temperature | `int16_t` | 0.01 °C / LSB, signed | −4000 … +8500 | −40.00 … +85.00 °C |
| 2–3 | Humidity | `uint16_t` | 0.01 %RH / LSB, unsigned | 0 … 10000 | 0.00 … 100.00 %RH |
| 4–6 | Pressure | `uint24_t`* | 0.01 hPa / LSB, unsigned | 30000 … 110000 | 300.00 … 1100.00 hPa |
| 7 | Sequence number | `uint8_t` | Wraps 0–255 | 0 … 255 | — |

*`uint24_t` = 3 bytes, little-endian. There is no native 24-bit type in C;
pack/unpack manually (see [Section 8](#8-encoding-examples)).

**Firmware encode (pseudocode):**
```c
frame.data[0] = (uint8_t)(temp_scaled & 0xFF);
frame.data[1] = (uint8_t)((temp_scaled >> 8) & 0xFF);
frame.data[2] = (uint8_t)(humidity_scaled & 0xFF);
frame.data[3] = (uint8_t)((humidity_scaled >> 8) & 0xFF);
frame.data[4] = (uint8_t)(pressure_scaled & 0xFF);
frame.data[5] = (uint8_t)((pressure_scaled >> 8) & 0xFF);
frame.data[6] = (uint8_t)((pressure_scaled >> 16) & 0xFF);
frame.data[7] = seq++;
```

---

### 3.2 `0x101` — MPU-6050 Accelerometer

Raw 16-bit ADC output from the MPU-6050 accelerometer registers. No
scale factor applied in firmware — the ESP32 and backend store raw values;
conversion to physical units (g) is done at display time.

**Full-scale setting:** ±2 g (`ACCEL_CONFIG` register `AFS_SEL = 0b00`).  
**Conversion at display:** `accel_g = raw_value / 16384.0`

| Byte(s) | Field | Type | Notes |
|---------|-------|------|-------|
| 0–1 | Accel X (Ax) | `int16_t` | Raw ADC, signed, little-endian |
| 2–3 | Accel Y (Ay) | `int16_t` | Raw ADC, signed, little-endian |
| 4–5 | Accel Z (Az) | `int16_t` | Raw ADC, signed, little-endian |
| 6 | Sequence number | `uint8_t` | Shared counter with 0x102 |
| 7 | Reserved | `uint8_t` | Must be `0x00` |

> **Note:** The sequence number in frames `0x101` and `0x102` is the
> **same counter**, incremented once per acquisition cycle. This allows
> the backend to join accel and gyro rows from the same sample by matching
> `seq` values.

---

### 3.3 `0x102` — MPU-6050 Gyroscope

Raw 16-bit ADC output from the MPU-6050 gyroscope registers.

**Full-scale setting:** ±250 °/s (`GYRO_CONFIG` register `FS_SEL = 0b00`).  
**Conversion at display:** `gyro_dps = raw_value / 131.0`

| Byte(s) | Field | Type | Notes |
|---------|-------|------|-------|
| 0–1 | Gyro X (Gx) | `int16_t` | Raw ADC, signed, little-endian |
| 2–3 | Gyro Y (Gy) | `int16_t` | Raw ADC, signed, little-endian |
| 4–5 | Gyro Z (Gz) | `int16_t` | Raw ADC, signed, little-endian |
| 6 | Sequence number | `uint8_t` | Same counter as 0x101 |
| 7 | Reserved | `uint8_t` | Must be `0x00` |

---

### 3.4 `0x10F` — Heartbeat / Node Status

Transmitted every second regardless of sensor state. A missing heartbeat
for more than 3 seconds indicates Node A has hung, lost power, or the CAN
bus has failed.

| Byte(s) | Field | Type | Description |
|---------|-------|------|-------------|
| 0 | Node ID | `uint8_t` | `0x01` = NUCLEO Node A |
| 1 | FW version major | `uint8_t` | e.g. `0x01` for v1.x |
| 2 | FW version minor | `uint8_t` | e.g. `0x00` for v1.0 |
| 3 | Uptime low byte | `uint8_t` | Seconds since boot, wraps at 255 |
| 4 | Status flags | `uint8_t` | See [Section 6](#6-status-flags-bitmap) |
| 5–7 | Reserved | `uint8_t[3]` | Must be `0x00 0x00 0x00` |

---

### 3.5 `0x200` — Relay State Change

Transmitted on event only — when the relay is asserted (temperature exceeds
40 °C) or de-asserted (temperature drops below 38 °C after hysteresis).
Not transmitted at 1 Hz.

| Byte(s) | Field | Type | Values |
|---------|-------|------|--------|
| 0 | State | `uint8_t` | `0x01` = relay ON, `0x00` = relay OFF |
| 1–2 | Trigger temperature | `int16_t` | 0.01 °C / LSB (same scale as 0x100 byte 0–1) |
| 3 | Reason code | `uint8_t` | See table below |
| 4–7 | Reserved | `uint8_t[4]` | Must be `0x00` |

**Reason codes:**

| Code | Meaning |
|------|---------|
| `0x01` | Temperature threshold exceeded (ON event) |
| `0x02` | Temperature dropped below hysteresis limit (OFF event) |
| `0xFF` | Manual / test activation |

---

### 3.6 `0x7FF` — Error / Fault Frame

Transmitted by any node when a recoverable or unrecoverable fault is
detected. Using the highest standard ID ensures this frame loses arbitration
to all sensor data frames — it never delays time-critical measurements.

| Byte(s) | Field | Type | Description |
|---------|-------|------|-------------|
| 0 | Source node ID | `uint8_t` | `0x01` = Node A, `0x02` = Node B |
| 1 | Fault code | `uint8_t` | See [Section 7](#7-fault-code-reference) |
| 2 | Fault sub-code | `uint8_t` | Driver-specific detail (0x00 if unused) |
| 3 | Status flags snapshot | `uint8_t` | Value of status flags at time of fault |
| 4–7 | Reserved | `uint8_t[4]` | Must be `0x00` |

---

## 4. Fixed-Point Encoding Reference

Floating-point operations are avoided in firmware (no FPU on Cortex-M0+,
and `float` in ISR context is inadvisable). Sensor values are represented
as scaled integers.

| Field | Physical unit | Scale factor | C type | Firmware formula |
|-------|--------------|-------------|--------|-----------------|
| Temperature | °C | × 100 | `int16_t` | `(int16_t)(temp_celsius * 100.0f)` |
| Humidity | %RH | × 100 | `uint16_t` | `(uint16_t)(humidity_pct * 100.0f)` |
| Pressure | hPa | × 100 | `uint32_t` (3 bytes used) | `(uint32_t)(pressure_hpa * 100.0f)` |
| Relay trigger temp | °C | × 100 | `int16_t` | Same as temperature |

**Decoder formula (Python):**
```python
temp_c        = int16_raw / 100.0
humidity_pct  = uint16_raw / 100.0
pressure_hpa  = uint24_raw / 100.0
```

**Decoder formula (C / ESP32):**
```c
float temp_c       = (float)((int16_t)(data[1] << 8 | data[0])) / 100.0f;
float humidity_pct = (float)((uint16_t)(data[3] << 8 | data[2])) / 100.0f;
uint32_t p_raw     = data[4] | ((uint32_t)data[5] << 8) | ((uint32_t)data[6] << 16);
float pressure_hpa = (float)p_raw / 100.0f;
```

---

## 5. Sequence Number Behaviour

- Sequence numbers are `uint8_t`, range 0–255, wrapping back to 0 after 255.
- Frame `0x100` has its own independent sequence counter.
- Frames `0x101` and `0x102` share a single sequence counter — both are
  incremented in the same 1 Hz acquisition cycle, so their `seq` values
  always match for a given sample.
- The heartbeat frame `0x10F` does **not** carry a sequence number (byte 3
  is uptime, not seq).
- A gap in sequence numbers (e.g. last received seq = 10, next = 13) means
  2 frames were lost in transit. The Python subscriber logs dropped-frame
  warnings based on this.
- Sequence numbers are **not** used for deduplication — duplicate delivery
  is not expected on a point-to-point CAN bus in normal operation.

---

## 6. Status Flags Bitmap

Byte 4 of the heartbeat frame `0x10F`. Each bit represents the live health
state of one subsystem. `1` = OK / active, `0` = fault / inactive.

| Bit | Mask | Meaning when 1 | Meaning when 0 |
|-----|------|----------------|----------------|
| 0 | `0x01` | BME280 OK — last read succeeded | BME280 fault — I²C NAK or timeout |
| 1 | `0x02` | MPU-6050 OK — last read succeeded | MPU-6050 fault — I²C NAK or timeout |
| 2 | `0x04` | Relay active (GPIO asserted HIGH) | Relay inactive (GPIO low) |
| 3 | `0x08` | CAN TX queue not full | CAN TX queue full (back-pressure) |
| 4–7 | `0xF0` | Reserved — must be `0` | — |

**Example:** `status_flags = 0x03` → BME280 OK, MPU-6050 OK, relay OFF, queue not full.  
**Example:** `status_flags = 0x07` → BME280 OK, MPU-6050 OK, relay ON.  
**Example:** `status_flags = 0x02` → BME280 fault, MPU-6050 OK, relay OFF.

---

## 7. Fault Code Reference

Used in byte 1 of fault frame `0x7FF`.

| Code | Constant name | Description | Producing node |
|------|--------------|-------------|----------------|
| `0x01` | `FAULT_BME280_NAK` | BME280 did not ACK on I²C | Node A |
| `0x02` | `FAULT_MPU6050_NAK` | MPU-6050 did not ACK on I²C | Node A |
| `0x03` | `FAULT_MCP2515_INIT` | MCP2515 failed to leave config mode | Node A or B |
| `0x04` | `FAULT_CAN_TX_TIMEOUT` | MCP2515 TX buffer did not clear within timeout | Node A |
| `0x05` | `FAULT_CAN_BUS_OFF` | bxCAN / MCP2515 entered bus-off error state | Node A or B |
| `0x10` | `FAULT_MQTT_CONNECT` | MQTT broker connection failed after max retries | Node B |
| `0x11` | `FAULT_SNTP_TIMEOUT` | SNTP time sync did not complete within 30 s | Node B |
| `0xFF` | `FAULT_UNKNOWN` | Unclassified fault — check sub-code and serial log | Any |

Sub-code (byte 2) carries driver-specific detail. For I²C faults, it contains
the HAL error code returned by `HAL_I2C_Master_Transmit`. For MCP2515 faults,
it contains the CANSTAT register value at the time of the fault.

---

## 8. Encoding Examples

### Example A — BME280 reading: 22.45 °C, 48.10 %RH, 1013.25 hPa, seq = 7

**Step 1 — Scale to integers:**
```
temp_scaled     = (int16_t)(22.45 * 100)  = 2245  = 0x08C5
humidity_scaled = (uint16_t)(48.10 * 100) = 4810  = 0x12CA
pressure_scaled = (uint32_t)(1013.25 * 100) = 101325 = 0x018BCD
seq             = 7 = 0x07
```

**Step 2 — Pack little-endian into 8 bytes:**
```
Byte 0 = 0xC5   (temp LSB)
Byte 1 = 0x08   (temp MSB)
Byte 2 = 0xCA   (humidity LSB)
Byte 3 = 0x12   (humidity MSB)
Byte 4 = 0xCD   (pressure byte 0, LSB)
Byte 5 = 0x8B   (pressure byte 1)
Byte 6 = 0x01   (pressure byte 2, MSB)
Byte 7 = 0x07   (sequence)
```

**Resulting CAN frame:**
```
ID: 0x100  DLC: 8  Data: C5 08 CA 12 CD 8B 01 07
```

**Step 3 — Decode (verify round-trip):**
```python
raw = bytes([0xC5, 0x08, 0xCA, 0x12, 0xCD, 0x8B, 0x01, 0x07])
import struct
temp_c        = struct.unpack_from('<h', raw, 0)[0] / 100.0   # → 22.45
humidity_pct  = struct.unpack_from('<H', raw, 2)[0] / 100.0   # → 48.10
p_raw         = raw[4] | (raw[5] << 8) | (raw[6] << 16)       # → 101325
pressure_hpa  = p_raw / 100.0                                  # → 1013.25
seq           = raw[7]                                         # → 7
```

---

### Example B — Accelerometer at rest (flat on desk), seq = 7

At rest with Z-axis vertical, expected values are approximately:
`Ax ≈ 0 g`, `Ay ≈ 0 g`, `Az ≈ +1 g`

At ±2 g full-scale, `+1 g = +16384 = 0x4000`.

```
Byte 0 = 0x00  (Ax LSB)  → Ax_raw = 0
Byte 1 = 0x00  (Ax MSB)
Byte 2 = 0x00  (Ay LSB)  → Ay_raw = 0
Byte 3 = 0x00  (Ay MSB)
Byte 4 = 0x00  (Az LSB)  → Az_raw = 16384 = 0x4000
Byte 5 = 0x40  (Az MSB)
Byte 6 = 0x07  (sequence = 7)
Byte 7 = 0x00  (reserved)
```

**Resulting CAN frame:**
```
ID: 0x101  DLC: 8  Data: 00 00 00 00 00 40 07 00
```

---

### Example C — Relay ON event at 41.50 °C

```
temp_scaled = (int16_t)(41.50 * 100) = 4150 = 0x1036

Byte 0 = 0x01   (state = ON)
Byte 1 = 0x36   (trigger temp LSB)
Byte 2 = 0x10   (trigger temp MSB)
Byte 3 = 0x01   (reason = TEMP_THRESHOLD_EXCEEDED)
Byte 4–7 = 0x00 (reserved)
```

**Resulting CAN frame:**
```
ID: 0x200  DLC: 8  Data: 01 36 10 01 00 00 00 00
```

---

## 9. Decoding Checklist

Use this when writing or reviewing a CAN frame parser (ESP32 `can_parser.cpp`
or a Python test fixture):

- [ ] Read `frame.id` first — unknown IDs must be ignored, not rejected with an error
- [ ] Confirm `frame.dlc == 8` before accessing any data byte
- [ ] Use `int16_t` (signed) cast for temperature and gyro fields, `uint16_t` for humidity
- [ ] Reconstruct 24-bit pressure as `uint32_t` using three separate OR operations — do not `memcpy` directly into a 32-bit field (alignment and endianness issues)
- [ ] Divide scaled integers by 100.0 (float) — not integer division
- [ ] Treat reserved bytes as don't-care — do not assert they are 0x00 in production code
- [ ] On sequence gap > 1: log a warning; do not discard the frame
- [ ] `0x7FF` fault frames must always be processed regardless of other frame filtering logic

---

*CANLOG-01 · CAN Frame Specification · v1.0 · MIT License*
