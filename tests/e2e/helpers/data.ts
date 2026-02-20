/**
 * Seed data IDs and values from seed.sql
 */
export const SEED = {
  park: {
    id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    code: "BNP",
    name: "Bardia National Park",
  },
  segment: {
    id: "b2c3d4e5-f6a7-8901-bcde-f12345678901",
    distanceKm: 45,
    maxSpeedKmh: 40,
    minSpeedKmh: 10,
    minTravelMinutes: 67.5,
    maxTravelMinutes: 270,
  },
  checkposts: {
    east: {
      id: "c3d4e5f6-a7b8-9012-cdef-123456789012",
      code: "BNP-A",
      positionIndex: 0,
    },
    west: {
      id: "d4e5f6a7-b8c9-0123-defa-234567890123",
      code: "BNP-B",
      positionIndex: 1,
    },
  },
};

/**
 * Generates a random client ID
 */
export function generateClientId(): string {
  return crypto.randomUUID();
}

/**
 * Builds a default passage insert object with optional overrides
 */
export function passage(overrides: Record<string, unknown> = {}) {
  return {
    client_id: generateClientId(),
    plate_number: `TEST-${Date.now()}`,
    vehicle_type: "car",
    checkpost_id: SEED.checkposts.east.id,
    segment_id: SEED.segment.id,
    recorded_at: new Date().toISOString(),
    ranger_id: "<must be provided>",
    source: "app",
    ...overrides,
  };
}
