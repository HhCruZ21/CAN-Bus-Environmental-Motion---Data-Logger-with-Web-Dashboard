# MQTT Topics — CANLOG-01

> **Document status:** Draft v1.0 · Pre-development  
> **Last updated:** 2026-03  
> **Relates to:** `architecture.md`, `/firmware/node_b/mqtt_client.h`, `/backend/mqtt_subscriber.py`

---

## Table of Contents

- [1. General Conventions](#1-general-conventions)
- [2. Topic Hierarchy](#2-topic-hierarchy)
- [3. Topic Definitions](#3-topic-definitions)
  - [3.1 canlog/node_a/bme280](#31-canlognode_abme280)
  - [3.2 canlog/node_a/accel](#32-canlognode_aaccel)
  - [3.3 canlog/node_a/gyro](#33-canlognode_agyro)
  - [3.4 canlog/node_a/heartbeat](#34-canlognode_aheartbeat)
  - [3.5 canlog/node_a/relay](#35-canlognode_arelay)
  - [3.6 canlog/node_a/fault](#36-canlognode_afault)
- [4. Timestamp Handling](#4-timestamp-handling)
- [5. QoS Rationale](#5-qos-rationale)
- [6. Retained Message Behaviour](#6-retained-message-behaviour)
- [7. TLS Configuration](#7-tls-configuration)
- [8. Broker Configuration Reference](#8-broker-configuration-reference)
- [9. Full Payload Examples](#9-full-payload-examples)
- [10. Subscriber Routing Logic](#10-subscriber-routing-logic)
- [11. Testing the Pipeline Manually](#11-testing-the-pipeline-manually)

---

## 1. General Conventions

| Property | Value |
|----------|-------|
| Broker | Mosquitto on Raspberry Pi |
| Network port | `8883` (TLS, ESP32 → Pi) · `1883` (plain, localhost only) |
| Protocol version | MQTT 3.1.1 |
| Payload encoding | UTF-8 JSON |
| Payload max size | 512 bytes (PubSubClient buffer limit on ESP32) |
| Topic separator | `/` (forward slash) |
| Wildcard subscribe | `canlog/#` — matches all project topics |
| Client ID — ESP32 | `canlog-node-b` |
| Client ID — Python subscriber | `canlog-subscriber` |
| Keep-alive interval | 60 seconds |
| Clean session | `true` for ESP32 · `false` for Python subscriber (preserves QoS 1/2 queues) |

**JSON field naming:** All field names use `snake_case`. No abbreviations
except established ones (`ts`, `seq`, `ax`, `ay`, `az`, `gx`, `gy`, `gz`).

**Numeric precision:** All floating-point fields are rounded to 2 decimal
places before serialisation. `"temp_c": 22.45` not `"temp_c": 22.449999999`.

---

## 2. Topic Hierarchy

```
canlog/
└── node_a/
    ├── bme280        ← environmental sensor data     (1 Hz, QoS 1)
    ├── accel         ← accelerometer data            (1 Hz, QoS 1)
    ├── gyro          ← gyroscope data                (1 Hz, QoS 1)
    ├── heartbeat     ← node status / health          (1 Hz, QoS 0, retained)
    ├── relay         ← relay state change events     (on event, QoS 2, retained)
    └── fault         ← error / fault notifications  (on event, QoS 1)
```

The three-level pattern is `canlog/{node_id}/{data_type}`.

`node_id` is `node_a` for the NUCLEO-G070RB (Node A). If additional nodes
are added in a future revision, they publish under their own `node_id`
without changing the topic structure.

---

## 3. Topic Definitions

---

### 3.1 `canlog/node_a/bme280`

**Source:** CAN frame `0x100` decoded by ESP32.  
**Rate:** 1 Hz.  
**QoS:** 1 (at least once).  
**Retained:** No.

#### Schema

| Field | Type | Units | Description |
|-------|------|-------|-------------|
| `ts` | string \| null | ISO-8601 UTC | Timestamp of the sensor read. `null` if SNTP unavailable. |
| `node_id` | string | — | Always `"node_a"` in v1.0 |
| `temp_c` | number | °C | Temperature, 2 d.p. Decoded from fixed-point (÷100) |
| `humidity_pct` | number | %RH | Relative humidity, 2 d.p. |
| `pressure_hpa` | number | hPa | Barometric pressure, 2 d.p. |
| `seq` | integer | — | Frame sequence number 0–255, wraps |

#### Example payload

```json
{
  "ts": "2026-03-15T14:32:07Z",
  "node_id": "node_a",
  "temp_c": 22.45,
  "humidity_pct": 48.10,
  "pressure_hpa": 1013.25,
  "seq": 7
}
```

#### SQLite target table

`sensor_bme280` — one row per message.

---

### 3.2 `canlog/node_a/accel`

**Source:** CAN frame `0x101` decoded by ESP32.  
**Rate:** 1 Hz.  
**QoS:** 1 (at least once).  
**Retained:** No.

#### Schema

| Field | Type | Units | Description |
|-------|------|-------|-------------|
| `ts` | string \| null | ISO-8601 UTC | Timestamp of the sensor read |
| `node_id` | string | — | Always `"node_a"` |
| `ax_raw` | integer | ADC counts | Accel X raw. Convert: `ax_g = ax_raw / 16384.0` at ±2 g FS |
| `ay_raw` | integer | ADC counts | Accel Y raw |
| `az_raw` | integer | ADC counts | Accel Z raw. At rest flat: ≈ +16384 |
| `seq` | integer | — | Shared with gyro topic — same value for same acquisition cycle |

#### Example payload

```json
{
  "ts": "2026-03-15T14:32:07Z",
  "node_id": "node_a",
  "ax_raw": -42,
  "ay_raw": 115,
  "az_raw": 16350,
  "seq": 7
}
```

#### SQLite target table

`sensor_mpu6050` — combined with gyro data. See
[Section 10](#10-subscriber-routing-logic) for join strategy.

---

### 3.3 `canlog/node_a/gyro`

**Source:** CAN frame `0x102` decoded by ESP32.  
**Rate:** 1 Hz.  
**QoS:** 1 (at least once).  
**Retained:** No.

#### Schema

| Field | Type | Units | Description |
|-------|------|-------|-------------|
| `ts` | string \| null | ISO-8601 UTC | Timestamp of the sensor read |
| `node_id` | string | — | Always `"node_a"` |
| `gx_raw` | integer | ADC counts | Gyro X raw. Convert: `gx_dps = gx_raw / 131.0` at ±250 °/s FS |
| `gy_raw` | integer | ADC counts | Gyro Y raw |
| `gz_raw` | integer | ADC counts | Gyro Z raw. At rest: ≈ 0 |
| `seq` | integer | — | Shared with accel topic — matches for same acquisition cycle |

#### Example payload

```json
{
  "ts": "2026-03-15T14:32:07Z",
  "node_id": "node_a",
  "gx_raw": 3,
  "gy_raw": -7,
  "gz_raw": 1,
  "seq": 7
}
```

#### SQLite target table

`sensor_mpu6050` — combined with accel on matching `seq`.

---

### 3.4 `canlog/node_a/heartbeat`

**Source:** CAN frame `0x10F` decoded by ESP32.  
**Rate:** 1 Hz.  
**QoS:** 0 (fire and forget).  
**Retained:** **Yes** — broker stores the last message. A new subscriber
immediately receives the most recent node status without waiting for the
next heartbeat.

#### Schema

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string \| null | ISO-8601 UTC timestamp |
| `node_id` | string | `"node_a"` |
| `fw_version` | string | Firmware version string, e.g. `"1.0"` |
| `uptime_s` | integer | Seconds since Node A last booted (wraps at 255) |
| `status_flags` | integer | Raw bitmap byte from CAN frame — see `/docs/can_frame_spec.md` Section 6 |
| `bme280_ok` | boolean | Decoded from `status_flags` bit 0 — convenience field |
| `mpu6050_ok` | boolean | Decoded from `status_flags` bit 1 — convenience field |
| `relay_active` | boolean | Decoded from `status_flags` bit 2 — convenience field |

> The decoded boolean fields (`bme280_ok`, `mpu6050_ok`, `relay_active`)
> are added by the ESP32 parser for dashboard convenience. The raw
> `status_flags` byte is always included alongside them for completeness.

#### Example payload

```json
{
  "ts": "2026-03-15T14:32:07Z",
  "node_id": "node_a",
  "fw_version": "1.0",
  "uptime_s": 142,
  "status_flags": 3,
  "bme280_ok": true,
  "mpu6050_ok": true,
  "relay_active": false
}
```

#### SQLite target table

`node_status` — one row per heartbeat message (1 Hz).

---

### 3.5 `canlog/node_a/relay`

**Source:** CAN frame `0x200` decoded by ESP32.  
**Rate:** On event only (relay state change).  
**QoS:** 2 (exactly once).  
**Retained:** **Yes** — broker stores the last relay state. Dashboard can
query broker on startup to know current relay state without waiting for
the next event.

#### Schema

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string \| null | ISO-8601 UTC timestamp of the relay event |
| `node_id` | string | `"node_a"` |
| `state` | string | `"on"` or `"off"` |
| `reason` | string | Human-readable reason string |
| `temp_trigger_c` | number | Temperature that triggered the event, 2 d.p. |

**Reason strings:**

| `reason` value | Meaning |
|----------------|---------|
| `"temp_threshold_exceeded"` | Temperature rose above 40 °C (ON event) |
| `"temp_below_hysteresis"` | Temperature fell below 38 °C (OFF event) |
| `"manual_test"` | Activated via firmware test mode |

#### Example payload — relay ON

```json
{
  "ts": "2026-03-15T14:45:22Z",
  "node_id": "node_a",
  "state": "on",
  "reason": "temp_threshold_exceeded",
  "temp_trigger_c": 41.50
}
```

#### Example payload — relay OFF

```json
{
  "ts": "2026-03-15T14:47:08Z",
  "node_id": "node_a",
  "state": "off",
  "reason": "temp_below_hysteresis",
  "temp_trigger_c": 37.82
}
```

#### SQLite target table

`relay_events` — one row per message.

---

### 3.6 `canlog/node_a/fault`

**Source:** CAN frame `0x7FF` decoded by ESP32.  
**Rate:** On event only.  
**QoS:** 1 (at least once).  
**Retained:** No — fault messages are transient events, not persistent state.

#### Schema

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string \| null | ISO-8601 UTC timestamp |
| `node_id` | string | `"node_a"` or `"node_b"` depending on source |
| `fault_code` | integer | Numeric fault code — see `/docs/can_frame_spec.md` Section 7 |
| `fault_code_name` | string | Human-readable name, e.g. `"FAULT_BME280_NAK"` |
| `sub_code` | integer | Driver-specific detail byte (0 if unused) |
| `status_flags` | integer | Raw status flags snapshot at time of fault |
| `description` | string | Short plain-English description of the fault |

#### Example payload

```json
{
  "ts": "2026-03-15T14:33:01Z",
  "node_id": "node_a",
  "fault_code": 1,
  "fault_code_name": "FAULT_BME280_NAK",
  "sub_code": 4,
  "status_flags": 2,
  "description": "BME280 did not ACK on I2C bus. HAL error code: 4."
}
```

#### SQLite target table

Not persisted in v1.0 — faults are logged to the rotating log file only.
Adding a `fault_events` table is a documented future improvement.

---

## 4. Timestamp Handling

All `ts` fields are **ISO-8601 UTC strings** in the format:

```
YYYY-MM-DDTHH:MM:SSZ
```

Example: `"2026-03-15T14:32:07Z"`

**Source of time:** The ESP32 synchronises with an SNTP server
(`pool.ntp.org`) on boot. The timestamp is attached by the ESP32 at the
moment the MQTT message is published — not at the moment the CAN frame
was transmitted. The difference is typically < 20 ms and is acceptable
for this project.

**When SNTP is unavailable:**

- `ts` is set to `null` in all payloads.
- The Python subscriber falls back to `datetime.utcnow()` as the
  timestamp for SQLite writes, and adds a `"ts_source": "subscriber"`
  field to the log entry to flag the fallback.
- SNTP failure is published as a fault frame (`FAULT_SNTP_TIMEOUT`,
  code `0x11`) and logged to `canlog/node_a/fault`.

**Timezone:** All timestamps are UTC. The dashboard converts to local
time for display using the browser's `Intl.DateTimeFormat` API.

---

## 5. QoS Rationale

| Topic | QoS | Reason |
|-------|-----|--------|
| `bme280` | 1 | Sensor data at 1 Hz — at-least-once delivery acceptable. Duplicate rows in SQLite are benign (same seq number, deduplicated in query if needed). Overhead of QoS 2 handshake at 1 Hz is unnecessary. |
| `accel` | 1 | Same rationale as bme280. |
| `gyro` | 1 | Same rationale as bme280. |
| `heartbeat` | 0 | Node health is continuously updated at 1 Hz. A missed heartbeat is non-critical — the next one arrives within 1 s. QoS 0 minimises broker overhead for the highest-frequency management traffic. |
| `relay` | 2 | Relay events are infrequent and safety-relevant. Exactly-once delivery ensures the dashboard alert log and SQLite relay_events table never contain a duplicate or missing state change. |
| `fault` | 1 | Fault events are infrequent but important. At-least-once is sufficient — a duplicate fault log entry is preferable to a missed fault. |

---

## 6. Retained Message Behaviour

Two topics use `retain = true`:

**`canlog/node_a/heartbeat` (retained):**  
Any client that subscribes after Node A has been running will immediately
receive the most recent heartbeat without waiting up to 1 s. The dashboard
`StatusBadge` component uses this to show node health immediately on page
load.

**`canlog/node_a/relay` (retained):**  
A client that connects after a relay ON event will immediately know the
relay is active — it does not have to wait for the next state change.
The dashboard reads this on startup to set the initial relay indicator
state.

**Clearing a retained message:**  
If Node A is decommissioned or the relay topic needs to be reset, publish
an empty payload (`""`) to the topic with `retain = true`. Mosquitto will
delete the retained message.

---

## 7. TLS Configuration

MQTT traffic between the ESP32 (Node B) and the Raspberry Pi broker
travels over TLS on port 8883. Plain-text MQTT on port 1883 is bound to
`localhost` only and used solely by the Python subscriber running on
the Pi itself.

**Certificate setup summary:**

```
ca.key + ca.crt        ← Self-signed Certificate Authority (10-year validity)
server.key + server.crt ← Broker server certificate, signed by CA
```

**Mosquitto TLS configuration** (`/etc/mosquitto/conf.d/tls.conf`):

```
listener 8883
cafile   /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile  /etc/mosquitto/certs/server.key
require_certificate false
tls_version tlsv1.2
```

**ESP32 TLS configuration:**  
`ca.crt` is embedded in firmware as a `const char[]` in `ca_cert.h`.
`WiFiClientSecure` is configured with `espClient.setCACert(ca_cert)`.
No client certificate is used (broker does not require it).

**Verifying TLS from the Pi:**

```bash
mosquitto_sub --cafile /etc/mosquitto/certs/ca.crt \
              -h localhost -p 8883 \
              -t canlog/# -v
```

A Wireshark capture of the TLS handshake is stored in
[`/debug_logs/mqtt_publish.pcapng`](../debug_logs/).

---

## 8. Broker Configuration Reference

Full Mosquitto configuration for reference. Split across two files
per Mosquitto best practice.

**`/etc/mosquitto/conf.d/default.conf`** (plain, localhost only):

```
listener 1883 localhost
allow_anonymous true
```

**`/etc/mosquitto/conf.d/tls.conf`** (TLS, network):

```
listener 8883
cafile   /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile  /etc/mosquitto/certs/server.key
require_certificate false
tls_version tlsv1.2
allow_anonymous true

max_queued_messages 1000
max_inflight_messages 20
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type information
```

**Persistence:** Enabled so QoS 1/2 messages and retained messages survive
a Mosquitto restart or Pi reboot. Persistence file is stored in
`/var/lib/mosquitto/`.

---

## 9. Full Payload Examples

A complete sequence of messages as they appear during one 1-second
acquisition cycle at steady state:

```
Topic: canlog/node_a/bme280
{"ts":"2026-03-15T14:32:07Z","node_id":"node_a","temp_c":22.45,
 "humidity_pct":48.10,"pressure_hpa":1013.25,"seq":42}

Topic: canlog/node_a/accel
{"ts":"2026-03-15T14:32:07Z","node_id":"node_a",
 "ax_raw":-42,"ay_raw":115,"az_raw":16350,"seq":42}

Topic: canlog/node_a/gyro
{"ts":"2026-03-15T14:32:07Z","node_id":"node_a",
 "gx_raw":3,"gy_raw":-7,"gz_raw":1,"seq":42}

Topic: canlog/node_a/heartbeat  [retained]
{"ts":"2026-03-15T14:32:07Z","node_id":"node_a","fw_version":"1.0",
 "uptime_s":142,"status_flags":3,"bme280_ok":true,
 "mpu6050_ok":true,"relay_active":false}
```

And during a relay trigger event (interleaved with the above):

```
Topic: canlog/node_a/relay  [retained, QoS 2]
{"ts":"2026-03-15T14:32:07Z","node_id":"node_a","state":"on",
 "reason":"temp_threshold_exceeded","temp_trigger_c":41.50}
```

---

## 10. Subscriber Routing Logic

The Python subscriber (`mqtt_subscriber.py`) subscribes to `canlog/#`
and routes each message by topic string. Below is the routing pseudocode:

```python
def on_message(client, userdata, msg):
    topic = msg.topic
    payload = json.loads(msg.payload.decode("utf-8"))

    if topic == "canlog/node_a/bme280":
        db.insert_bme280(payload)

    elif topic == "canlog/node_a/accel":
        # Buffer accel until matching gyro arrives (same seq)
        accel_buffer[payload["seq"]] = payload

    elif topic == "canlog/node_a/gyro":
        seq = payload["seq"]
        if seq in accel_buffer:
            db.insert_mpu6050(accel_buffer.pop(seq), payload)
        else:
            # Gyro arrived before accel — buffer gyro instead
            gyro_buffer[seq] = payload

    elif topic == "canlog/node_a/heartbeat":
        db.upsert_node_status(payload)

    elif topic == "canlog/node_a/relay":
        db.insert_relay_event(payload)

    elif topic == "canlog/node_a/fault":
        logger.error("Fault from %s: %s", payload.get("node_id"),
                     payload.get("description"))
        # Not persisted to DB in v1.0 — log only

    else:
        logger.warning("Unhandled topic: %s", topic)
```

**Accel/gyro join strategy:** Frames `0x101` (accel) and `0x102` (gyro)
share a sequence number and are transmitted in the same 1 Hz cycle. They
arrive within milliseconds of each other over MQTT. The subscriber buffers
whichever arrives first and waits for the matching `seq` from the other.
A buffer entry that is not matched within 5 seconds is discarded with a
warning log — this handles the edge case where one frame is dropped by the
QoS 1 delivery without flooding the buffer.

---

## 11. Testing the Pipeline Manually

### 11.1 Subscribe to all topics

```bash
mosquitto_sub --cafile /etc/mosquitto/certs/ca.crt \
              -h localhost -p 8883 \
              -t "canlog/#" -v
```

### 11.2 Publish a test BME280 message

```bash
mosquitto_pub --cafile /etc/mosquitto/certs/ca.crt \
              -h localhost -p 8883 \
              -t "canlog/node_a/bme280" \
              -m '{"ts":"2026-03-15T14:00:00Z","node_id":"node_a","temp_c":22.45,"humidity_pct":48.10,"pressure_hpa":1013.25,"seq":1}'
```

### 11.3 Check SQLite was written

```bash
sqlite3 /var/lib/canlog/canlog.db \
  "SELECT * FROM sensor_bme280 ORDER BY id DESC LIMIT 5;"
```

### 11.4 Check retained relay state

```bash
mosquitto_sub --cafile /etc/mosquitto/certs/ca.crt \
              -h localhost -p 8883 \
              -t "canlog/node_a/relay" -C 1
# -C 1 exits after receiving one message — the retained payload
```

### 11.5 Simulate a fault

```bash
mosquitto_pub --cafile /etc/mosquitto/certs/ca.crt \
              -h localhost -p 8883 \
              -t "canlog/node_a/fault" \
              -m '{"ts":"2026-03-15T14:00:00Z","node_id":"node_a","fault_code":1,"fault_code_name":"FAULT_BME280_NAK","sub_code":0,"status_flags":2,"description":"Test fault injection."}'
```

Verify the fault appears in `/var/log/canlog/subscriber.log` at `ERROR`
level and does **not** create a row in SQLite (v1.0 behaviour).

---

*CANLOG-01 · MQTT Topics · v1.0 · MIT License*
