#include "postgres.h"
#include "fmgr.h"
#include "utils/timestamp.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(timestamptp_in);
Datum
timestamptp_in(PG_FUNCTION_ARGS)
{
    PG_RETURN_NULL();
}
