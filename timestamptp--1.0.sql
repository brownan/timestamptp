\echo Use "CREATE EXTENSION timestamptp" to load this file. \quit

-- Main input/output functions
CREATE FUNCTION timestamptp_in(cstring) RETURNS timestamptp
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION timestamptp_out(timestamptp) RETURNS cstring
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- Type declaration
CREATE TYPE timestamptp (
    INPUT = timestamptp_in,
    OUTPUT = timestamptp_out,
    INTERNALLENGTH = 10,
    ALIGNMENT = double,
    STORAGE = plain,
    CATEGORY = 'D'
);

-- Other Input/output functions
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

-- Operator Functions and operator declarations
CREATE FUNCTION timestamptp_eq(x timestamptp, y timestamptp) RETURNS bool AS $$
    SELECT x::timestamptz = y::timestamptz;
$$ LANGUAGE SQL;

CREATE OPERATOR = (
 FUNCTION = timestamptp_eq,
 LEFTARG = timestamptp,
 RIGHTARG = timestamptp,
 COMMUTATOR = =,
 RESTRICT = eqsel,
 JOIN = eqjoinsel,
 HASHES, MERGES
);

CREATE FUNCTION timestamptp_eq_timestamptz(x timestamptp, y timestamptz) RETURNS bool AS $$
    SELECT x::timestamptz = y;
$$ LANGUAGE SQL;

CREATE OPERATOR = (
    FUNCTION = timestamptp_eq_timestamptz,
    LEFTARG = timestamptp,
    RIGHTARG = timestamptz,
    COMMUTATOR = =,
    RESTRICT = eqsel,
    JOIN = eqjoinsel,
    HASHES, MERGES
);

CREATE FUNCTION timestamptz_eq_timestamptp(x timestamptz, y timestamptp) RETURNS bool AS $$
    SELECT x = y::timestamptz;
$$ LANGUAGE SQL;

CREATE OPERATOR = (
    FUNCTION = timestamptz_eq_timestamptp,
    LEFTARG = timestamptz,
    RIGHTARG = timestamptp,
    COMMUTATOR = =,
    RESTRICT = eqsel,
    JOIN = eqjoinsel,
    HASHES, MERGES
);

CREATE FUNCTION timestamptp_add_interval(x timestamptp, y interval) RETURNS timestamptp AS $$
    SELECT make_timestamptp(x::timestamptz + y, get_offset(x));
$$ LANGUAGE SQL;

CREATE OPERATOR + (
    FUNCTION = timestamptp_add_interval,
    LEFTARG = timestamptp,
    RIGHTARG = interval,
    COMMUTATOR = +
);

CREATE FUNCTION interval_add_timestamptp(x interval, y timestamptp) RETURNS timestamptp AS $$
    SELECT make_timestamptp(y::timestamptz + x, get_offset(y));
$$ LANGUAGE SQL;

CREATE OPERATOR + (
    FUNCTION = interval_add_timestamptp,
    LEFTARG = interval,
    RIGHTARG = timestamptp,
    COMMUTATOR = +
);


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
