:- module(http_date,
            [decode/2,
             encode/2,
             is_imf_fixdate/1,
             is_rfc850/1,
             is_asctime/1,
             valid_date/1,
             valid_time/1,
             valid_http_date/1,
             consistent_dayname/1,
             strict_http_date/1,
             http_date_stamp/2,
             stamp_http_date/3,
             http_date//2]).

day(mon, 1, `Mon`, `Monday`).
day(tue, 2, `Tue`, `Tuesday`).
day(wed, 3, `Wed`, `Wednesday`).
day(thu, 4, `Thu`, `Thursday`).
day(fri, 5, `Fri`, `Friday`).
day(sat, 6, `Sat`, `Saturday`).
day(sun, 7, `Sun`, `Sunday`).

month(1, `Jan`, 31).
month(2, `Feb`, 28).
month(3, `Mar`, 31).
month(4, `Apr`, 30).
month(5, `May`, 31).
month(6, `Jun`, 30).
month(7, `Jul`, 31).
month(8, `Aug`, 31).
month(9, `Sep`, 30).
month(10, `Oct`, 31).
month(11, `Nov`, 30).
month(12, `Dec`, 31).

leap_year(Y) :-
    0 is Y mod 4,
    ( 0 is Y mod 100 -> 0 is Y mod 400 ; true ).

days_in_month(Y, M, N) :-
    month(M, _, N0),
    ( M =:= 2, leap_year(Y) -> N is N0 + 1 ; N = N0 ).

day_name(D, short) --> { day(D, _, Cs, _) }, Cs.
day_name(D, long)  --> { day(D, _, _, Cs) }, Cs.

month_name(M) --> { month(M, Cs, _) }, Cs.

ndigits(0, []) --> [].
ndigits(N, [C|Cs]) -->
    { N > 0, N0 is N - 1 },
    [C],
    { code_type(C, digit) },
    ndigits(N0, Cs).

digits(N, V) --> { var(V) }, !, ndigits(N, Cs), { number_codes(V, Cs) }.
digits(N, V) --> { format(codes(Cs), '~|~`0t~d~*|', [V, N]) }, ndigits(N, Cs).

time(time(H, Mi, S)) -->
    digits(2, H), `:`, digits(2, Mi), `:`, digits(2, S).

asctime_day(D) --> ` `, digits(1, D), { D < 10 }.
asctime_day(D) --> digits(2, D).

date1(date(Y, M, D)) -->
    digits(2, D), ` `, month_name(M), ` `, digits(4, Y).

date2(date(Y, M, D)) -->
    digits(2, D), `-`, month_name(M), `-`, digits(2, Y).

http_date(imf_fixdate, datetime(Day, Date, Time)) -->
    day_name(Day, short), `, `, date1(Date), ` `, time(Time), ` GMT`.

http_date(rfc850, datetime(Day, Date, Time)) -->
    day_name(Day, long), `, `, date2(Date), ` `, time(Time), ` GMT`.

http_date(asctime, datetime(Day, date(Y, M, D), Time)) -->
    day_name(Day, short), ` `, month_name(M), ` `, asctime_day(D), ` `,
    time(Time), ` `, digits(4, Y).

%! decode(+Text, -Date) is semidet.
decode(Text, http_date(Format, DateTime)) :-
    string_codes(Text, Codes),
    once(phrase(http_date(Format, DateTime), Codes)).

encode(http_date(Format, DateTime), Text) :-
    once(phrase(http_date(Format, DateTime), Codes)),
    string_codes(Text, Codes).

is_imf_fixdate(http_date(imf_fixdate, _)).
is_rfc850(http_date(rfc850, _)).
is_asctime(http_date(asctime, _)).

valid_date(date(Y, M, D)) :-
    between(0, 9999, Y),
    days_in_month(Y, M, Max),
    between(1, Max, D).

valid_time(time(H, Mi, S)) :-
    between(0, 23, H),
    between(0, 59, Mi),
    between(0, 59, S).

valid_http_date(http_date(_, datetime(_, Date, Time))) :-
    valid_date(Date),
    valid_time(Time).

consistent_dayname(http_date(_, datetime(Day, date(Y, M, D), _))) :-
    day_of_the_week(date(Y, M, D), N),
    day(Day, N, _, _).

strict_http_date(http_date(Format, DateTime)) :-
    valid_http_date(http_date(Format, DateTime)),
    ( Format == rfc850 -> true
    ; consistent_dayname(http_date(Format, DateTime))
    ).

http_date_stamp(http_date(_, datetime(_, date(Y, M, D), time(H, Mi, S))), Stamp) :-
    date_time_stamp(date(Y, M, D, H, Mi, S, 0, -, -), Stamp).

stamp_http_date(Stamp, Format, http_date(Format, datetime(Day, date(Y, M, D), time(H, Mi, S)))) :-
    stamp_date_time(Stamp, date(Y, M, D, H, Mi, Sf, _, _, _), 0),
    S is truncate(Sf),
    day_of_the_week(date(Y, M, D), N),
    day(Day, N, _, _).

:- begin_tests(http_date).

test(imf) :-
    decode("Sun, 06 Nov 1994 08:49:37 GMT", D),
    assertion(D == http_date(imf_fixdate, datetime(sun, date(1994,11,6), time(8,49,37)))).

test(rfc850) :-
    decode("Sunday, 06-Nov-94 08:49:37 GMT", D),
    assertion(D == http_date(rfc850, datetime(sun, date(94,11,6), time(8,49,37)))).

test(asctime_padded) :-
    decode("Sun Nov  6 08:49:37 1994", D),
    assertion(D == http_date(asctime, datetime(sun, date(1994,11,6), time(8,49,37)))).

test(asctime_two_digit) :-
    decode("Wed Nov 16 08:49:37 1994", D),
    assertion(D == http_date(asctime, datetime(wed, date(1994,11,16), time(8,49,37)))).

test(trailing_data, [fail]) :- decode("Sun, 06 Nov 1994 08:49:37 GMTx", _).
test(garbage, [fail]) :- decode("not a date", _).
test(feb_31_rejected, [fail]) :- decode("Sun, 31 Feb 1994 08:49:37 GMT", D), valid_http_date(D).
test(feb_29_leap) :- decode("Tue, 29 Feb 2000 08:49:37 GMT", D), valid_http_date(D).
test(feb_29_century_not_leap, [fail]) :- decode("Thu, 29 Feb 1900 08:49:37 GMT", D), valid_http_date(D).
test(dayname_matches) :- decode("Sun, 06 Nov 1994 08:49:37 GMT", D), consistent_dayname(D).
test(dayname_mismatch, [fail]) :- decode("Mon, 06 Nov 1994 08:49:37 GMT", D), consistent_dayname(D).
test(leap_years, [forall(member(Y-Is, [1992-true, 1900-false, 2000-true, 1994-false]))]) :-
    (leap_year(Y) -> Got = true ; Got = false),
    assertion(Got == Is).
test(time_out_of_range,
    [forall(member(S, ["Sun, 06 Nov 1994 25:49:37 GMT",
                       "Sun, 06 Nov 1994 08:99:37 GMT",
                       "Sun, 06 Nov 1994 08:49:99 GMT"])),
     fail]) :-
        decode(S, D),
        valid_http_date(D).
test(time_out_of_range_still_parses,
    [forall(member(S, ["Sun, 06 Nov 1994 25:49:37 GMT",
                       "Sun, 06 Nov 1994 08:99:37 GMT",
                       "Sun, 06 Nov 1994 08:49:99 GMT"]))]) :-
     decode(S, _).

test(rfc850_rejects_four_digit_year, [fail]) :-
    encode(http_date(rfc850, datetime(sun, date(1994,11,6), time(8,49,37))), _).

test(roundtrip, [forall(member(S, ["Sun, 06 Nov 1994 08:49:37 GMT",
                                   "Sunday, 06-Nov-94 08:49:37 GMT",
                                   "Sun Nov  6 08:49:37 1994",
                                   "Wed Nov 16 08:49:37 1994"]))]) :-
    decode(S, D), encode(D, S2), assertion(S2 == S).

test(asctime_zero_padded_day_normalize) :-
    decode("Sun Nov 06 08:49:37 1994", D),
    encode(D, S),
    assertion(S == "Sun Nov  6 08:49:37 1994").

test(every_day_and_month, [forall((day(Day,_,_,_), month(M,_,_)))]) :-
    Date = http_date(imf_fixdate, datetime(Day, date(1994, M, 6), time(8,49,37))),
    encode(Date, S), decode(S, Back), assertion(Back == Date).

test(strict_checks_dayname_for_imf) :-
    strict_http_date(http_date(imf_fixdate, datetime(sun, date(1994,11,6), time(8,49,37)))).

test(strict_rejects_wrong_dayname_for_imf, [fail]) :-
    strict_http_date(http_date(imf_fixdate, datetime(mon, date(1994,11,6), time(8,49,37)))).

test(strict_skips_dayname_for_rfc850_two_digit_year) :-
    strict_http_date(http_date(rfc850, datetime(mon, date(94,11,6), time(8,49,37)))).

test(stamp_epoch) :-
    stamp_http_date(0, imf_fixdate, D),
    assertion(D == http_date(imf_fixdate, datetime(thu, date(1970,1,1), time(0,0,0)))).

test(stamp_from_known_date) :-
    decode("Sun, 06 Nov 1994 08:49:37 GMT", D),
    http_date_stamp(D, Stamp),
    assertion(Stamp =:= 784111777.0).

test(long_dayname_not_imf, [fail]) :- decode("Sunday, 06 Nov 1994 08:49:37 GMT", _).
test(short_dayname_not_rfc850, [fail]) :- decode("Sun, 06-Nov-94 08:49:37 GMT", _).

test(format_predicate_accepts_own_format,
    [forall( member(Format-Check, [imf_fixdate-is_imf_fixdate,
                                  rfc850-is_rfc850,
                                  asctime-is_asctime]))]) :-
    call(Check, http_date(Format, datetime(sun, date(1994,11,6), time(8,49,37)))).

test(format_predicate_rejects_other_formats,
[forall(( member(Format-Check, [imf_fixdate-is_imf_fixdate,
                              rfc850-is_rfc850,
                              asctime-is_asctime]),
          member(Other, [imf_fixdate, rfc850, asctime]),
          Other \== Format ))]) :-
    \+ call(Check, http_date(Other, datetime(sun, date(1994,11,6), time(8,49,37)))).

:- end_tests(http_date).
