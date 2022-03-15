CREATE EXTENSION timestamptp;

SELECT timestamptp_in('2021-01-02T03:04:05-0500');

SELECT '2000-01-01 00:00:00Z'::timestamptp;
SELECT '2000-01-01 00:00:00+1011'::timestamptp;
