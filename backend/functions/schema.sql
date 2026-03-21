CREATE TABLE sensor_bme280 (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc  TEXT NOT NULL,
    node_id        TEXT NOT NULL,
    temp_c         REAL,
    humidity_pct   REAL,
    pressure_hpa   REAL,
    seq            INTEGER
);

CREATE TABLE sensor_mpu6050 (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc  TEXT NOT NULL,
    node_id        TEXT NOT NULL,
    ax_raw         INTEGER, ay_raw INTEGER, az_raw INTEGER,
    gx_raw         INTEGER, gy_raw INTEGER, gz_raw INTEGER,
    seq            INTEGER
);

CREATE TABLE relay_events (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc  TEXT NOT NULL,
    state          TEXT NOT NULL,   -- 'on' or 'off'
    reason         TEXT,
    temp_trigger_c REAL
);

CREATE TABLE node_status (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc  TEXT NOT NULL,
    node_id        TEXT NOT NULL,
    fw_version     TEXT,
    uptime_s       INTEGER,
    status_flags   INTEGER
);