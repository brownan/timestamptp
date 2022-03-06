\echo Use "CREATE EXTENSION timestamptp" to load this file. \quit

CREATE FUNCTION timestamptp_in(text) RETURNS text
AS '$libdir/timestamptp'
LANGUAGE C IMMUTABLE STRICT;
