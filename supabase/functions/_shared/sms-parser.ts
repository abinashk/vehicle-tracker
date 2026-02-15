// SMS V1 compact format parser.
// Format: V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>

const SMS_VERSION = 'V1';
const FIELD_COUNT = 6;
const SEPARATOR = '|';

const VEHICLE_TYPE_MAP: Record<string, string> = {
  CAR: 'car',
  JSV: 'jeep_suv',
  MNB: 'minibus',
  BUS: 'bus',
  TRK: 'truck',
  TNK: 'tanker',
  MCY: 'motorcycle',
  ARK: 'auto_rickshaw',
  TRC: 'tractor',
  OTH: 'other',
};

export interface ParsedSms {
  checkpostCode: string;
  plateNumber: string;
  vehicleType: string;
  recordedAt: Date;
  rangerPhoneSuffix: string;
}

export function parseSmsBody(body: string): ParsedSms {
  const parts = body.trim().split(SEPARATOR);

  if (parts.length !== FIELD_COUNT) {
    throw new Error(
      `Invalid SMS format: expected ${FIELD_COUNT} fields, got ${parts.length}`,
    );
  }

  const [version, checkpostCode, plateNumber, vehicleTypeCode, epochStr, rangerPhoneSuffix] = parts;

  if (version !== SMS_VERSION) {
    throw new Error(`Unsupported SMS version: ${version}`);
  }

  const vehicleType = VEHICLE_TYPE_MAP[vehicleTypeCode];
  if (!vehicleType) {
    throw new Error(`Unknown vehicle type code: ${vehicleTypeCode}`);
  }

  const epochSeconds = parseInt(epochStr, 10);
  if (isNaN(epochSeconds)) {
    throw new Error(`Invalid timestamp: ${epochStr}`);
  }

  return {
    checkpostCode,
    plateNumber,
    vehicleType,
    recordedAt: new Date(epochSeconds * 1000),
    rangerPhoneSuffix,
  };
}
