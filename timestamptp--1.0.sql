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

-- Other low-level input/output/cast functions
CREATE FUNCTION timestamptp_to_timestamptz(timestamptp) RETURNS timestamptz
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
WITH FUNCTION timestamptp_to_timestamptz
AS ASSIGNMENT;

CREATE CAST (timestamptz AS timestamptp)
WITH FUNCTION timestamptz_to_timestamptp
AS ASSIGNMENT;

-- Higher level functions and operators
--
-- Note: functions below are mostly defined in the SQL language. These functions
-- will be inlined as long as they meet the conditions for inlining of SQL functions
-- https://wiki.postgresql.org/wiki/Inlining_of_SQL_functions
-- In short, make sure SQL functions are:
-- * NOT defined with SECURITY DEFINER
-- * Does not return types SETOF, TABLE, or RECORD
-- * Is not recursive
-- * Consist of a single, simple SELECT expression
-- * Body contains no aggregates, window functions, subqueries, CTEs
-- * Body contains no FROM clause referencing tables or table-like objects
-- * Body does not contain GROUP BY, HAVING, ORDER BY, DISTINCT, LIMIT, OFFSET, UNION,
--   INTERSECTION, or EXCEPT clauses
-- * Body returns exactly one column whose type matches the function's declared return type
-- * returns no more than 1 row
-- * If function is declared IMMUTABLE, it must not invoke any non-immutable function or operator
-- * If function is declared STABLE, it must not invoke any volatile function or operator
-- * If function is declared STRICT, then the planner must be able to prove that the expression
--   returns NULL if any parameter is NULL. Basically, make sure to actually use each parameter
--   in the function body, and make sure functions and operators used are themselves STRICT.
-- Additionally, arguments won't be inlined if they are used more than once in the function
-- body AND are either 1. a volatile expression, or 2. expensive (cost >10 or contains a subquery)
-- More info: http://www.neilconway.org/talks/optimizer/optimizer.pdf

CREATE FUNCTION timestamptp_eq(x timestamptp, y timestamptp) RETURNS bool AS $$
    SELECT x::timestamptz = y::timestamptz;
$$ LANGUAGE SQL LEAKPROOF STRICT IMMUTABLE PARALLEL SAFE COST 1;

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
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE COST 1;

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
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE COST 1;

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
$$ LANGUAGE SQL STABLE PARALLEL SAFE STRICT COST 1;

CREATE OPERATOR + (
    FUNCTION = timestamptp_add_interval,
    LEFTARG = timestamptp,
    RIGHTARG = interval,
    COMMUTATOR = +
);

CREATE FUNCTION interval_add_timestamptp(x interval, y timestamptp) RETURNS timestamptp AS $$
    SELECT make_timestamptp(y::timestamptz + x, get_offset(y));
$$ LANGUAGE SQL STABLE PARALLEL SAFE STRICT COST 1;

CREATE OPERATOR + (
    FUNCTION = interval_add_timestamptp,
    LEFTARG = interval,
    RIGHTARG = timestamptp,
    COMMUTATOR = +
);


-- Functions and operators to implement:
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
