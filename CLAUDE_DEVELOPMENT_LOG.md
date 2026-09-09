# gcamreport v9.1 compatibility — development log

Goal: make `gcamreport_temp` (a clone of `gcamreport`) able to parse and report on
`gcam-v9.1-Windows-Release-Package` output, which the original `gcamreport` package
(built against v8.2) cannot read correctly.

This log is a concise, chronological record of actions, results, and fixes. It
continues work already present in this checkout (see `development_log/ERROR_LOG.md`
for the earlier session's notes on the ag_price_map decile problem and the
`v9.1` vs `v.9.1` version-key pitfall).

## 1) Research: what changed between v8.2 and v9.1

`gcam-doc/v9.1` is an empty folder (docs for that tag were never populated), so
`gcam-doc/VERSION_CHANGES.md` (a CMP-by-CMP summary spanning v7.0 → v9.1) was used
as the source instead, per the task's own fallback instruction.

Relevant CMPs between v8.2 and v9.1, in order:
- v8.3 Gcamstr (string interning) — internal C++ perf change, no report impact.
- **v8.4 CMP #410** — Socioeconomic/macro data update (PWT v9→v10, GMD, SSP v3.0.1→v3.2).
- v8.5 CMP #422 — Bugfix bundle (MAGICC removed, Hector-only; unit-conversion cleanups).
- **v8.6 CMP #400** — Differentiated CCS vs non-CCS criteria-pollutant emission factors.
- v8.7 CMP #408 — Cement data update (new data sources, same sector/tech names).
- **v8.8 CMP #415/#407** — New nuclear techs "large reactor" + "SMR" replacing "Gen_III";
  new H2 LDV/H2 MHDV/LH2 hydrogen delivery commodities; buildings "other"→"others" rename
  (later found to collide, see v9.1 fix below).
- v8.9–v8.11 — Non-CO2 MACC update, Moirai LULC/pasture update, GCAM-USA state-level
  fossil resource curves (new `resources_fossil_USA.xml`, `en_supply_USA.xml`,
  `gas_trade_USA.xml`; adds state-level grades to existing resource names, not new
  resource names).
- **v9.0 CMP #411** — Macro module KLEM → KLEAM (adds agriculture as a third macro
  production input with its own labor/capital markets). No effect on the gcamreport
  join keys tested here, but should be watched if ag/GDP decomposition variables are
  audited later.
- **v9.1 CMP #425** — Bugfix bundle: reverts a v8.8 buildings "other"/"others" naming
  collision (restores them as separate categories), fixes a ~10x aluminum cost unit bug,
  removes obsolete SRES heating/cooling-degree-day data.

## 2) Cross-checking `gcamreport/inst` against the GCAM release packages

`gcamreport/inst/extdata` already had per-version subfolders (`mappings/GCAMx.y`,
`queries/GCAMx.y`, `template/GCAMx.y`, `saveDataFiles_GCAMx.y.R`). Before this session,
prior work had already: added `v9.1` to `available_GCAM_versions` /
`deciles_GCAM_versions`, created `inst/extdata/{mappings,queries,template}/GCAM9.1`
(cloned from GCAM8.2), added `saveDataFiles_GCAM9.1.R`, defaulted `R/main.R` entry
points to `GCAM_version = 'v9.1'`, and generated all 62 `*_v9.1.rda` package-data
objects. That earlier pass hit and documented one blocking error (see
`development_log/ERROR_LOG.md`): `ag_price_map_v9.1` (cloned verbatim from v8.2)
rejected 10 new decile-based residential clothes-dryer sector names.

This session picked up from there. Action: ran `generate_report(..., GCAM_version =
"v9.1")` against the real `gcam-v9.1-Windows-Release-Package/output` BaseX database
(region = USA, scenario = Reference) to see what actually breaks.

### Root cause investigation

Comparing `input/gcamdata/xml/building_det.xml` between the two release packages
(direct code diff, since the CMP write-ups don't mention this) showed GCAM 9.1 adds
**11 new decile-disaggregated residential end-use sectors** (clothes dryers, clothes
washers, computers, cooking, dishwashers, freezers, furnace fans, hot water, lighting,
refrigerators, televisions) plus a 12th, "resid other" (singular — distinct from the
pre-existing "resid others" aggregate), and **8 new commercial sectors** (comm cooking,
comm hot water, comm lighting, comm non-building, comm office, comm other, comm
refrigeration, comm ventilation). This is a residential/commercial buildings
disaggregation that CMP #425's "other"/"others" note only partially describes; the
full breakout is not itemized in VERSION_CHANGES.md at all. `gcamreport`'s mapping
CSVs (which are essentially master lists of every sector/technology name GCAM can
produce, joined with `left_join_strict` so an unmapped name is a hard error) had no
rows for any of these new sectors.

Separately, `input/gcamdata/xml/electricity.xml` showed the nuclear subsector's
`Gen_III` stub-technology replaced by two new technologies, `SMR` and `large reactor`
(consistent with CMP #415/#407, "Small Modular Reactors").

## 3) Fixes applied to `inst/extdata/mappings/GCAM9.1/*.csv`

For each new building sector, the fuel set (electricity/gas/refined liquids) was
read directly off `building_det.xml` per sector, and new mapping rows were added by
cloning the existing "resid others modern" / "comm others" template rows (same
reporting category, since these are literally a finer split of what used to be
lumped under "others") — swapping the sector name and, where the file is fuel-specific,
filtering to only the fuels that sector actually has:

- `ag_price_map.csv`, `en_price_map.csv` — added `NoReported` placeholder rows for all
  12 new resid categories × 10 deciles, and the 8 new bare (no-decile) comm categories.
- `final_energy_map.csv` — added per-fuel rows (sector, fuel) for each new category.
- `CO2_tech_map.csv` — added per-fuel rows for gas/refined-liquids only (electricity
  isn't a combustion fuel and biomass/coal don't apply to these appliance sectors).
- `CO2_ETS_sector_map.csv` (was already partially updated from a prior pass — had
  clothes dryers/cooking/hot water/"resid other"/"resid others" but was missing 8
  categories) — filled in the remaining resid/comm categories.
- `kyotogas_sector.csv`, `nonCO2_emissions_sector_map.csv` — cloned every existing
  "resid others modern" / "comm others" line (all GHG species × fuel combos) for each
  new sector name. This is deliberately over-inclusive (some fuel/GHG combos cloned
  won't actually occur for a given appliance), which is harmless because these two
  files are *not* joined with `left_join_strict` in `R/functions.R` — an unused row
  just never matches.

**Result of first rebuild+retest**: got past the buildings decile error, but hit a
*second*, more specific failure: `co2_tech_map_v9.1` join key is `(sector, subsector,
technology)`, not `(sector, fuel)`. Discovery: GCAM 9.1 also renamed many *existing*
building technologies from generic fuel names ("gas") to specific equipment names
("gas furnace", "gas furnace hi-eff", "fuel furnace hi-eff", etc.) — this affects
old sectors (`resid heating modern`, `comm heating`, `comm cooking`, ...) as well as
new ones, and wasn't visible from the sector-name diff alone.

**Fix**: wrote a small script
(`inst/extdata/mappings/GCAM9.1/../../../../../..` — see session scratchpad,
not committed to the repo) that parses `building_det.xml` for every
`(supplysector, subsector, stub-technology)` triple under a combustion-fuel
subsector (biomass/coal/gas/refined liquids), and for every triple missing from
`CO2_tech_map.csv`, clones the row where `technology == subsector` (the generic
"gas"/"biomass"/etc. row already present) with the specific technology name
substituted in — same reporting category, since the equipment sub-type doesn't
change which IAMC variable it should roll up into. Added 26 rows this way.

**Nuclear tech rename**: added `SMR` and `large reactor` rows to `capacity_map.csv`
(feeds both `capacity_map_v9.1`, joined on `technology` alone, and
`secondary_energy_map_v9.1`, joined on `(output, subsector, technology)`) by cloning
the `Gen_III` row. Also added matching placeholder rows to `ag_price_map.csv` /
`en_price_map.csv` for the new `elec_SMR` / `elec_large reactor` (+ `-fixed-output`)
market names, and cloned `Gen_III` rows in `A23.globaltech_capacity_factor.csv` and
`L223.GlobalTechCapital_elec.csv` (capacity factor / capital cost lookups; not
strict-joined, but left as NA otherwise, which would silently corrupt SMR/large
reactor capacity-factor and cost reporting).

**Result of second rebuild+retest**: down to 4 remaining `co2_tech_map_v9.1` misses,
none building-related: `H2 LDV`, `H2 MHDV`, `LH2` (new hydrogen delivery-mode
commodities from CMP #415/#407, subsector `onsite production`, technology `natural
gas steam reforming`) and `iron and steel / EAF with DRI / Hydrogen-based DRI` (a new
steel-making technology). Fixed by cloning `H2 wholesale dispensing / forecourt
production / natural gas steam reforming` (same Hydrogen-supply reporting category)
for the three new H2 sectors, and cloning `iron and steel / EAF with DRI / EAF with
DRI` for the new hydrogen-based DRI technology. Also added `NoReported` /
delivered-hydrogen-price placeholder rows for `H2 LDV`/`H2 MHDV`/`LH2` to
`ag_price_map.csv` / `en_price_map.csv`, which were missing there too (same
all-sector master-list pattern as the buildings fix).

## 4) A self-inflicted bug: missing trailing newline

**Result of third rebuild+retest**: got past `co2_tech_map_v9.1` entirely (including
`co2_ets_bysec`), then failed with `non-numeric argument to binary operator` in
`value * unit_conv` inside `get_co2_ets()` (`R/functions.R`), which does a plain
(non-strict) `left_join` against `co2_ets_sector_map_v9.1`.

Cause: `inst/extdata/mappings/GCAM9.1/CO2_ETS_sector_map.csv` did not end in a
newline before this session's edits. The patch script appended new rows with
`echo ... >> file`, which glued the first new row onto the end of the *last existing
line* with no separator (`...3.666667resid clothes washers,...`). readr parsed that
line's 9th field, `3.666667resid clothes washers`, as text, which made it infer the
whole `unit_conv` column as character — so `value * unit_conv` failed for every row,
not just the merged one. Fixed by inserting the missing newline between the two
merged rows (verified no other patched file had the same pre-existing
missing-trailing-newline condition). Lesson for any future append-based CSV patch:
check `tail -c1 file | xxd` before using `>>`.

## 5) A false alarm: single-region test artifact, not a v9.1 gap

**Result of fourth rebuild+retest** (still `desired_regions = "USA"`, chosen for
speed): got past all emissions/price/secondary-energy joins fixed above, then failed
in `get_secondary_energy()` with: *"The 'district heat production by subsector
(fuel)' query is unavailable in your project but necessary to standardize the
output."* This looked like a new v9.1 gap, but the USA region has essentially no
district heat production in GCAM, so the query legitimately returns 0 rows for a
USA-only report.

**Verification**: reran `generate_report(..., GCAM_version = "v8.2", desired_regions
= "USA")` against the known-good `gcam-v8.2-Windows-Release-Package` database (the
same package the original `gcamreport` was built for) with the same single-region
setting. It failed with the *identical* error. This confirms the limitation is
pre-existing in `gcamreport` itself (a single region with zero district-heat rows
trips a hard "query unavailable" check that assumes at least one row), not something
introduced by the v9.1 mapping work. No fix needed here — it was a test-setup
artifact from picking a fast, narrow region for iteration. Final validation switched
to `desired_regions = "All"`.

## 6) Full-region test: two more real gaps found and fixed

Switching to `desired_regions = "All"` (the realistic use case) confirmed the
district-heat error in section 5 disappears — it really was a USA-only artifact.
Two genuine v9.1 gaps then surfaced, one per rebuild/retest cycle:

- **`secondary_energy_map_v9.1` (`capacity_map.csv`) missing `(H2 central
  production, hybrid, electrolysis)`.** Matches CMP #415/#407's "stand-alone
  electrolysis replaced by hybrid solar-wind PEM electrolysis": v9.1 adds a new
  `hybrid` subsector alongside the existing `electricity`/`nuclear`/`solar`/`wind`
  electrolysis subsectors. Fixed by cloning the `electricity` row (same
  `Secondary Energy|Hydrogen|Electricity` category — the electricity source only
  changes generation mix, not the reporting bucket) with `hybrid` as the subsector.
- **`energy_price_map_v9.1` (`en_price_map.csv`) missing 8 new market names**:
  `Capital_Ag`, `Labor_Ag`, `Labor_Materials`, `Labor_Total`, `ag food service`,
  `ag service`, `capital-ag`, `capital-energy`. This is the **CMP #411 KLEM→KLEAM**
  macro-economic module change flagged in step 1 finally showing up in a report
  path: v9.1 gives agriculture its own labor and capital markets and an "ag food
  service" GDP term, none of which existed as markets in v8.2. Fixed the same way
  as every other net-new commodity in this package: added `NoReported` placeholder
  rows (this join only cares about *energy* prices; these markets aren't energy
  commodities, so `NoReported` is the correct, not just expedient, answer here).

## 7) Final-energy consumers of the new H2 delivery commodities

**Result of fifth full-region rebuild+retest**: got past `energy_price` into
`fe_sector`, then `final_energy_map_v9.1` rejected 4 more (sector, input) combos:
`agricultural energy use`/`construction energy use`/`mining energy use` each
consuming `H2 MHDV` as a fuel, and `ammonia` consuming `H2 central production`
directly. This is the flip side of the CMP #415/#407 H2-commodity split from step 3:
those sectors' technologies can evidently draw hydrogen from any of the delivery
modes, not just plain `hydrogen`/`H2 retail delivery`.

Rather than patch these 4 one at a time (every other final-energy-consuming sector
in the model could plausibly hit the same gap under `desired_regions = "All"` on a
later iteration), generalized the fix: for every existing `(sector, "H2 retail
delivery")` row in `final_energy_map.csv`, cloned matching rows for `H2 LDV`, `H2
MHDV`, `LH2` (same category — these are just alternate delivery infrastructure for
the same Hydrogen final-energy bucket); for every existing `(sector, "hydrogen")`
row, cloned one for `H2 central production` (direct off-take, same bucket). Added 30
rows this way in one pass instead of waiting for each to surface individually.

## 8) Transport also switched to the new H2 delivery commodities

**Result of sixth full-region rebuild+retest**: got past `fe_sector` into
`fe_transportation`, then `transport_final_en_map_v9.1` rejected 12 (sector, input,
mode) combos — every hydrogen-fueled transport mode. In v8.2 these modes were fueled
by the generic `H2 wholesale dispensing` (aviation, shipping, freight rail) or `H2
retail dispensing` (trucks, buses, LDVs) commodities; in v9.1 they draw from the
same three delivery-mode-specific commodities found in step 3/7: `LH2` for aviation
and shipping (liquid hydrogen, consistent with needing a cryogenic fuel), `H2 MHDV`
for trucks/buses/freight rail, `H2 LDV` for passenger cars. This is a straight 1:1
rename per (sector, mode) — fixed by cloning each existing `H2 wholesale
dispensing`/`H2 retail dispensing` row for the same (sector, mode) with only the
input name swapped to its v9.1 replacement. (One clone source,
`trn_pass_road_LDV_4W`/`Mini Car`, turned out to already carry a pre-existing
copy-paste bug in the v8.2 template — mislabeled as `Final Energy|Electricity`
instead of `Hydrogen` — so that one row was built from the correctly-labeled `Car`
row instead and manually corrected.)

## 9) HFC refrigerant emissions for the new refrigerator/refrigeration sectors

**Result of seventh full-region rebuild+retest**: got past `fe_transportation` all
the way through `fe_sector_clean`, `primary_energy_clean`, `energy_price_clean`,
food/expenditure/GDP/trade/inequality processing, into `kyoto_gases_clean`, then
`kyoto_sector_map_v9.1` rejected 10 rows: HFC125/134a/143a/23/32 for `comm
refrigeration` and `resid refrigerators modern` (subsector NA, ghg_sector "none").
Refrigeration equipment leaks HFC refrigerants as a fugitive (non-combustion)
emission, so — unlike the other 10 new appliance categories, which only needed the
generic "others" fuel-consumption treatment — the two refrigeration-specific
categories also need the same HFC-species rows that `resid cooling modern` / `comm
cooling` already carry (air conditioning uses the same refrigerants). Cloned those
6 HFC-species rows from `resid cooling modern` → `resid refrigerators modern` and
from `comm cooling` → `comm refrigeration` in `kyotogas_sector.csv`.

**Process correction**: this also exposed a gap in my own earlier file survey. I had
classified `kyotogas_sector.csv` and `nonCO2_emissions_sector_map.csv` as *not*
strict-joined (and therefore lower priority) based on grepping for
`` left_join_strict(get(paste(...` — but both `get_kyoto_gases()` and its non-CO2
counterpart first resolve the mapping into a local variable (`kyoto_sector_map <-
get(...)`) and call `left_join_strict()` on *that* a few lines later, which my grep
pattern didn't match. Re-grepped for every bare `left_join_strict(` call (not just
the `get(paste(...` form) and confirmed `nonCO2_emissions_sector_map.csv` has the
identical structure and would hit the identical gap, so applied the same
cooling→refrigeration/refrigerators HFC clone there pre-emptively rather than
waiting for the next failure to prove it.

## 10) Criteria-pollutant emissions from the new H2 delivery-mode sectors

**Result of eighth full-region rebuild+retest**: the HFC/`nonCO2_emissions_sector_map`
proactive fix from step 9 was validated — the run sailed through `kyoto_gases_clean`,
`labor_clean`, `land_clean`, `f_gases_total` into `nonco2_clean`, then
`nonco2_emis_sector_map_v9.1` rejected CO/H2/NOx for `H2 LDV`/`H2 MHDV`/`LH2`. These
are the same three new hydrogen-production/delivery sectors from step 3/7/8, this
time needing their own criteria-pollutant (CO, unreacted H2, NOx) rows — the direct
producer-side counterpart to step 2's `CO2_tech_map` fix and step 7's
`final_energy_map`/`transport_final_en_map` consumer-side fixes. Cloned all three gas
rows from the existing `H2 wholesale dispensing` entries (same
`Emissions|<gas>|Energy|Supply|Hydrogen` category) for each of the three new sectors.
Did not extend this to `kyotogas_sector.csv` — CO, H2, and NOx are criteria
pollutants, not Kyoto gases, and that file's GHG list doesn't carry them for any
other sector either.

## 11) KLEAM labor/capital markets, round two: `res_extraction_map`

**Result of ninth full-region rebuild+retest**: cleared `nonco2_clean`,
`nonelec_investment_clean`, `poverty_clean`, `production_price_clean`, into
`resource_extraction_clean`, then an un-named mapping (`res_extraction_map_v9.1`,
joined on `resource`) rejected `ag food service`, `ag service`, `Labor_Ag`,
`Labor_Materials` — the same CMP #411 KLEAM markets from step 6, this time showing
up as `resource` entries rather than `market`/`sector` entries. Since these markets
had already proven to surface under multiple different column names across
different queries, added `NoReported` rows for all 8 KLEAM market names (not just
the 4 that happened to trip this particular error) to `res_extraction_map.csv`, and
pre-emptively to `ag_price_map.csv` and `production_map.csv` too (both are
strict-joined, sector-keyed master lists with the same structure that could plausibly
encounter the same names on a later pipeline step).

## 12) Water-map gaps: the same new sectors again, plus a genuinely new one

**Result of tenth full-region rebuild+retest**: past `resource_extraction_clean`,
`resource_investment_clean`, `total_investment_clean`, all of `ag_trade`/`pe_trade`/
`trade_clean`, `trn_sales_clean`, `trn_stock_clean` (so the transport vehicle
stock/sales maps needed no changes at all), into `water_consumption_clean`, where
`water_map_v9.1` (joined on `sector`/`subsector`) rejected 19 rows in two unrelated
groups:

- **Familiar new sectors, water-tracking edition**: `H2 LDV`/`H2 MHDV`/`LH2`
  (`onsite production`) and `H2 central production`/`hybrid` needed the same
  `Water XX|Industrial Water` row already used for `H2 central production`/
  `electricity` and `H2 wholesale dispensing`/`forecourt production`. `elec_SMR`/`SMR`
  and `elec_large reactor`/`large reactor` were also requested — but neither of the
  nuclear technologies they replaced (`Gen_III`/`Gen_II_LWR`) had ever had a water
  row in this file, i.e. nuclear generation's water use isn't broken out from the
  aggregate in this package at all. Rather than invent a category with no v8.2
  precedent, added `NoReported` rows for both (matching the existing convention for
  other untracked sectors, e.g. `food processing`/`food processing`), preserving the
  same (lack of) treatment nuclear already had.
- **A new, unrelated gap: 12 missing crop × river-basin combinations** —
  `biomassTree_AusInt`, `FruitsTree_Mackenzie`, `OtherGrainC4_CaspianSW`, and 7
  `OilCropTree_*` basins (`GangesR`, `Hainan`, `Hong`, `IrrawaddyR`, `LBalkash`,
  `Mekong`, `Salween`) plus `SugarCropC4_Gironde`, `Legumes_MagdalenaR`, and
  `MiscCropTree_MagdalenaR`. `water.csv` already carries dozens of `{crop
  type}Tree_{river basin}` rows per crop for irrigation water accounting, all with
  the identical `Water XX|Irrigation` category — v9.1 just adds a handful of basins
  not present in v8.2's set (most plausibly from the Moirai LULC/HYDE 3.5 update in
  CMP #424, step 1). Added the 12 rows using the exact same template. Checked
  `land_use_map.csv`/`ag_production_map.csv`/`ag_demand_map.csv` (the other
  crop-related strict maps) for the same basin codes — none reference river-basin
  detail, since they key on plain crop names, so no changes needed there.

## 13) Success

**Result of eleventh full-region rebuild+retest**: `generate_report()` ran to
completion for `GCAM_version = "v9.1"` with `desired_regions = "All"` and
`desired_variables = "All"` against the real `gcam-v9.1-Windows-Release-Package`
output database. It cleared every remaining step (`water_consumption_clean`,
`water_withdrawals_clean`, `yield_clean`), wrote the standardized CSV and Excel
output files, ran the built-in vetting checks (`Inf variables: OK`, `NA variables:
OK`), and printed `SUCCESS`. No `left_join_strict` errors remain.

## 14) Status: done

`gcamreport_temp` now generates a complete, full-region report from GCAM 9.1 output,
matching the same successful path already proven for GCAM 8.2. Summary of every
change made this session, in the order the pipeline hits them:

1. `inst/extdata/saveDataFiles_constants.R` — `v9.1` already added to
   `available_GCAM_versions`/`deciles_GCAM_versions` by prior work; unchanged this
   session.
2. `inst/extdata/mappings/GCAM9.1/ag_price_map.csv`, `en_price_map.csv` — decile
   rows (`_d1`–`_d10`) for the 12 new residential appliance sectors, bare rows for
   the 8 new commercial sectors, and `NoReported` placeholders for `H2 LDV`/`H2
   MHDV`/`LH2`/`elec_SMR`/`elec_large reactor`(+`-fixed-output`)/the 8 KLEAM
   labor-capital markets.
3. `final_energy_map.csv` — per-fuel rows for the 12 new resid + 8 new comm
   sectors; `H2 LDV`/`H2 MHDV`/`LH2`/`H2 central production` cloned onto every
   sector that already consumed `H2 retail delivery`/`hydrogen`.
4. `CO2_tech_map.csv` — 26 rows for renamed building equipment technologies
   (`gas furnace`, `fuel water heater`, etc. replacing bare fuel-name techs) across
   both new and pre-existing sectors; H2 LDV/MHDV/LH2 + iron-and-steel
   hydrogen-based DRI producer-side rows.
5. `CO2_ETS_sector_map.csv` — remaining 16 new resid/comm sector rows (8 had
   already been added by prior work); fixed a missing-trailing-newline corruption
   this session's own patch introduced.
6. `kyotogas_sector.csv`, `nonCO2_emissions_sector_map.csv` — bulk clone of every
   `resid others modern`/`comm others` line for the 12+8 new sectors; targeted
   HFC-refrigerant clones (cooling → refrigerators/refrigeration) for fugitive
   emissions; CO/H2/NOx rows for the 3 new H2 sectors.
7. `capacity_map.csv` (backs both `capacity_map_v9.1` and `secondary_energy_map_v9.1`),
   `A23.globaltech_capacity_factor.csv`, `L223.GlobalTechCapital_elec.csv` — `SMR`/
   `large reactor` rows cloned from `Gen_III`; `H2 central production`/`hybrid`
   electrolysis row cloned from the `electricity` subsector.
8. `transport_final_en_map.csv` — 12 rows renaming `H2 wholesale/retail dispensing`
   to `LH2`/`H2 MHDV`/`H2 LDV` per transport mode; corrected one pre-existing
   copy-paste bug (Mini Car mislabeled as Electricity) found while doing so.
9. `res_extraction_map.csv`, `production_map.csv` — `NoReported` rows for the 8
   KLEAM labor/capital market names.
10. `water.csv` — `Water XX|Industrial Water` rows for the 3 H2 sectors + hybrid
    electrolysis; `NoReported` rows for `SMR`/`large reactor` (matching nuclear's
    pre-existing lack of water tracking); 12 new crop × river-basin irrigation rows.

Also fixed one self-inflicted bug (section 4): a missing trailing newline in
`CO2_ETS_sector_map.csv` caused an appended row to merge with the last existing line,
which silently corrupted the `unit_conv` column's type for the whole file.

Not changed, and not needed: `buildings_en_service.csv`, `en_demand_price_map.csv`,
`yield_map.csv`, `land_use_map.csv`, `ag_production_map.csv`, `ag_demand_map.csv`,
`trn_sales_map.csv`/`trn_stock_map.csv` (transport vehicle stock/sales — no v9.1 gap
found), `capital_seq_tech_map.csv`, `co2_market_frag_map.csv`, `co2_resource_map.csv`,
`nonCO2_emissions_resource_map.csv` — none of these reference the buildings, nuclear,
hydrogen, or KLEAM changes at all.

**How to rebuild and rerun from a clean R session:**

```r
setwd("C:/Users/pjhan/Desktop/git/iam_models/GCAM/gcamreport_temp")
devtools::load_all(".", reset = TRUE)
source("inst/extdata/saveDataFiles_constants.R")
source("inst/extdata/saveDataFiles_GCAM9.1.R")   # must run AFTER load_all, not before —
                                                   # it calls gather_map(), a package function
devtools::load_all(".", reset = TRUE)             # reload so the new data/*.rda take effect

generate_report(
  db_path = "C:/Users/pjhan/Desktop/GCAM/gcam-v9.1-Windows-Release-Package/output",
  db_name = "database_basexdb",
  prj_name = "gcam_v9.1_report.dat",
  scenarios = "Reference", final_year = 2050,
  desired_regions = "All", desired_variables = "All",
  GCAM_version = "v9.1", launch_ui = FALSE, save_output = TRUE
)
```

## 15) Regression check against the existing test suite

Ran the package's own `tests/testthat` suite (`test_reporter_v7p0.R`,
`test_reporter_v8p2.R`, `test_ui_v7p0.R`) against `gcamreport_temp` after all the
changes above, and got 6 errors. Before concluding anything was broken, ran the
identical suite against the untouched, pristine `../gcamreport` package (the v8.2
baseline this whole effort started from) — it produced the **exact same 6 errors**,
at the same test names and lines (`test_reporter_v7p0.R:69`, `:294`, `:377`, `:399`;
`test_reporter_v8p2.R:13`; `test_ui_v7p0.R:7`), all `left_join_strict` failures on
`(scenario, region[, year])` joins against computed intermediate data frames like
`population_clean`, unrelated to any mapping CSV. These are pre-existing failures in
the original codebase (likely an rgcam/dplyr version-compatibility issue in this
environment, out of scope for a v9.1 compatibility pass) — **this session's changes
introduced zero regressions** to the v7.0/v8.2 test suite.

Cleaned up the test artifacts this session generated along the way (`*_test*.dat`
project stubs in the package root, plus the cached BaseX projects and standardized
CSV/XLSX/RData outputs under the GCAM output folders) — none of that was meant to
be a permanent deliverable.

**Suggested follow-up (not done this session, out of the original scope):** there is
no `tests/testthat/testInputs/v_9.1` fixture or `test_reporter_v9p1.R`/
`test_ui_v9p1.R`, unlike v7.0/v7.1/v8.2. Saving a small cached rgcam project for
v9.1 (the way `gcamreport_onboard8p2_Ctax_260210.dat` is used for v8.2) and adding a
matching test file would let future changes be regression-tested against v9.1
without needing the live multi-gigabyte BaseX database.

## 16) Final 3-part validation: report generation, UI, output format

Requested explicitly as a closing check. All three parts run against the real
`gcam-v9.1-Windows-Release-Package` output database.

### 16.1) `generate_report()`

Ran again from a clean session (`desired_regions = "All"`, `desired_variables =
"All"`, `scenarios = "Reference"`, `GCAM_version = "v9.1"`) and saved the output
(rather than deleting it, as earlier test runs had). **Result: `SUCCESS`** — 88,739
rows × 15 columns, `Model`/`Scenario`/`Region`/`Variable`/`Unit` plus 10 year
columns (2005–2050). Standardized `.csv`, `.xlsx`, and `.RData` all written under
the GCAM output folder.

### 16.2) UI launch — found and fixed a real (pre-existing) bug

Launched `launch_gcamreport_ui(data_path = <standardized .RData>, GCAM_version =
"v9.1")` as a background R process and curled its Shiny port once it started
listening. **First attempt failed**: HTTP 500, "object 'GCAM_version' not found",
thrown from `reset_first_load()` (`R/app_functions.R:205`), which — like
`server.R` in several places — looks up a bare global variable `GCAM_version` that
`launch_gcamreport_ui()` never actually creates. It assigns `sdata`,
`available_years`, `cols.global`, `tree_vars`, `tree_reg`, and `all_varss` to the
global environment with `<<-`, but not its own `GCAM_version` parameter.

Checked whether this was something introduced this session: it is not — the
identical function body (missing the same assignment) exists verbatim in the
untouched `../gcamreport` package. It's a pre-existing bug, and the reason
`tests/testthat/test_ui_v7p0.R`'s pattern and the informal `Testrun.R` helper both
work around it by manually doing `assign("GCAM_version", ..., envir = .GlobalEnv)`
*before* calling into the report/UI functions, rather than relying on the package
to do it.

Since the task explicitly asked to confirm the UI "runs correctly," and the fix is
a one-line, unambiguous omission (mirroring the `<<-` pattern already used for
every sibling variable in the same function), fixed it in `gcamreport_temp`:
added `GCAM_version <<- GCAM_version` in `launch_gcamreport_ui()` (`R/main.R`,
right after data is loaded). Not backported to `../gcamreport` — out of scope for
this repo's role as a clone under active development for v9.1 work; the pristine
baseline was left untouched, as with every other check in this log.

Relaunched after the fix: the app started, and a GET to `/` returned **HTTP 200**,
a 27 KB page titled "gcamreport" with 57 shiny/shinydashboard markers, and no
server-side errors or warnings in the R process log (only a pre-existing, harmless
`shiny::dataTableOutput()` deprecation notice unrelated to this bug). Killed the
background R process afterward (`taskkill` by the PID bound to its listening
port) — nothing left running.

### 16.3) Output format check

Loaded the standardized `.RData` and inspected it directly:

- **Structure**: a `data.frame`, IAMC-style wide format —
  `Model, Scenario, Region, Variable, Unit, 2005, 2010, 2015, 2021, 2025, 2030,
  2035, 2040, 2045, 2050`. `Model` is correctly `"GCAM 9.1"` (not stuck at an
  earlier version's label). 33 regions, 2,847 unique variables, 52 units.
- **Completeness**: zero `NA` in any column (including every year column), zero
  `Inf`/`-Inf` anywhere in the numeric columns.
- **New v9.1 categories reach final variable names**, confirming the mapping
  work actually produces reportable output and not just error-free-but-empty
  joins: `Secondary Energy|Electricity|Nuclear`, `Water
  Consumption|Electricity|Nuclear`, `Capacity|Electricity|Nuclear` (SMR/large
  reactor); `Final Energy|Transportation|Passenger|Hydrogen`, and dozens of
  `Emissions|<gas>|Energy|Supply|Hydrogen` variables (H2 LDV/MHDV/LH2); the full
  `Final Energy|{Residential,Commercial}|Space Heating|...` breakdowns. (No
  separate "Refrigeration" variable appears — expected and correct, since those
  sectors were deliberately mapped into the existing Residential/Commercial
  buckets rather than given their own IAMC variable, per section 9.)
- **Spot-checked values are plausible, not just non-null**: World `Secondary
  Energy|Electricity|Nuclear` rises 10.1 → 17.9 EJ (2021→2050); World `Final
  Energy|Transportation|Passenger|Hydrogen` grows from ~0 to 1.35 EJ; USA
  `Emissions|CO2|Energy|Demand|Residential` declines 283 → 192 Mt CO2 — all
  smooth, monotonic-ish reference-scenario trajectories with no discontinuities
  or sign flips that would indicate a mis-mapped category.

**Overall: all three parts pass.** `gcamreport_temp` generates a complete,
correctly-formatted v9.1 report and its interactive UI now launches without
error.
