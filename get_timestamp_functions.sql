select 
    proname,
    oidvectortypes(proargtypes), 
    prorettype::regtype as prorettype,
    procost,
    CASE
        WHEN proisstrict THEN 'STRICT'
        ELSE 'CALLED ON NULL INPUT'
    END as proisstrict,
    CASE
        WHEN provolatile = 'i' THEN 'IMMUTABLE'
        WHEN provolatile = 's' THEN 'STABLE'
        WHEN provolatile = 'v' THEN 'VOLATILE'
    END AS provolatile,
    CASE
        WHEN proparallel = 's' THEN 'PARALLEL SAFE'
        WHEN proparallel = 'r' THEN 'PARALLEL RESTRICTED'
        WHEN proparallel = 'u' THEN 'PARALLEL UNSAFE'
    END as proparallel,
    (SELECT lanname FROM pg_language WHERE pg_language.oid = prolang) AS prolang,
    prosrc,
    ARRAY(SELECT oprname FROM pg_operator WHERE oprcode = pg_proc.oid) as operators
from pg_proc
WHERE (SELECT oid FROM pg_type WHERE typname='timestamptz') = ANY(proargtypes::int[]);
