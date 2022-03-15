#include "postgres.h"
#include "fmgr.h"
#include "utils/timestamp.h"
#include "utils/datetime.h"
#include "miscadmin.h"

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


/*
 * Convert a cstring into a TimestampTp
 */
PG_FUNCTION_INFO_V1(timestamptp_in);
Datum
timestamptp_in(PG_FUNCTION_ARGS)
{
    char *str = PG_GETARG_CSTRING(0);
    int	dterr;

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

    TimestampTz result;
    if (tm2timestamp(&tm, fsec, &tz, &result) != 0) {
        ereport(
            ERROR,
            errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
            errmsg("timestamp out of range: \"%s\"", str)
        );
    }

    /*
    Everything so far is basically the same as timestamptz_in. Now we save the
    timestamp value into our TimestampTp struct along with the offset
    */

    TimestampTp *ret = palloc(sizeof(TimestampTp));
    ret->timestamp = result;
    ret->tzoffset = tz / SECS_PER_MINUTE;

    PG_RETURN_TIMESTAMPTP(ret);
}


/*
 * Convert a TimestampTz to a cstring
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
    Our requested timezone. This is where this function differs from timestamptz_out:
    we explicitly set the requested timezone when calling timestamp2tm, instead of
    leaving it NULL, which requests the system default.
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
            (
                errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
                errmsg("timestamp out of range")
            )
        );
     }

    
    char *ret;
    ret = pstrdup(buf);
    PG_RETURN_CSTRING(ret);
}


