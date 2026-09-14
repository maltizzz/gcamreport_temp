# Why the 5 tests failed (and what to do about it)

This is a plain-language summary of why `./gcamreport-fork/tests/testthat.R`
reported 5 failing tests, and whether each one is a real problem or a false
alarm. Investigated on 2026-09-14 against `gcamreport-fork` branch `pj-kaist`,
commit `e379e21`.

**Short answer up front:** none of the 5 failures are caused by GCAM v7.0
being fundamentally incompatible with the newer v9.1 code. Two of them are
real (but small and fixable) bugs. One is a missing test file. Two of them
are false alarms caused by testing an old, un-refreshed copy of the package
instead of the current code.

---

## Test 1 — `test_reporter_hist.R` (historical values check)

**What the error said:** The "purpose-grown biomass production" query is
missing from the project database.

**What's actually happening:** This test checks several GCAM versions one
after another. The v7.0 check finishes completely fine. It's the **next**
one, v7.1, that fails, because the sample database file used for that test
(`test7.1.dat`) doesn't have the biomass query data saved inside it.

**Is it a real bug?** Yes — but it's a problem with the test's sample data
file, not with the report-generating code itself.

**How to fix it:** Get a new copy of `testInputs/v_7.1/test7.1.dat` that was
exported with the "purpose-grown biomass production" query included. If that
query was deliberately left out of v7.1 databases, the code needs to be told
that it's optional for that version instead.

---

## Test 2 — `test_reporter_v7p0.R` (invalid version number check)

**What the error said:** Giving `GCAM_version = 4` (an invalid value) didn't
produce the exact error message the test expected.

**What's actually happening:** The code's error message is actually correct
— it lists all 8 supported versions, including the newly added `v9.1`. The
test file just has the *old* expected message typed in from before `v9.1`
was added, so the text comparison doesn't match.

**Is it a real bug?** No — this is just a test file that wasn't updated when
`v9.1` support was added. The actual feature works fine.

**How to fix it:** Add `, v9.1` to the expected error text on line 475 of
`test_reporter_v7p0.R`. One-line fix.

---

## Test 3 — `test_reporter_v8p2.R` (v8.2 population weights check)

**What the error said:** A data join failed because of missing (NA) values
in population weight numbers.

**What's actually happening:** When this test is re-run using the current
version of the code, it passes completely — all 185 checks succeed, zero
failures.

**Is it a real bug?** No, not anymore — it looks like whatever caused this
has already been fixed in recent commits. The failure you saw came from
testing an outdated, already-installed copy of the package (see the note at
the bottom of this document).

**How to fix it:** Nothing to fix in the code. Just make sure you reinstall
the package from the current source before running the tests again.

---

## Test 4 — `test_reporter_vScenarioMIPCMIP7.R` (ScenarioMIP/CMIP7 check)

**What the error said:** A required folder path ("db_path") was missing.

**What's actually happening:** The test is looking for a database file at
`testInputs/v_ScenarioMIPCMIP7/db_exp_scenarioMIPcmip7.dat`, but that entire
folder doesn't exist in this checkout at all. Since the file can't be found,
the code falls back to a generic "you forgot to tell me where the database
is" error, which is misleading but technically correct given what it found.

**Is it a real bug?** No — it's a missing test file, not a code problem.

**How to fix it:** Track down the `v_ScenarioMIPCMIP7` test database (it may
exist in one of the other checkouts, like `gcamreport-kaist`) and copy it
into `gcamreport-fork/tests/testthat/testInputs/v_ScenarioMIPCMIP7/`.

---

## Test 5 — `test_ui_v7p0.R` (v7.0 report generation, full run)

**What the error said:** Several 2021 rows for technologies like PV,
biomass, coal, gas, and wind couldn't be matched to the v7.0 capital-cost
reference table.

**What's actually happening:** The v7.0 capital-cost table already has all
of those technologies listed, at 5-year intervals (2015, 2020, 2025, ...).
The code is specifically designed to fill in a value for 2021 by
interpolating between the surrounding years — this is expected, normal
behavior for GCAM v7.0, which has always used 2021 as a base year.
Re-running this exact test against the current code — both on its own, and
right after re-running the other 3 failing tests first (to rule out one test
leaving behind bad leftover data for the next one) — completes with **zero**
failures.

**Is it a real bug?** No — same story as Test 3. This is a false alarm from
testing an outdated installed copy of the package.

**How to fix it:** Nothing to fix in the code. Reinstall from current source
and re-run.

---

## Why did Tests 3 and 5 fail if the code is fine?

`tests/testthat.R` runs `library(gcamreport)`, which loads whatever copy of
the package is currently **installed** on the computer — not the live code
sitting in the `gcamreport-fork` folder. If the installed copy was built
before some recent fixes were committed (several v7.0/v9.1-related commits
landed around the same time), the test run will use the old, buggy version
even though the source code on disk has already moved on.

**Fix:** before running the test suite, reinstall the package from the
current source:

```r
devtools::install(".")
```

or simply run the tests through the live source instead of the installed
copy:

```r
devtools::test(".")
```

---

## Summary table

| Test | Real code bug? | What's wrong | Fix effort |
|---|---|---|---|
| 1. Historical values | Yes | v7.1 sample database is missing a query | Replace/regenerate a data file |
| 2. Invalid version message | Yes (trivial) | Test's expected text wasn't updated for v9.1 | One-line text edit |
| 3. v8.2 population weights | No (false alarm) | Tested an outdated installed package | Reinstall & re-run |
| 4. ScenarioMIP/CMIP7 | Not code — missing file | Test database folder doesn't exist here | Copy in the missing data file |
| 5. v7.0 full report | No (false alarm) | Tested an outdated installed package | Reinstall & re-run |
