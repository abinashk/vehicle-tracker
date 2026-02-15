-- Seed Data: Banke National Park pilot deployment
-- Description: Initial data for the Banke National Park highway segment with two checkposts

-- =============================================================================
-- Park: Banke National Park
-- =============================================================================
INSERT INTO public.parks (id, name, code)
VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Banke National Park',
    'BNP'
);

-- =============================================================================
-- Highway Segment: Banke Highway Segment
-- Distance: 45 km, Max speed: 40 km/h, Min speed: 10 km/h
-- Computed thresholds:
--   min_travel_time = (45 / 40) * 60 = 67.50 minutes
--   max_travel_time = (45 / 10) * 60 = 270.00 minutes (4.5 hours)
-- =============================================================================
INSERT INTO public.highway_segments (id, park_id, name, distance_km, max_speed_kmh, min_speed_kmh)
VALUES (
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Banke Highway Segment',
    45.00,
    40.00,
    10.00
);

-- =============================================================================
-- Checkpost A: East Gate (position_index 0)
-- =============================================================================
INSERT INTO public.checkposts (id, segment_id, name, code, position_index)
VALUES (
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'East Gate Checkpost',
    'BNP-A',
    0
);

-- =============================================================================
-- Checkpost B: West Gate (position_index 1)
-- =============================================================================
INSERT INTO public.checkposts (id, segment_id, name, code, position_index)
VALUES (
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'West Gate Checkpost',
    'BNP-B',
    1
);
