\echo Use "CREATE EXTENSION timestamptp" to load this file. \quit

CREATE FUNCTION timestamptp_in(cstring) RETURNS timestamptp
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION timestamptp_out(timestamptp) RETURNS cstring
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE timestamptp (
    INPUT = timestamptp_in,
    OUTPUT = timestamptp_out,
    INTERNALLENGTH = 10,
    ALIGNMENT = double,
    STORAGE = plain,
    CATEGORY = 'D'
);


CREATE FUNCTION get_timestamp(timestamptp) RETURNS timestamptz
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION get_offset(timestamptp) RETURNS int2
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION make_timestamptp(timestamptz, integer) RETURNS timestamptp
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION make_timestamptp(timestamptz, text) RETURNS timestamptp
AS '$libdir/timestamptp', 'make_timestamptp_in_timezone'
LANGUAGE C STABLE STRICT PARALLEL SAFE;

CREATE FUNCTION timestamptz_to_timestamptp(timestamptz) RETURNS timestamptp
AS '$libdir/timestamptp'
LANGUAGE C STABLE STRICT PARALLEL SAFE;

-- Casts
CREATE CAST (timestamptp AS timestamptz)
WITH FUNCTION get_timestamp
AS ASSIGNMENT;

CREATE CAST (timestamptz AS timestamptp)
WITH FUNCTION timestamptz_to_timestamptp
AS ASSIGNMENT;

-- Functions and operators to implement:
-- timestamptp = timestamptp
-- to_char(timestamptz, text)
-- timestamptp + interval
-- timestamptp - interval
-- timestamptp - timestamptp
-- age(timestamptp, timestamptp)
-- age(timestamptp)
-- date_part(text, timestamptp)
-- date_trunc(text, timestamptp)
-- extract(field from timestamptp)
-- isinfinite(timestamptp)
-- make_timestamptp(year, month, day, hour, minute, second, timezone)
-- make_timestamptp(timestamptz, text) (textual description of timezone)
-- (timestamptp, timestamptp) OVERLAPS (timestamptp, timestamptp)
