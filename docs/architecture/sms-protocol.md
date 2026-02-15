# SMS Protocol Specification

## Overview

The SMS protocol provides a fallback communication channel for transmitting vehicle passage data when mobile data connectivity is unavailable. Rangers' devices send compact passage data via SMS to a Twilio-provisioned phone number. Twilio forwards the SMS content to a Supabase Edge Function via webhook, which parses the data and inserts a passage record.

---

## V1 Format Definition

### Format String

```
V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>
```

### Example

```
V1|BNP-A|BA1PA1234|CAR|1709123456|9801
```

### Field Descriptions

| Position | Field | Type | Description | Example |
|----------|-------|------|-------------|---------|
| 1 | Version | string | Protocol version identifier. Always `V1` for this version. | `V1` |
| 2 | Checkpost Code | string | Unique code identifying the checkpost (from `checkposts.code`). | `BNP-A` |
| 3 | Plate Number | string | Normalized vehicle plate number (English transliteration). | `BA1PA1234` |
| 4 | Vehicle Type Code | string | Short code for the vehicle type. See mapping table below. | `CAR` |
| 5 | Timestamp Epoch | integer | Unix epoch timestamp (seconds) of when the vehicle was recorded. This is the `recorded_at` time from the device. | `1709123456` |
| 6 | Ranger Phone Suffix | string | Last 4 digits of the ranger's phone number. Used to identify which ranger sent the SMS. | `9801` |

### Delimiter

The pipe character `|` is used as the field delimiter. This character is unlikely to appear in any field values (plate numbers, checkpost codes, etc.).

---

## Encoding Rules

Encoding is performed by `SmsEncoder.encode()` in `/packages/shared/lib/src/utils/sms_encoder.dart`.

### Input

| Parameter | Source |
|-----------|--------|
| Checkpost code | From the ranger's assigned checkpost configuration |
| Plate number | Normalized plate number (output of `PlateNormalizer.normalize()`) |
| Vehicle type | Selected vehicle type enum value |
| Recorded at | Device timestamp at camera shutter moment |
| Ranger phone | Last 4 digits of the ranger's phone number from their profile |

### Process

1. Start with version prefix `V1`.
2. Append the checkpost code as-is.
3. Append the normalized plate number (already transliterated to English).
4. Convert the vehicle type enum to its short code (see mapping below).
5. Convert `recorded_at` to Unix epoch seconds (integer, no fractional seconds).
6. Extract the last 4 digits of the ranger's phone number.
7. Join all fields with the `|` delimiter.

### Output

A single string of no more than 160 characters suitable for a single SMS message.

### Example Encoding

```
Input:
  checkpost_code = "BNP-A"
  plate_number = "BA1PA1234"
  vehicle_type = VehicleType.car
  recorded_at = 2024-02-28T10:30:56Z (epoch: 1709123456)
  ranger_phone = "+9779801234567" (suffix: "4567")

Output:
  "V1|BNP-A|BA1PA1234|CAR|1709123456|4567"
```

---

## Decoding Rules

Decoding is performed by `SmsDecoder.decode()` in `/packages/shared/lib/src/utils/sms_decoder.dart` and by `sms-parser.ts` in `/supabase/functions/_shared/sms-parser.ts`.

### Process

1. Split the incoming SMS body by the `|` delimiter.
2. Validate that there are exactly 6 fields.
3. Validate that the first field is `V1` (version check).
4. Extract each field:
   - **Checkpost code** (field 2): Look up in `checkposts` table to get `checkpost_id` and `segment_id`.
   - **Plate number** (field 3): Use as-is (already normalized).
   - **Vehicle type code** (field 4): Map back to the full vehicle type string using the code mapping.
   - **Timestamp epoch** (field 5): Convert from Unix epoch seconds to `timestamptz`.
   - **Ranger phone suffix** (field 6): Look up in `user_profiles` where `phone_number` ends with this suffix.
5. Generate a deterministic `client_id` for deduplication (e.g., UUID v5 from a hash of the SMS content).
6. Return a structured passage record ready for database insertion.

### Validation Errors

| Error | Condition |
|-------|-----------|
| Invalid format | Not exactly 6 pipe-delimited fields |
| Unsupported version | First field is not `V1` |
| Unknown checkpost | Checkpost code not found in database |
| Unknown vehicle type | Vehicle type code not in mapping |
| Invalid timestamp | Timestamp is not a valid integer or is in the future |
| Unknown ranger | No ranger found with matching phone suffix |

---

## Vehicle Type Code Mapping

| Enum Value | SMS Code | Description |
|------------|----------|-------------|
| car | CAR | Standard car / sedan |
| jeep | JEP | Jeep / SUV |
| motorcycle | MOT | Motorcycle / two-wheeler |
| bus | BUS | Bus (public or private) |
| truck | TRK | Truck / heavy vehicle |
| mini_truck | MTK | Mini truck / pickup |
| auto | AUT | Auto-rickshaw / three-wheeler |
| tractor | TRC | Tractor |
| other | OTH | Any other vehicle type |

### Code Design Rationale

- All codes are exactly 3 characters for consistent message length.
- Codes are uppercase ASCII for reliability across SMS gateways.
- Codes are mnemonic (first three consonants or abbreviation) for human readability during debugging.

---

## Character Limit Considerations

### SMS Limit: 160 Characters (GSM-7 Encoding)

A single SMS message using GSM-7 encoding supports 160 characters. The V1 format is designed to fit within this limit.

### Maximum Field Lengths

| Field | Max Length | Notes |
|-------|-----------|-------|
| Version (`V1`) | 2 | Fixed |
| Delimiters (5x `\|`) | 5 | Fixed |
| Checkpost code | 10 | Per database constraint |
| Plate number | 20 | Generous upper bound for Nepali plates |
| Vehicle type code | 3 | Fixed, see mapping |
| Timestamp epoch | 10 | Unix epoch in seconds (10 digits until 2286) |
| Ranger phone suffix | 4 | Fixed, last 4 digits |

**Maximum total: 2 + 5 + 10 + 20 + 3 + 10 + 4 = 54 characters**

This provides significant headroom within the 160-character limit, allowing for future format extensions if needed.

### Encoding Note

The V1 format uses only ASCII characters (letters, digits, pipe, hyphen). This ensures GSM-7 encoding is used (not UCS-2, which would halve the character limit to 70). Nepali/Devanagari characters are never included in the SMS because plate numbers are normalized to English transliteration before encoding.

---

## Twilio Webhook Handling

### Inbound Flow

```
Ranger's Phone
    |
    | SMS: "V1|BNP-A|BA1PA1234|CAR|1709123456|4567"
    |
    v
Twilio Phone Number
    |
    | HTTP POST (webhook)
    |
    v
Supabase Edge Function: /functions/v1/sms-webhook
    |
    |-- 1. Verify Twilio signature (X-Twilio-Signature header)
    |-- 2. Extract SMS body from POST parameters
    |-- 3. Parse V1 format (using sms-parser.ts)
    |-- 4. Look up checkpost_id, segment_id, ranger_id
    |-- 5. Generate deterministic client_id
    |-- 6. INSERT into vehicle_passages (source='sms')
    |-- 7. Auto-match trigger fires
    |
    v
Return TwiML response (200 OK)
```

### Twilio Webhook POST Parameters

Twilio sends a POST request with `application/x-www-form-urlencoded` body. Relevant fields:

| Parameter | Description |
|-----------|-------------|
| `Body` | The SMS message text (contains V1 format string) |
| `From` | Sender's phone number (the ranger's device) |
| `To` | Twilio phone number (the gateway) |
| `MessageSid` | Unique Twilio message identifier |

### Twilio Signature Verification

The Edge Function must verify the `X-Twilio-Signature` header to ensure the request genuinely came from Twilio.

**Process:**
1. Construct the full URL of the webhook endpoint.
2. Sort all POST parameters alphabetically by key.
3. Append each key-value pair to the URL.
4. Compute HMAC-SHA1 of the resulting string using the Twilio Auth Token as the key.
5. Base64-encode the HMAC result.
6. Compare with the `X-Twilio-Signature` header value.

If the signature does not match, return 403 Forbidden.

### TwiML Response

The webhook must return a valid TwiML response (XML) with a 200 status code, even if the SMS processing fails:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>Received</Message>
</Response>
```

For errors, still return 200 with TwiML (Twilio expects 200). Log the error internally.

### Edge Function Error Handling

| Scenario | Response | Action |
|----------|----------|--------|
| Valid SMS, new passage | 200 + TwiML | Insert passage, trigger matching |
| Valid SMS, duplicate client_id | 200 + TwiML | `ON CONFLICT DO NOTHING`, log as duplicate |
| Invalid V1 format | 200 + TwiML | Log error, do not insert |
| Unknown checkpost code | 200 + TwiML | Log error, do not insert |
| Invalid Twilio signature | 403 | Reject request |
| Server error | 500 | Log error, Twilio will retry |

---

## Future Considerations

### V2 Format (Not Implemented)

If future requirements exceed the V1 format, a V2 format could include:
- Direction indicator (entry/exit) if determined at the checkpost
- Photo hash for verification
- Additional metadata

The version field (`V1`) allows the decoder to route to the appropriate parser. Unknown versions should be logged and rejected gracefully.

---

## Related Documents

- `/packages/shared/lib/src/utils/sms_encoder.dart` -- Dart implementation of encoding
- `/packages/shared/lib/src/utils/sms_decoder.dart` -- Dart implementation of decoding
- `/packages/shared/lib/src/constants/sms_format.dart` -- SMS format constants
- `/supabase/functions/_shared/sms-parser.ts` -- TypeScript implementation for Edge Function
- `/supabase/functions/sms-webhook/index.ts` -- SMS webhook Edge Function
- `/docs/architecture/offline-sync.md` -- When and why SMS fallback triggers
