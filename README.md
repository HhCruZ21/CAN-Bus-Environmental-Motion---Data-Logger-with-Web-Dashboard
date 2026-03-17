# CAN-Bus-Environmental-Motion---Data-Logger-with-Web-Dashboard

## 10. Repository Structure

The repository must be structured as follows to meet both technical and portfolio presentation requirements:

| Path | Contents |
|------|----------|
| `README.md` | Project overview, hardware setup photo, build instructions, quick-start guide |
| `/docs/architecture.md` | System architecture narrative, data flow description |
| `/docs/can_frame_spec.md` | Complete CAN frame specification (mirrors Section 5.1) |
| `/docs/mqtt_topics.md` | MQTT topic hierarchy and payload schemas (mirrors Section 5.2) |
| `/docs/hardware_setup.md` | Wiring diagram, pinout tables, component photos |
| `/docs/Functional_Requirements.xlsx` | Refer this document for Functional Requirements |
| `/docs/Non_Functional_Requirements.xlsx` | Refer this document for Non-Functional Requirements |
| `/docs/Testing_Requirements.xlsx` | Refer this document for Testing Levels and Requirements |
| `/docs/BOM.docx` | Refer this document for Bill of Materials |
| `/docs/Debug_Req_Proofs.docx.docx` | Refer this document for required debugging proofs |
| `/firmware/node_a/` | STM32 CubeIDE project: drivers, main loop, CAN TX, relay logic |
| `/firmware/node_b/` | ESP32 Arduino project: CAN RX, MQTT bridge, TLS config |
| `/backend/` | Python subscriber, Flask REST API, SQLite schema migration script |
| `/frontend/` | SolidJS or TypeScript dashboard, package.json, build script |
| `/tests/unit/` | Unity-based C unit tests for firmware modules (host-runnable) |
| `/tests/integration/` | Python integration test script (MQTT mock + SQLite check) |
| `/debug_logs/` | PulseView .sr captures, Wireshark .pcapng files, companion READMEs |
| `/diagrams/` | System architecture diagram (SVG/PNG), CAN bus topology diagram |
| `/ci/` | GitHub Actions workflow YAML or local test runner script |
