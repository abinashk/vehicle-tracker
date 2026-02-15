# Requirements Document: National Park Vehicle Speed Monitoring System

## 1. Context & Problem Statement

Vehicles driving through highway segments that pass through Nepal's national parks frequently exceed speed limits, endangering wildlife and park visitors. There is a legal framework backing speed enforcement on these segments.

The system will use a **time-based speed detection** approach: two checkposts at each end of a highway segment record when a vehicle enters and exits. If the travel time is below a threshold (implying speeding), the ranger at the exit checkpost is alerted to stop the vehicle.

---

## 2. System Overview

| Aspect | Decision |
|--------|----------|
| **Platforms** | Mobile (iOS + Android) + Web dashboard |
| **Mobile framework** | Flutter |
| **Users** | Park rangers (field) + Park management (admin) |
| **Deployment scope** | Pilot: **Banke National Park**, 1 highway segment (2 checkposts). Designed to expand to multiple parks/segments. |
| **Highway segment distance** | 30–70 km |
| **Daily vehicle volume** | 500–2,000 vehicles per checkpost |
| **Operating hours** | 24/7 |
| **Budget** | Under $5,000 USD (development + first year operations) |
| **Timeline** | Working first version within a few months |
| **Language** | English first; Nepali localization added later |

---

## 3. User Roles

### 3.1 Ranger (Mobile App)
- Park rangers/staff stationed at checkposts
- Use **personal smartphones** (mixed Android/iOS)
- Authenticate with **username + password** (credentials created by admin)
- Number of rangers per checkpost varies by shift/season (1 during low traffic, multiple during peak)
- **Pilot scale**: Under 10 ranger accounts total

### 3.2 Admin (Web Dashboard)
- Park management (warden / chief ranger)
- Accesses dashboard from **office with reliable internet**
- Manages ranger accounts, highway segments, thresholds (speed limit + distance)
- Reviews vehicle logs, violations, and unmatched entries
- Resolves data issues (unmatched entries, duplicates)

---

## 4. Core Functional Requirements

### 4.1 Vehicle Entry/Exit Recording
- Ranger takes a **photo** of the vehicle's license plate using the phone camera
- **OCR** extracts the plate number automatically; ranger **verifies and corrects** if needed
- Ranger selects **vehicle type** from a dropdown: Car, Jeep/SUV, Minibus, Bus, Truck, Tanker, Motorcycle, Auto-rickshaw, Tractor, Other
- System records: plate number, vehicle type, timestamp, checkpost ID, ranger ID
- **Both checkposts function as both entry and exit** (two-way highway)
- A vehicle's first record at one checkpost = entry; the matching record at the other checkpost = exit

### 4.2 Speed & Overstay Violation Detection
- When a vehicle is recorded at a checkpost, the system checks for a matching entry from the opposite checkpost
- **Two violation types** are detected:

**Speeding (too fast):**
- If travel time < **minimum threshold** → vehicle was speeding
- Triggers a **SPEEDING** alert at the exit checkpost

**Overstay (too slow / suspected illegal activity):**
- If travel time > **maximum threshold** → vehicle stayed too long inside the park (potential poaching/illegal activity)
- Triggers an **OVERSTAY** alert at the exit checkpost when the vehicle finally exits
- **Proactive overstay alert**: If a vehicle has not exited after the max threshold time has elapsed, the system proactively alerts the **entry checkpost ranger** (via push notification / queued for next sync) and the **admin** (via web dashboard) — even before the vehicle exits

**Threshold configuration:**
- Admin configures **speed limit**, **minimum speed**, and **segment distance** via web dashboard
- System auto-calculates minimum and maximum travel times (e.g., 50 km at max 40 km/h → min 75 min; 50 km at min 15 km/h → max 200 min)
- Same thresholds for all vehicle types initially; per-type thresholds as a future enhancement

### 4.3 Alert & Enforcement
- When a violation is detected (speeding OR overstay), the exit checkpost ranger receives:
  - Visual + audio alert on the app
  - **Clear label**: "SPEEDING" or "OVERSTAY" to distinguish violation type
  - Vehicle details: plate number, vehicle type, entry time, travel time, how much outside threshold
- Ranger is instructed to **stop the vehicle**
- Ranger records the **outcome**: warned, fined, vehicle details, notes (free-text) — same outcome options for both violation types in v1
- Outcome is stored as part of the violation record

**Proactive overstay alerts:**
- When a vehicle exceeds the max travel time without exiting, the server triggers:
  - Push notification to the **entry checkpost ranger** (queued if offline, delivered on next sync)
  - Alert on the **admin web dashboard**
- This allows rangers/admin to initiate a search or investigation before the vehicle exits

### 4.4 Duplicate Handling
- If multiple rangers photograph the same vehicle at the same checkpost, **duplicates are allowed**
- Admin can clean up duplicates via the web dashboard if needed

### 4.5 Unmatched Entry Resolution
- If a vehicle has an entry record but no corresponding exit (vehicle stopped in park, ranger missed it, etc.), the entry remains open
- Admin manually resolves unmatched entries via the web dashboard

---

## 5. License Plate Requirements

### 5.1 Formats to Support
The OCR system must recognize multiple plate formats currently in circulation in Nepal:

| Format | Example (English) | Example (Devanagari) |
|--------|-------------------|---------------------|
| New provincial | Ba 1 Pa 1234 | बा १ पा १२३४ |
| Old zone-based | Na 1 Ja 1234 | ना १ ज १२३४ |
| Government (red plates) | Generic OCR + manual correction | — |
| Diplomatic (blue plates) | Generic OCR + manual correction | — |
| Tourist plates | Generic OCR + manual correction | — |

### 5.2 Script Support
- Plates may be in **Devanagari script** or **English/Latin script**
- OCR must handle both scripts
- Internally, the system should normalize plates to a canonical format for matching (e.g., always store as English transliteration)

### 5.3 OCR Accuracy
- OCR accuracy will be lower at night (phone flash) — manual correction by ranger covers the gap
- The primary goal of OCR is to **speed up data entry**, not to be 100% autonomous

---

## 6. Connectivity & Data Sync

This is the most critical architectural challenge. Checkposts have **mostly offline** connectivity.

### 6.1 Primary Sync: Mobile Data
- When mobile data is available, the app syncs records to a **central server**
- Exit checkpost pulls entry records from the server to check for matches
- Sync should be **opportunistic**: app syncs whenever connectivity is detected

### 6.2 Fallback: SMS to Server
- When mobile data is unavailable, the app sends an **SMS** containing the plate number + timestamp to a **server-side SMS gateway** (e.g., Twilio)
- The server ingests the SMS data and makes it available to the other checkpost when that checkpost is online
- SMS format: compact encoding of plate number + timestamp + checkpost ID + vehicle type within 160 characters

### 6.3 Offline Operation
- The app must be **fully functional offline** for recording entries
- Entry records are queued locally and synced when connectivity returns
- For exit matching: the app checks its **local cache** of synced entry records
- If no match is found locally (data hasn't synced yet), the app should indicate that the match check is **pending** and retry when connectivity is available

### 6.4 Data Conflict Resolution
- Server timestamp is authoritative for sync conflicts
- Entry records are append-only (no edits to past records from mobile)

---

## 7. Photo & Evidence Requirements

### 7.1 Photo Storage
- Photos are stored **locally on the device**
- Photos are synced to the server **optionally** when connectivity allows (not blocking)
- Photo + timestamp is **sufficient legal evidence** (no GPS or tamper-proofing required)

### 7.2 Photo Quality
- Daytime: standard phone camera quality
- Nighttime: phone camera flash; accept lower quality, ranger corrects OCR manually
- No special hardware required

---

## 8. Data Retention & Reporting

### 8.1 Retention
- All records (entries, exits, violations, photos) retained for **1 year**
- Automatic cleanup of records older than 1 year

### 8.2 Reporting (Web Dashboard)
- **Basic** reporting only:
  - List/log of all vehicle passages (filterable by date, checkpost, vehicle type)
  - List of violations with outcome details
  - Unmatched entries requiring admin resolution
  - Basic counts (vehicles per day, violations per day)

---

## 9. Non-Functional Requirements

### 9.1 Performance
- OCR processing: on-device, should complete within a few seconds
- Speed check (matching entry to exit): near-instant from local cache; dependent on sync latency when data hasn't been cached

### 9.2 Security
- Username/password authentication for rangers
- Admin authentication for web dashboard
- No sensitive personal data stored beyond plate numbers and ranger IDs
- HTTPS for all server communication

### 9.3 Scalability
- Design for 1 park / 1 segment initially
- Data model and API should support multiple parks and segments without rearchitecting
- Expected scale: 500–2,000 records/day/checkpost (low for a database)

### 9.4 Cost Constraints
- Total budget under $5,000 (dev + year 1 ops)
- Hosting: use free tiers of cloud services where possible
- OCR: on-device (no per-request API costs)
- SMS gateway: costs per SMS — mobile data is down ~5–10% of the time, so SMS volume is low (estimated 50–200 SMS/day worst case)

---

## 10. Out of Scope (v1)

- Per-vehicle-type speed thresholds (future enhancement)
- Nepali language UI (future enhancement)
- Integration with government vehicle registration database
- Automatic vehicle type detection from photos
- Auto-deduplication of records
- Tamper-proof / blockchain-based evidence records
- Real-time GPS tracking of vehicles within the park
- Driver identification (only plate number, not driver)

---

## 11. Resolved Decisions Summary

All open questions have been resolved:

| Question | Resolution |
|----------|-----------|
| Pilot park | Banke National Park |
| Special plate formats | Generic OCR + manual correction for government, diplomatic, tourist plates |
| SMS volume | Mobile data down ~5–10% → low SMS usage, manageable cost |
| Speed limit | Varies by park; admin-configurable via dashboard (max speed + min speed + distance → auto-calculated min/max travel time thresholds) |
| Overstay detection | Dual threshold: too fast = SPEEDING, too slow = OVERSTAY (poaching concern). Proactive alert to entry checkpost + admin if vehicle exceeds max time without exiting. |
| Vehicle type list | Car, Jeep/SUV, Minibus, Bus, Truck, Tanker, Motorcycle, Auto-rickshaw, Tractor, Other |
| Ranger count (pilot) | Under 10 accounts |
| Admin access | Office with reliable internet |

---

*This requirements document is complete. All requirements have been clarified and finalized. Ready for implementation planning upon approval.*
