#include <assert.h>

#include "postgres.h"
#include "fmgr.h"
#include "miscadmin.h"
#include "parser/scansup.h"
#include "utils/builtins.h"
#include "utils/datetime.h"
#include "utils/timestamp.h"

PG_MODULE_MAGIC;


/*
Timezone offset in minutes, positive values WEST of GMT
(This is negative of normal ISO timezone offsets, to match how a lot of the postgres
timestamp utility functions work)
*/
typedef int16 TzOffset;


typedef struct {
    TimestampTz timestamp;
    TzOffset tzoffset;
} TimestampTp;


#define DatumGetTimestampTp(X)	((TimestampTp *) DatumGetPointer(X))
#define TimestampTpGetDatum(X) PointerGetDatum(X)
#define PG_GETARG_TIMESTAMPTP(n) DatumGetTimestampTp(PG_GETARG_DATUM(n))
#define PG_RETURN_TIMESTAMPTP(x) return TimestampTpGetDatum(x)


/* Forward declarations */
static pg_tz *get_timezone(text *zonename);


/*
 * The type's input function: Convert a cstring into a TimestampTp
 */
PG_FUNCTION_INFO_V1(timestamptp_in);
Datum
timestamptp_in(PG_FUNCTION_ARGS)
{
    char *str = PG_GETARG_CSTRING(0);
    int	dterr;

    /*
    Parse the input string into an array of tokens and token types
    */
    char workbuf[MAXDATELEN + MAXDATEFIELDS];
    char *field[MAXDATEFIELDS];
    int	ftype[MAXDATEFIELDS];
    int numfields;
    dterr = ParseDateTime(
        str,
        workbuf,
        sizeof(workbuf),
        field,
        ftype,
        MAXDATEFIELDS,
        &numfields
    );

    /*
    Decode the token array into a pg_tm struct, fsec fractional seconds, and
    tz timezone offset
    */
    int	dtype;
    struct pg_tm tm;
    fsec_t fsec;
    int	tz;
    if (dterr == 0) {
        dterr = DecodeDateTime(field, ftype, numfields, &dtype, &tm, &fsec, &tz);
    }
    
    if (dterr != 0) {
        DateTimeParseError(dterr, str, "timezone-preserving timestamp");
    }
    
    if (dtype != DTK_DATE) {
        elog(ERROR, "unexpected dtype %d while parsing timestamptz \"%s\"",
            dtype, str);
    }

    /*
    Translate the decoded information into the postgres timestamp format, which is
    microseconds since Jan 1 2000
    */
    TimestampTz result;
    if (tm2timestamp(&tm, fsec, &tz, &result) != 0) {
        ereport(
            ERROR,
            errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
            errmsg("timestamp out of range: \"%s\"", str)
        );
    }

    /*
    Everything so far is basically the same as the standard timestamptz_in function.
    Now we save the timestamp value into our TimestampTp struct along with the offset.
    */

    TimestampTp *ret = palloc(sizeof(TimestampTp));
    ret->timestamp = result;
    ret->tzoffset = tz / SECS_PER_MINUTE;

    PG_RETURN_TIMESTAMPTP(ret);
}


/*
 * The type's output function: Convert a TimestampTz to a cstring
 */
PG_FUNCTION_INFO_V1(timestamptp_out);
Datum
timestamptp_out(PG_FUNCTION_ARGS)
{
    TimestampTp *value = PG_GETARG_TIMESTAMPTP(0);

    TimestampTz dt = value->timestamp;
    TzOffset offset = value->tzoffset;

    char buf[MAXDATELEN + 1];
    int tz;
    struct pg_tm tt;
    fsec_t fsec;
    const char *tzn;

    /*
    Turn the stored offset into a pg_tz struct, which we can use below in the call
    to timestamp2tm.
    This is where this function differs from timestamptz_out: we explicitly set
    the requested timezone when calling timestamp2tm, instead of leaving it NULL,
    which requests the system timezone.
    */
    pg_tz *requseted_timezone = pg_tzset_offset(offset * SECS_PER_MINUTE);

    if (TIMESTAMP_NOT_FINITE(dt)) {
        EncodeSpecialTimestamp(dt, buf);
    } else if (timestamp2tm(dt, &tz, &tt, &fsec, &tzn, requseted_timezone) == 0) {
        /* Also: always output ISO format, regardless of system setting */
        EncodeDateTime(&tt, fsec, true, tz, tzn, USE_ISO_DATES, buf);
    } else {
        ereport(
            ERROR,
            errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
            errmsg("timestamp out of range")
        );
     }

    char *ret;
    ret = pstrdup(buf);
    PG_RETURN_CSTRING(ret);
}


/*
get_timestamp(timestamptp) -> timestamptz

Also implements the timestamptp -> timestamptz cast

Returns the timestamptz timestamp in this timestamptp. Timezone offset information will be
lost, but the timestamptz will still refer to the same timestamp, just in GMT.
*/
PG_FUNCTION_INFO_V1(get_timestamp);
Datum
get_timestamp(PG_FUNCTION_ARGS)
{
    TimestampTp *timestamp = PG_GETARG_TIMESTAMPTP(0);
    PG_RETURN_TIMESTAMPTZ(timestamp->timestamp);
}

/*
get_offset(timestamptp) -> smallint

Returns an int representing this timestamptp's stored timezone offset from GMT
in minutes, positive values EAST of GMT.
*/
PG_FUNCTION_INFO_V1(get_offset);
Datum
get_offset(PG_FUNCTION_ARGS)
{
    TimestampTp *timestamp = PG_GETARG_TIMESTAMPTP(0);
    PG_RETURN_INT16(-timestamp->tzoffset);
}

/*
make_timestamptp(timestamptz, integer) -> timestamptp

Constructs a timestamptp from a timestamptz and an integer offset.
*/
PG_FUNCTION_INFO_V1(make_timestamptp);
Datum
make_timestamptp(PG_FUNCTION_ARGS)
{
    TimestampTz timestamp = PG_GETARG_TIMESTAMPTZ(0);
    int32 offset = PG_GETARG_INT32(1);

    /*
    Can't be 16 or more hours in either direction.
    This limit comes from postgresql's timestamp parser, which also rejects any
    offset over 16
    */
    if (offset >= 60*16 || offset <= -60*16) {
        ereport(
            ERROR,
            errcode(ERRCODE_INVALID_TIME_ZONE_DISPLACEMENT_VALUE),
            errmsg("Timezone offset must be strictly between -960 and 960")
        );
    }

    TimestampTp *ret = palloc(sizeof(TimestampTp));
    ret->timestamp = timestamp;
    ret->tzoffset = (TzOffset) -offset;

    PG_RETURN_TIMESTAMPTP(ret);
}


/*
make_timestamptp(timestamptz, text) -> timestamptp

Constructs a timestamptp from a timestamptz and a string describing a timezone.
The resulting timestamptp will have the same timestamp as the original timestamptz,
but with the timezone offset set according to the given timezone. If the timezone
given is DST-aware, it will be interpreted in the context of the given timestamp.

The given timezone text can be in any format supported by postgres:
* A full timezone name, e.g. America/New_York
* A timezone abbreviation, e.g. PST
* A POSIX-style timezone specification. See Postgresql manual appendix B.5

Note that timezone abbreviations are typically not DST-aware, and only specify a fixed
offset. Full timezone names must be given for DST-aware conversions.

This function should be marked STABLE and not IMMUTABLE because it depends on
system timezone definitions.
*/
PG_FUNCTION_INFO_V1(make_timestamptp_in_timezone);
Datum
make_timestamptp_in_timezone(PG_FUNCTION_ARGS)
{
    TimestampTz timestamp = PG_GETARG_TIMESTAMPTZ(0);
    pg_tz *timezone = get_timezone(PG_GETARG_TEXT_PP(1));

    /*
    Decode the timestamp so that we can get the offset that it would have in this
    timezone
    */
    struct pg_tm info;
    int tz;
    fsec_t fsec;
    if (timestamp2tm(timestamp, &tz, &info, &fsec, NULL, timezone) != 0) {
        ereport(
            ERROR,
            errmsg("timestamptz is out of range")
        );
    }

    TimestampTp *ret = palloc(sizeof(TimestampTp));
    ret->timestamp = timestamp;
    ret->tzoffset = (TzOffset) tz / SECS_PER_MINUTE;
    PG_RETURN_TIMESTAMPTP(ret);
}


/*
Implements the cast from timestamptz to timestamptp

We must choose a timezone offset to attach to the new timestamptp,
so we choose the system's defined local timezone. To explicitly specify
the timezone, use make_timestamptp() instead.

This function must be marked as STABLE and not IMMUTABLE because it depends on external
state (the configured timezone).
*/
PG_FUNCTION_INFO_V1(timestamptz_to_timestamptp);
Datum
timestamptz_to_timestamptp(PG_FUNCTION_ARGS)
{
    TimestampTz ts = PG_GETARG_TIMESTAMPTZ(0);

    long int gmtoff;
    if (!pg_get_timezone_offset(session_timezone, &gmtoff)) {
        /*
        Fallback: just assume UTC
        I think pg_get_timezone_offset() returns false for timezones that have multiple
        offsets (DST-aware timezones), so we may want to do some more intelligent timezone
        translations here
        */
        gmtoff = 0;
    }
    TzOffset offset = -gmtoff / SECS_PER_MINUTE;

    TimestampTp *ret = palloc(sizeof(TimestampTp));
    ret->timestamp = ts;
    ret->tzoffset = offset;
    PG_RETURN_TIMESTAMPTP(ret);
}


/*
Interpret a timezone string and return a pg_tz struct

Similar boilerplate code is used in several places in utils/adt/timestamp.c in the postgres
source, but unfortunately doesn't seem to be exported in any form that I can call. So the logic
is duplicated here.

Takes mostly from parse_sane_timezone() in timestamp.c

Functions which use this function should be marked STABLE at best. They can't be
IMMUTABLE because the timezone lookups depend on the timezone definition tables.
*/
static pg_tz *get_timezone(text *zonename)
{
    char tzname[TZ_STRLEN_MAX + 1];
    text_to_cstring_buffer(zonename, tzname, sizeof(tzname));

    if (isdigit((unsigned char) *tzname)) {
        ereport(
            ERROR,
            errmsg("invalid input syntax for type %s: \"%s\"", "numeric time zone", tzname),
            errhint("Numeric time zones must have \"-\" or \"+\" as first character.")
        );
    }

    /*
    Attempt to interpret the string as a numeric timezone spec, e.g. -05:00
    */
    int offset;
    pg_tz *tzp;
    int decode_status = DecodeTimezone(tzname, &offset);
    if (decode_status == 0) {
        tzp = pg_tzset_offset(offset);
        if (tzp == NULL) {
            /*
            Shouldn't error because DecodeTimezone should have already done bounds
            checking
            */
            ereport(
                ERROR,
                errmsg("Internal error translating offset into timezone")
            );
        }
        return tzp;
    } else if (decode_status == DTERR_TZDISP_OVERFLOW) {
        ereport(
            ERROR,
            errcode(ERRCODE_INVALID_PARAMETER_VALUE),
            errmsg("numeric time zone \"%s\" out of range", tzname)
        );
    } else if (decode_status != DTERR_BAD_FORMAT) {
        ereport(
            ERROR,
            errcode(ERRCODE_INVALID_PARAMETER_VALUE),
            errmsg("time zone \"%s\" not recognized", tzname)
        );
    }

    /* String failed to parse as an offset spec. Try a timezone abbreviation */
    char *lowzone = downcase_truncate_identifier(tzname, strlen(tzname), false);
    int type = DecodeTimezoneAbbrev(0, lowzone, &offset, &tzp);
    if (type == DYNTZ) {
        assert(tzp != NULL);
        return tzp;
    } else if (type == TZ || type == DTZ) {
        /* Convert this offset to a timezone */
        tzp = pg_tzset_offset(-offset);
        if (tzp == NULL) {
            ereport(
                ERROR,
                errmsg("Internal error translating offset into timezone")
            );
        }
        return tzp;
    }

    /* Failed to parse as an abbreviation, try full timezone name */
    tzp = pg_tzset(tzname);
    if (tzp != NULL) {
        return tzp;
    }

    ereport(
        ERROR,
        errcode(ERRCODE_INVALID_PARAMETER_VALUE),
        errmsg("time zone \"%s\" not recognized", tzname)
    );

}
