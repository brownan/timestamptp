\echo Use "CREATE EXTENSION timestamptp" to load this file. \quit

CREATE FUNCTION timestamptp_in(cstring) RETURNS timestamptp
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION timestamptp_out(timestamptp) RETURNS cstring
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE timestamptp (
    INPUT = timestamptp_in,
    OUTPUT = timestamptp_out,
    INTERNALLENGTH = 10,
    ALIGNMENT = double,
    STORAGE = plain
);
