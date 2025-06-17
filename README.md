# Postgresql Timezone-Preserving Timestamp Type

This Postgresql extension adds a new datatype to Postgresql, a timestamp that preserves the original timezone.

Postgresql has two timestamp types out of the box: `timestamp without time zone` and `timestamp with timezone`
(abbreviated `timestamptz`).
Internally, both use the same representation: a 64-bit integer storing the number of microseconds since the
Postgresql timestamp epoch (Jan 1, 2000). The only difference is that, during input, the `with time zone` variant
will convert the given timestamp to UTC and store that. Abstractly, this represents an absolute timestamp, rather
than one relative to an unspecified local timezone like the `without time zone` variant.

Problem is, the original timezone is lost. Outputting a `timestamp with time zone` value back to a string will
show it in the Postgresql server's configured local timezone, or a timezone explicitly given using the
`AT TIME ZONE` construct. For uses where preserving the original timezone is necessary, storing the original
time zone must be done in a separate column.

The timezone-preserving timestamp implemented in this repository (abbreviated `timestamptp`)
adds timezone information so that it can
be passed around within Postgresql as a single logical datatype. The representation on disk is a struct
consisting of the original `TimestampTz` type and a `TzOffset` type.

`timestamptp` mostly behaves the same as the original `timestamptz`. The following functionality is implemented:

* Inputs (string to `timestamptp` conversion) parses the timezone in the timestamp string and stores that
* Outputs (`timestamptp` to string) will format the timestamp in the stored timezone
* Casts between `timestamptp` and `timestamptz` are implemented and declared "AS ASSIGNMENT" meaning it will implicitly convert
  on assignments, but otherwise must be explicitly cast. Casting from `timestamptp` drops the stored timezone,
  and casting to uses the system's local timezone.
* Alternate constructor functions `make_timestamptp(timestamptz, integer)` and `make_timestamptp(timestamptz, text)`
  create a new `timestamptp`  type given a regular timestamp and a timezone offset, either in minutes offset from
  UTC or a timezone string.
* The equality operator `=` is implemented, and ignores timezone for comparisons. Equality is also implemented
  between `timestamptp` and `timestamptz` for convenience (saves an explicit cast).
* Addition of a `timestamptp` and an `interval` type will add the interval and preserve the original timezone.
