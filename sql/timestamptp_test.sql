CREATE EXTENSION timestamptp;

SET DateStyle TO Postgres;
SET TimeZone TO EST;

--
-- See that the timezone offsets are preserved to minute resolution
SELECT timestamptp_in('2021-01-02T03:04:05-0123');

--
-- Use cast syntax
SELECT '2010-01-02 03:04:05 +06:07'::timestamptp;
SELECT '2000-01-01 00:00:00Z'::timestamptp;

--
-- Extract timestamptz and offset from a timestamptp
SELECT get_timestamp('2000-01-01 00:00:00 -07:00'::timestamptp);
SELECT get_offset('2000-01-01 00:00:00 -07:00'::timestamptp);

--
-- Construct a timestamptp from a timestamptz and an offset
SELECT make_timestamptp('2000-01-01 00:00:00 +06:00'::timestamptz, -300);

--
-- Error cases with timezone offset overflow
SELECT '2000-01-01 00:00:00 +16'::timestamptp;
SELECT '2000-01-01 00:00:00 -16'::timestamptp;
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, -960);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, 960);

--
-- Just under the overflow
SELECT '2000-01-01 00:00:00 +15:59'::timestamptp;
SELECT '2000-01-01 00:00:00 -15:59'::timestamptp;
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, -959);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, 959);

--
-- Cast a timestamptp to timestamptz
SELECT ('2000-01-01 00:00:00 +07:00'::timestamptp)::timestamptz;

--
-- Cast a timestamptz to timestamptp using implicit local timezone
SELECT ('2000-01-01 00:00:00 +00:00'::timestamptz)::timestamptp;

--
-- Tests for converting timestamptz to timestamptp in a DST-aware timezone
-- These two timestamps are on different sides of a DST transition, so the result
-- should have different offsets
SELECT make_timestamptp('2022-03-12 12:00:00Z'::timestamptz, 'America/New_York');
SELECT make_timestamptp('2022-03-13 12:00:00Z'::timestamptz, 'America/New_York');

--
-- Tests make_timestamptp() using other formats for specifying a timezone
-- as text. Offset spec, timezone abbreviations, and full timezone names should
-- be accepted.
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, '-05:00'::text);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, '+0500'::text);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, 'EST'::text);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, 'EDT'::text);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, 'PST'::text);
SELECT make_timestamptp('2000-01-01 00:00:00 +00:00'::timestamptz, 'US/Eastern'::text);
