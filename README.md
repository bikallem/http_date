# http_date

Parse and format HTTP date values in SWI-Prolog, as defined in
[RFC 9110 section 5.6.7](https://www.rfc-editor.org/rfc/rfc9110#section-5.6.7).

An HTTP date appears in one of three formats.

| Format      | Example                          |
|-------------|----------------------------------|
| IMF-fixdate | `Sun, 06 Nov 1994 08:49:37 GMT`  |
| RFC 850     | `Sunday, 06-Nov-94 08:49:37 GMT` |
| asctime     | `Sun Nov  6 08:49:37 1994`       |

One grammar, `http_date//2`, defines all three. `decode/2` and `encode/2` run
that same grammar in opposite directions. The two directions cannot
disagree.

## Install

```prolog
?- pack_install(http_date).
```

To install from a checkout of this repository, run `pack_install('.')` from
the repository root.

## Use

```prolog
?- use_module(library(http_date)).

?- decode("Sun, 06 Nov 1994 08:49:37 GMT", D).
D = http_date(imf_fixdate, datetime(sun, date(1994, 11, 6), time(8, 49, 37))).

?- encode(http_date(asctime, datetime(sun, date(1994,11,6), time(8,49,37))), S).
S = "Sun Nov  6 08:49:37 1994".
```

A decoded value is the term `http_date(Format, datetime(Day, Date, Time))`.
`Format` is one of `imf_fixdate`, `rfc850` or `asctime`. Unify against it to
ask which format you have, or call `is_imf_fixdate/1`, `is_rfc850/1` or
`is_asctime/1`.

The grammar is exported. You can call it from a larger grammar and avoid an
intermediate string.

```prolog
last_modified(Format, DateTime) -->
    `Last-Modified: `, http_date(Format, DateTime).
```

## Shape and meaning are separate checks

`decode/2` checks shape only. It accepts the three layouts, rejects trailing
data, and rejects an unknown day name or month. It does not make sure that the
numbers name a real instant. For example, `Sun, 99 Nov 1994 08:49:37 GMT`
decodes to `date(1994, 11, 99)`.

`valid_http_date/1` checks meaning. It rejects a day the month does not have.
It rejects 29 February in a year that is not a leap year. It also rejects an
hour above 23, or a minute or second above 59.

```prolog
?- decode(Text, D), valid_http_date(D).
```

`strict_http_date/1` adds the day of the week. It calls `valid_http_date/1`,
then checks the day name against the calendar with `consistent_dayname/1`.
For the RFC 850 format it skips that check, because a two digit year does not
say which century it means.

The split is deliberate. RFC 9110 lets a recipient accept a date whose day
name is wrong. The parser stays permissive. The caller decides how much to
demand.

## Timestamps

`http_date_stamp/2` converts a value to a Unix timestamp, and
`stamp_http_date/3` converts a timestamp back. Both treat the value as GMT.

```prolog
?- decode("Sun, 06 Nov 1994 08:49:37 GMT", D), http_date_stamp(D, Stamp).
Stamp = 784111777.0.

?- get_time(Now), stamp_http_date(Now, imf_fixdate, D), encode(D, S).
```

Call `valid_http_date/1` before you convert. `date_time_stamp/2` normalizes an
impossible date instead of refusing it. 31 February becomes 3 March.

An RFC 850 value holds a two digit year. `http_date_stamp/2` reads that year
literally. `Sunday, 06-Nov-94` gives a timestamp in the year 94. If you need a
century, map the year yourself.

## Tests

```bash
swipl -q -g run_tests -t halt prolog/http_date.pl
```

The suite runs 127 cases. The round trip test reads the same tables the
grammar reads. It generates one case for every day and month pair.

## Development

The repository carries a Nix flake. `nix develop` gives you a shell with
SWI-Prolog on the path. If you use direnv, run `direnv allow` once. The shell
then loads on entry.
