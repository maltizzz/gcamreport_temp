# Function Catalog: gcamreport_temp/R

This document catalogs every function defined across the 6 R source files in `gcamreport_temp/R/` (`app_functions.R`, `data.R`, `functions.R`, `gcamreport.R`, `main.R`, `zzz.R`), with a concise description, inputs, and outputs for each.

## app_functions.R

Ancillary functions supporting the Shiny app UI (region/variable tree widgets, plot validation, data subsetting).

- **compute_height**
  - What it does: Computes a "nice" pixel height for rendered plots based on the number of ungrouped regions selected, so plots with more region facets get proportionally taller. Excludes the aggregate region groups (MAF, LAM, OECD90, REF, ASIA) from the count.
  - Input: `reg_all` — vector of region names.
  - Output: A single numeric height value (325 if fewer than 3 non-aggregate regions, otherwise `160 * ceiling(sqrt(n))`).

- **is_leaf**
  - What it does: Checks whether a nested tree node (used for the Shiny variable/region tree widget) is a leaf (i.e., has no further nested children) by testing the lengths of successive nested levels.
  - Input: `tree` — a tree node (nested list) to check.
  - Output: `TRUE` if the node is a leaf, `FALSE` otherwise.

- **change_style**
  - What it does: Recursively walks a tree of regions/variables and sets each node's `sttype` attribute to `"dis"` (disabled) if it's in the list of variables to disable (`tmp_vars`, only checked when `type == "variables"`), otherwise `"basic"`.
  - Input: `tree` — tree to restyle; `type` — `"regions"` or `"variables"`; `tmp_vars` — optional vector of variable IDs to mark disabled.
  - Output: The tree with updated style attributes on every node.

- **check_user_choices_plot**
  - What it does: Validates a user's plotting selections in the Shiny app, generating a vector of error messages if no scenario/year/region/variable is selected, or if a "grouped" plot is requested but variables span more than one top-level category.
  - Input: `vars`, `scen`, `years`, `reg` — user selections; `grouped` — logical, whether a grouped plot is requested.
  - Output: A character vector of error messages (empty if all validations pass).

- **update_user_choices_plot**
  - What it does: Reads the currently selected regions/variables from the Shiny tree widgets, applies "first load" / "no selection" default logic (selecting everything on first load, or nothing when the user cleared a selection), flattens the selected tree nodes into vectors, and assembles all plotting inputs into one list.
  - Input: `selected_scen`, `selected_years` — user selections; `tree_regions`, `tree_variables` — shinyTree widget objects; `sidebarItemExpanded` — which sidebar panel is currently expanded. Also relies on several global/mutable variables (`firstReg`, `firstVars`, `noReg`, `noVars`, `GCAM_version`).
  - Output: A named list with `scen`, `years`, `cols`, `vars_ini`, `reg_ini`, `vars`, `reg`, `basic_reg`, `basic_vars` used to drive the plot/data sample.

- **reset_first_load**
  - What it does: Initializes/resets the global state used the first time the Shiny app loads — builds the initial region and variable trees, records the base column set, and resets the "first load" flags.
  - Input: none (relies on globals `GCAM_version`, `sdata`).
  - Output: None (side effect only); sets globals `tree_reg`, `cols.global`, `tree_vars`, `firstLoad`, `firstReg`, `firstVars`, `noReg`, `noVars`, `updatedVars`, `all_varss`.

- **do_data_sample**
  - What it does: Subsets the standardized dataset (`sdata`) to the scenarios, years, columns, variables, and regions currently selected by the user in the app (handling the "all"/"none" selection special cases via `basic_reg`/`basic_vars` flags).
  - Input: `sdata` — full dataset; `sel_scen`, `sel_years`, `sel_cols` — selected scenarios/years/columns; `sel_vars`, `sel_reg` — selected variable/region tree nodes; `basic_reg`, `basic_vars` — flags indicating "use all" (1), "use none" (2), or "use selection" (other).
  - Output: A tibble containing the filtered/selected subset of data.

- **do_mount_tree**
  - What it does: Recursively builds a nested list ("tree") structure from a data frame's columns, one nesting level per column, used to populate the Shiny `shinyTree` region/variable selectors, tagging each node with display attributes (`sttype`, `stopened`, `sticon`, `stselected`, `my_id`).
  - Input: `df` — data frame; `column_names` — names of columns to nest by; `current_column` — current recursion depth (default 1); `selec` — whether nodes start selected; `iid` — accumulated id path used internally.
  - Output: A nested list (tree) suitable for `shinyTree`.

- **do_unmount_tree**
  - What it does: Flattens a nested `shinyTree`-style list back into a flat character vector of selected values — for `"variables"` it joins the path after the first level with `|`, for `"regions"` it takes just the last path segment.
  - Input: `base_tree` — nested list (selected tree nodes); `type` — `"variables"` or `"regions"`.
  - Output: A character vector of flattened selections, or `NULL` if the tree is empty.

- **do_collapse_df**
  - What it does: Collapses every row of a data frame/data table into a single `|`-delimited string per row (used to build a searchable list of all variable/region label combinations), stripping out any `NA` placeholders introduced by the join.
  - Input: `basic_data` — data frame/data.table to collapse.
  - Output: A character vector, one collapsed string per row.

## data.R

This file contains **no functions**. It consists entirely of roxygen `@format`/dataset-documentation blocks (`NULL`-bodied objects with `@docType data`) describing the package's bundled internal datasets (region/continent mappings, conversion factors, GWP tables, sector/technology mapping tables, templates, etc., per supported GCAM version). No `name <- function(...)` or `name = function(...)` definitions were found in this file.

## functions.R

The largest source file, containing ~106 functions: general-purpose ancillary/utility helpers, followed by a long series of `get_*` functions (each retrieves one or more GCAM queries, transforms/maps them to standardized IAMC-style reporting variables, and assigns the result to a global variable), plus functions that bind the results into the final report and validate it.

### Ancillary / Utility Functions

- **find_closest_values**
  - What it does: Finds the two closest values in a vector to a target value — the largest value ≤ target and the smallest value ≥ target.
  - Input: `values_vector` (numeric vector), `target_value` (single numeric value).
  - Output: A length-2 numeric vector `c(smaller, larger)`.

- **interpolateGCAMdata**
  - What it does: Ensures a specific year (e.g. the base year) is present in a dataset by linearly interpolating between the two closest existing years, grouped by all other columns.
  - Input: `data` (data frame), `yearcol` (default `'year'`), `valuecol` (default `'value'`), `year_to_appear` (year(s) that must exist, default `base_year`).
  - Output: The input data with the missing year(s) added via linear interpolation (`stats::approx`, rule 2).

- **listYears**
  - What it does: Returns the set of years reported by given scenario(s)/query(ies) in an already-loaded rgcam project; can require the year to appear in any scenario (union, filtered by frequency) or all scenarios (intersection).
  - Input: `projData` (loaded rgcam project object, not a filename), `scenarios` (optional vector), `queries` (optional vector), `anyscen` (logical, default TRUE).
  - Output: Numeric vector of years.

- **check_inf**
  - What it does: Checks whether a dataset's value column contains `Inf`; issues a `warning()` naming the dataset if so, but does not alter the data.
  - Input: `dataset`, `value_var_name` (default `'value'`), `dataset_name` (label for the warning).
  - Output: The unmodified `dataset` (side-effect: warning).

- **check_queries**
  - What it does: Verifies that all GCAM queries required to compute a given reporting variable (per `var_fun_map_<version>`) are present in the loaded project; `stop()`s with an informative message if a required query is missing.
  - Input: `var` (variable name), `GCAM_version` (default `'v8.2'`).
  - Output: None (invisible); called for its validation side effect.

- **filter_data_regions**
  - What it does: Filters a dataset's `region` column down to the user's `desired_regions.global` (if not `"All"`) and further restricts to regions present in the version-specific region/continent mapping (plus `'All'`).
  - Input: `data`, `GCAM_version` (default `'v8.2'`).
  - Output: Filtered data frame.

- **compute_reg_sec_weight**
  - What it does: Computes, for a hierarchical `|`-delimited `var` string, the regional-sectoral weight of each region's contribution relative to the World total at each level of the hierarchy (World weight = 1).
  - Input: `dt` (data frame with `scenario`, `region`, `var`, `year`, `value`).
  - Output: Data frame with `reg_sec_weight` column, completed over all scenario/var/year/region combinations (0-filled).

- **compute_sec_prevsec_weight**
  - What it does: Similar hierarchical decomposition of a `|`-delimited `var`, but computes each sector's share relative to its immediate parent sector within a region (not the World total), multiplying weights down the hierarchy.
  - Input: `dt` (same shape as above).
  - Output: Data frame with `sec_prevsec_weight` column.

- **handle_warning**
  - What it does: Issues a warning about a mismatch between mapping file(s) and/or a query; if run interactively (and `.myGlobals$interactive.global` is TRUE), prompts the user to manually check (stops) or continue.
  - Input: `mapping_name1`, `mapping_name2` (optional), `query_name` (optional; at least one of the latter two required).
  - Output: None (side effects: warning, possible `stop()` or interactive prompt).

- **left_join_strict**
  - What it does: A stricter `dplyr::left_join` that errors if rows in `left_df` don't find a match in `right_df`, except for rows containing user-specified "ignore" patterns (e.g., custom policy names) which are silently dropped instead of raising an error.
  - Input: `left_df`, `right_df`, `by` (join keys), `by_message` (columns to show in error), `mapping` (label for error message), `ignore` (patterns to exempt), `...` (passed to `left_join`).
  - Output: Joined data frame (or `stop()` with details of unmatched rows, saved to `left_join_strict_details` in global env).

- **left_join_error_no_match**
  - What it does: Restrictive left join (borrowed from `gcamdata`) that errors if the row count changes or if any newly joined columns contain NA, guaranteeing a full match.
  - Input: `d` (data frame/tibble), `...` (passed to `left_join`), `ignore_columns` (columns exempt from the NA check).
  - Output: Joined tibble (or `stop()`).

- **filter_desired_regions**
  - What it does: Scans the loaded project's queries for one containing a `region` column and returns its unique region values as the "desired regions"; falls back to the user-supplied vector with a warning if none found.
  - Input: `des_reg` (user-specified desired regions vector).
  - Output: Vector of region names.

- **transform_to_xml**
  - What it does: Wraps a list of parsed GCAM query definitions (each with `title`/`query`) into `<aQuery>` blocks and combines them into a single `<queries>` XML document.
  - Input: `parsed_queries_list` (list of query objects).
  - Output: An `xml2::xml_document`.

- **start_with_pattern**
  - What it does: Returns the subset of a character vector whose elements start with a given string pattern.
  - Input: `vector`, `pattern`.
  - Output: Filtered character vector.

- **filter_loading_regions**
  - What it does: Filters a raw GCAM query dataframe to desired regions, handling special cases: CO2 price markets (parsed via string splitting on emission-type keywords), "supply of all markets" (region extracted via regex), and generic `region`/`market` columns; also warns if user-specified regions are unavailable in the data.
  - Input: `data`, `desired_regions` (default `"All"`), `variable` (query/variable label controlling special-case logic), `GCAM_version`.
  - Output: Filtered data frame.

- **filter_variables**
  - What it does: Filters a dataset's `var` column to the user's `desired_variables.global` selection (plus `'NoReported'` and any `extra` variables), unless `desired_variables.global == "All"`.
  - Input: `data`, `variable` (unused legacy param), `extra` (additional variables to always keep).
  - Output: Filtered data frame.

- **gather_map**
  - What it does: Converts a "wide" mapping table with multiple `var`-prefixed columns into long format, dropping empty/NA variable entries.
  - Input: `df` (mapping data frame with one or more `var*` columns).
  - Output: Long-format data frame with a single `var` column.

- **conv_ghg_co2e**
  - What it does: Converts raw GHG emissions (query values tagged with a combined `ghg_sector` field) into CO2-equivalent units by separating gas from sector, filtering to recognized GHG gases, and multiplying by the appropriate Global Warming Potential (GWP) from the chosen GWP table (AR4/AR5/AR6).
  - Input: `data`, `GCAM_version`, `GWP_version` (default `'AR5'`).
  - Output: Data frame with `value` converted to CO2e and `Units = "CO2e"`.

- **conv_EJ_GW**
  - What it does: Converts an energy flow in EJ to an implied capacity in GW, using a capacity factor and version-specific hours-per-year / EJ-to-GWh conversion constants.
  - Input: `data`, `cf` (capacity factor), `EJ` (energy quantity column/expression), `GCAM_version`.
  - Output: `data` with an added `gw` column.

- **approx_fun**
  - What it does: Wraps `stats::approx` to interpolate/extrapolate a value series over given years (constant extrapolation with rule 1 or 2); catches errors and returns NA with a message rather than failing.
  - Input: `year`, `value`, `rule` (1 or 2; other values trigger `stop()`).
  - Output: Interpolated/extrapolated numeric vector (invisible).

- **check_match**
  - What it does: Diagnostic helper comparing the unique values of a column in dataset `x` against a column in dataset `y`; prints values present in `x` but not `y` (`opt="e"`) or present in both (`opt="i"`).
  - Input: `x`, `y` (data frames), `colmn_x`, `colmn_y` (defaults to `colmn_x`), `opt` (`"e"` or `"i"`).
  - Output: Printed message/list (used interactively for debugging mapping files); no meaningful return value.

### Load-Queries Functions (`get_*`) — Socioeconomics

- **get_population** — Retrieves "population by region" and converts thousands to millions. Input: `GCAM_version`. Output: sets global `population_clean` (`var = "Population"`).
- **get_population_weights** — Computes each region's share of world population per scenario/year (World = 1) from `population_clean`. Input: `GCAM_version`. Output: sets global `pop_weights` (`scenario, region, year, share`).
- **get_poverty** — From subregional income-by-decile data (`income_raw`), computes population shares below World Bank extreme-poverty ($2.15/day), LMIC ($3.65/day), and UMIC ($6.85/day) thresholds; only available for GCAM versions supporting deciles. Input: `GCAM_version`. Output: sets global `poverty_clean` (or NULL with a warning if unsupported).
- **get_inequality** — Computes income-inequality metrics from decile income data: bottom-40%-to-national-average income ratio, and the Gini coefficient (via trapezoidal Lorenz-curve integration). Input: `GCAM_version`. Output: sets global `inequality_clean` (or NULL with warning).
- **get_income** — Computes each income decile's share of total residential income, regionally and at the World level. Input: `GCAM_version`. Output: sets globals `income_raw` (filtered/raw subregional income query) and `income_clean` (share-by-decile).
- **get_labor** — Retrieves employed labor force from the "National Account" query (labor-force account) and computes inactive labor force as population minus active labor. Input: `GCAM_version`. Output: sets global `labor_clean` (or NULL with warning if unsupported).
- **get_gdp_ppp** — Retrieves GDP per-capita PPP, multiplies by population for total regional GDP, computes annual per-capita GDP growth rate, and GDP per capita relative to an OECD average benchmark. Input: `GCAM_version`. Output: sets globals `GDP_PPP_clean`, `GDP_PPP_pc_growth_clean`, `GDP_PPP_pc_oecd_share_clean`.
- **get_gdp_mer** — Retrieves "GDP MER by region" and converts million 1990$ to billion 2010$. Input: `GCAM_version`. Output: sets global `GDP_MER_clean`.
- **get_goods_trade** — Sums materials/energy/capital net-export accounts from "National Account" into a single monetary trade balance. Input: `GCAM_version`. Output: sets global `goods_trade_clean` (or NULL with warning if unsupported).
- **get_value_added** — Splits the "value-added" account equally (1/3 each) across Industry, Agriculture, and Services. Input: `GCAM_version`. Output: sets global `value_added_clean` (or NULL with warning).
- **get_en_expenditure** — Computes household energy expenditure as a share of income by decile, using building service costs × building energy demand, calibrated by an external multiplier joined against decile income; also computes regional-average and population-weighted World shares. Input: `GCAM_version`. Output: sets global `energy_expenditure_per_clean`.
- **get_food_expenditure** — Computes household food expenditure share of income by decile (or aggregate if income-group queries unavailable), calibrated with an external food-expenditure multiplier. Input: `GCAM_version`. Output: sets global `food_expenditure_per_clean`.
- **get_expenditure** — Combines food and energy expenditure shares by decile into a total household expenditure share. Input: `GCAM_version`. Output: sets global `expenditure_per_clean`.
- **get_capital_stock** — Retrieves the "capital-stock" account from National Account, converting million 1990$ to billion 2010$. Input: `GCAM_version`. Output: sets global `capital_stock_clean` (or NULL with warning).
- **get_capital_formation** — Computes annual net capital formation as the year-over-year change in `capital_stock_clean`. Input: `GCAM_version`. Output: sets global `capital_formation_clean`.

### Load-Queries Functions — Food & Agriculture

- **get_food_availability** — Computes per-capita food availability (kcal/cap/day) from food consumption data, adjusted upward for food waste share (SSP/region/year-specific) since GCAM does not track consumer waste directly; aggregates regionally and as a population-weighted World value. Input: `GCAM_version`. Output: sets global `food_availability_clean`.
- **get_food_demand** — Relabels `food_availability_clean`'s variable names from "Food Availability" to "Food Demand" (treated as equivalent). Input: `GCAM_version`. Output: sets global `food_demand_clean`.
- **get_food_intake** — Computes per-capita food intake (kcal/cap/day) directly from food consumption query (without the waste-share adjustment applied to availability), regionally and as population-weighted World average. Input: `GCAM_version`. Output: sets global `food_intake_clean`.
- **get_forestry** — Computes industrial roundwood production/demand (domestic + imports/exports) and wood-fuel production/demand (derived from forest residue biomass converted to volume via a historically-calibrated EJ-to-m³ ratio, with a special China post-2025 adjustment), aggregated into total roundwood variables. Input: `GCAM_version`. Output: sets globals `forestry_demand_clean`, `forestry_production_clean`.
- **get_ag_trade** — Computes net agricultural (and forestry) trade as exports minus imports, converting to dry-matter mass using water-content adjustments, from Armington-competition trade queries. Input: `GCAM_version`. Output: sets global `ag_trade`.
- **get_fert_consumption** — Retrieves fertilizer consumption by region and maps inputs to reporting variables. Input: `GCAM_version`. Output: sets global `fert_consumption_clean`.
- **get_yield** — Computes agricultural yield (production/land area) at regional and World level, using land area (from `land_yield`, adjusted for scaler effects) and production (from `ag_production_clean`), with 0/NaN guarding. Input: `GCAM_version`. Output: sets global `yield_clean`.
- **get_biomass_shares** — Computes the share of biomass production coming from residues + municipal solid waste (MSW) versus purpose-grown biomass, for later use in adjusting ag demand. Input: `GCAM_version`. Output: sets global `biomass_shares`.
- **get_ag_demand** — Combines crop, meat/dairy, and biomass demand balances (biomass adjusted by `biomass_shares` and unit-converted EJ→Mt), maps to reporting sectors, and converts to dry-matter mass via water content. Input: `GCAM_version`. Output: sets global `ag_demand_clean`.
- **get_ag_weights** — Computes demand-based weights of each agricultural sector/input relative to its parent price-reporting variable, regionally and globally (World=1), for use in price aggregation. Input: `GCAM_version`. Output: sets globals `ag_weights`, `ag_wld_weights`.
- **get_ag_production** — Combines crop and meat/dairy production queries (biomass unit-converted EJ→Mt) and converts to dry-matter mass using water content. Input: `GCAM_version`. Output: sets global `ag_production_clean`.
- **get_land** — Computes land allocation area by crop/water source, applying a cereal-crop scaler adjustment (to reconcile harvested-area mismatches) that proportionally rebalances non-cereal cropland; also computes annual forest area change and an unscaled `land_yield` variant for yield calculations. Input: `GCAM_version`. Output: sets globals `land_clean`, `land_yield`.

### Load-Queries Functions — Climate & Emissions

- **get_forcing** — Retrieves "total climate forcing" (World-level). Input: `GCAM_version`. Output: sets global `forcing_clean` (`var = "Forcing"`).
- **get_temperature** — Retrieves "global mean temperature" (World-level). Input: `GCAM_version`. Output: sets global `global_temp_clean` (`var = "Temperature|Global Mean"`).
- **get_co2_concentration** — Retrieves "CO2 concentrations" (World-level). Input: `GCAM_version`. Output: sets global `co2_concentration_clean` (`var = "Concentration|CO2"`).
- **get_co2_ets** — Retrieves World's CO2-ETS (emissions-trading-system) emissions by region and by sector (mapped via `co2_ets_sector_map`). Input: `GCAM_version`. Output: sets globals `co2_ets_byreg`, `co2_ets_bysec`.
- **get_nonbio_tmp** — Computes, per sector, the difference between the standard "by sector" CO2 query and the "no bio" variant (used to isolate negative bioenergy emissions). Input: `GCAM_version`. Output: sets global `nonbio_diff` (intermediate input for `get_co2_emiss`).
- **get_co2_emiss** — Combines by-tech and by-resource CO2 emissions, redistributing the bio/no-bio difference (`nonbio_diff`) across technologies proportional to their emissions share (excluding pure coal/gas techs), maps to reporting categories, and cross-checks the regional total against the "CO2 emissions by region" query (warns if mismatched). Input: `GCAM_version`. Output: sets global `co2_emiss`.
- **get_gross_co2_emiss** — Adds back CO2 removal (sequestration) to net CO2 emissions to compute "Gross" emissions (excluding the BECCS/AFOLU negative-emissions credit). Input: `GCAM_version`. Output: sets global `gross_co2_emiss_clean`.
- **get_lu_co2** — Computes land-use-change CO2 emissions (`Emissions|CO2|AFOLU`, converting C to CO2), also duplicating it into `Emissions|CO2` and an NGHGI-style AFOLU variable. Input: `GCAM_version`. Output: sets global `LUC_emiss`.
- **get_co2_emissions** — Combines `co2_emiss` (energy/industrial) and `LUC_emiss` (land use) into one total CO2 emissions dataset. Input: `GCAM_version`. Output: sets global `co2_emissions_clean`.
- **get_nonco2_emissions** — Retrieves non-CO2 (CH4, N2O, etc.) emissions by sector and by resource, handling special sector splits (forest/grassland fires, waste sub-categories) and combining with F-gas results. Input: `GCAM_version`. Output: sets global `nonco2_clean`.
- **get_fgas** — Converts F-gas (HFC/PFC) emissions to CO2e using GWP factors for the requested `GWP_version`, computing totals and separate HFC/PFC subtotals (normalized back to physical mass using a reference gas's GWP). Input: `GCAM_version`, `GWP_version` (default `'AR5'`). Output: sets globals `f_gases_total`, `f_gases_hfc`, `f_gases_pfc`.
- **get_kyoto_gases** — Aggregates all Kyoto-basket GHGs (CO2 energy/industrial, CO2 AFOLU, non-CO2) by sector into CO2e, handling the same fire/waste sector splits. Input: `GCAM_version`, `GWP_version` (default `'AR5'`). Output: sets global `kyoto_gases_clean`.
- **get_refliq_bioshare** — Computes biomass's share of refined-liquids production by region and World (used elsewhere to split bio vs. fossil liquid fuels). Input: `GCAM_version`. Output: sets global `refliq_bioshare`.
- **get_co2_sequestration** — Maps "CO2 sequestration by tech" to reporting categories. Input: `GCAM_version`. Output: sets globals `co2_sequestration_clean` and the raw removal data `co2_removal_raw` (the latter feeds `get_gross_co2_emiss`).

### Load-Queries Functions — Water

- **get_water_withdrawals** — Retrieves water withdrawal data. Input: `GCAM_version`. Output: sets global `water_withdrawals_clean`.
- **get_water_consumption** — Retrieves water consumption data. Input: `GCAM_version`. Output: sets global `water_consumption_clean`.

### Load-Queries Functions — Energy Supply & Demand

- **get_primary_energy** — Retrieves primary energy consumption with CCS (direct-equivalent, EJ only, excluding water) mapped to reporting fuel categories. Input: `GCAM_version`. Output: sets global `primary_energy_clean`.
- **get_pe_trade_prod** — Sums fossil-resource production (coal, natural gas, oil) plus biomass production (purpose-grown, residue, MSW) by resource/region/year, as a "production" component for trade balance. Input: `GCAM_version`. Output: sets global `pe_trade_prod`.
- **get_pe_trade_supply** — Extracts regional coal/gas/oil/biomass demand from the "supply of all markets" query by parsing region out of the market name, as the "demand" component for trade balance. Input: `GCAM_version`. Output: sets global `pe_trade_supply`.
- **get_pe_trade** — Computes net primary-energy trade (production − demand) by resource. Input: `GCAM_version`. Output: sets global `pe_trade`.
- **get_elec_gen_tech** — Retrieves electricity generation by technology (handling grid-region subsector naming), plus gas/hydrogen/district-heat/refined-liquids production by technology, mapped to secondary-energy reporting variables; aggregates into clean totals and appends secondary solids. Input: `GCAM_version`. Output: sets globals `secondary_energy_raw`, `secondary_energy_clean`.
- **get_secondary_solids** — Computes "Secondary Energy|Solids|Biomass" and "|Coal" (and their sum) from delivered-biomass/coal inputs-by-sector. Input: `GCAM_version`. Output: sets global `secondary_solids`.
- **get_consumption_hh** — Computes household energy-consumption share by decile from building final energy by service, regionally and at World level; only for decile-supporting GCAM versions. Input: `GCAM_version`. Output: sets global `consumption_hh_clean` (or NULL with warning).
- **get_fe_sector_tmp** — Retrieves final energy consumption by sector and fuel (excluding transport sectors, handling decile disaggregation) mapped to reporting variables. Input: `GCAM_version`. Output: sets globals `fe_sector_raw`, `fe_sector`.
- **get_fe_transportation_tmp** — Retrieves mode-specific transport final energy (rail, ship, domestic air, etc.) by mode and fuel, mapped to reporting variables. Input: `GCAM_version`. Output: sets globals `fe_transportation_raw`, `fe_transportation`.
- **get_fe_sector** — Merges `fe_sector` and `fe_transportation` results, summing to avoid duplicate reporting where sector- and subsector-level queries overlap (e.g., international vs domestic aviation). Input: `GCAM_version`. Output: sets global `fe_sector_clean`.
- **get_total_trade** — Combines agricultural trade and primary-energy trade into one dataset. Input: `GCAM_version`. Output: sets global `trade_clean`.
- **get_energy_service_transportation** — Computes transport service output by mode (converted million→billion km/yr) and derives Active/Public passenger-transport shares (regionally and at World level). Input: `GCAM_version`. Output: sets global `energy_service_transportation_clean`.
- **get_floor_space** — Retrieves building floorspace (with decile disaggregation handling) mapped to reporting variables. Input: `GCAM_version`. Output: sets global `floor_space_clean`.
- **get_hdd_cdd** — Applies a static (version-specific, non-GCAM-query) heating/cooling degree-day dataset uniformly across all loaded scenarios. Input: `GCAM_version`. Output: sets global `hdd_cdd_clean`.
- **get_industry_production** — Retrieves industry primary output by sector (grouping all chemical subsectors together) mapped to reporting variables. Input: `GCAM_version`. Output: sets global `industry_production_clean`.
- **get_iron_steel_imports** — Extracts the domestic portion of "regional iron and steel sources" as imports-related iron/steel data. Input: `GCAM_version`. Output: sets global `iron_steel_imports`.
- **get_iron_steel_exports** — Extracts "traded iron and steel" data, deriving the exporting region from the subsector name. Input: `GCAM_version`. Output: sets global `iron_steel_exports`.
- **get_iron_steel_clean** — Combines iron/steel imports and exports into one dataset. Input: `GCAM_version`. Output: sets global `iron_steel_clean`.

### Load-Queries Functions — Prices

- **get_ag_price_wld_tmp** — Computes a World agricultural price index (base year 2020=1, except biomass converted to $/GJ) weighted by global agricultural demand weights (`ag_wld_weights`). Input: `GCAM_version`. Output: sets global `ag_price_wld`.
- **get_ag_price** — Computes regional agricultural price indices (analogous to `get_ag_price_wld_tmp` but using regional `ag_weights`), then appends the precomputed World values. Input: `GCAM_version`. Output: sets global `ag_price_clean`.
- **get_price_var_tmp** — Extracts the unique set of CO2-price reporting variable names from the `co2_market_frag_map` mapping table. Input: `GCAM_version`. Output: sets global `price_var`.
- **get_regions_tmp** — Extracts the set of regions relevant to carbon-price computation from the CO2-market mapping filtered to desired/available regions. Input: `GCAM_version`. Output: sets global `regions.global`.
- **get_co2_price_global_tmp** — Retrieves the global/World CO2 price (from `"WorldCO2"`/`"globalCO2"` markets), converting units and mapping to fragmented-price reporting variables, expanded across all regions. Input: `GCAM_version`. Output: sets global `co2_price_global` (or NULL if no global market present).
- **get_co2_price_share_bysec** — Computes, per region/scenario at the last historical year, (a) the share of CO2 emissions covered by an ETS relative to total CO2 by sector, and (b) each sector's share of total regional CO2 emissions relative to the World. Input: `GCAM_version`. Output: sets global `co2_price_share_bysec`.
- **get_co2_price_fragmented_tmp** — Handles regionally-fragmented (non-global) CO2 markets/prices, classifying markets into building/industry/transport/ETS categories, removing "Rest of World" double-counting, and blending CO2 + CO2_ETS prices using the sectoral ETS shares. Input: `GCAM_version`. Output: sets global `co2_price_fragmented` (or NULL if not applicable).
- **get_co2_price** — Combines global and fragmented CO2 prices, completing missing scenario/region/year combinations with 0, and computes a "Global" weighted-average value using sectoral emission shares. Input: `GCAM_version`. Output: sets global `co2_price_clean`.
- **get_gov_revenue** — Computes government carbon revenue as CO2 emissions (by demand sector) multiplied by the corresponding carbon price, summed across sectors. Input: `GCAM_version`. Output: sets global `gov_revenue_clean`.
- **get_en_weights** — Computes energy-consumption-based weights of each sector relative to its parent energy-price reporting variable, regionally and globally, analogous to `get_ag_weights` but for final/primary/secondary energy. Input: `GCAM_version`. Output: sets globals `en_weights`, `en_wld_weights`.
- **get_energy_price_tmp** — Builds a comprehensive regional energy-price dataset from "prices of all markets" and CO2 prices (checking for missing CO2 markets and optionally prompting the user), with special handling to embed a carbon-price subsidy/cost into fragmented biomass prices. Input: `GCAM_version`. Output: sets global `energy_price`.
- **get_total_revenue** — Computes total resource revenue as fossil resource production (coal/oil/gas, EJ) multiplied by the corresponding regional resource price. Input: `GCAM_version`. Output: sets global `total_revenue`.
- **get_regional_emission** — Computes regional non-CO2 (CH4, N2O) fugitive emissions from fossil-resource extraction using fixed emission coefficients times regional production. Input: `GCAM_version`. Output: sets global `regional_emission`.
- **get_energy_price** — Computes a weighted-average final/primary/secondary energy price at the World level by combining regional-sectoral weights (`compute_reg_sec_weight`) with regional energy prices and demand-price mapping. Input: `GCAM_version`. Output: sets global `energy_price_clean`.
- **get_resource_extraction** — Maps raw "resource production" query values to reporting extraction variables with unit conversion. Input: `GCAM_version`. Output: sets global `resource_extraction_clean`.
- **get_production_price** — Combines iron/steel, chemical, ammonia/fertilizer, and aluminum price queries, converting units ($/kg→$/Mt, chemical proxy conversion, 1975$→2010$) and mapping to `Price|*` variables. Input: `GCAM_version`. Output: sets global `production_price_clean`.

### Load-Queries Functions — Capacity & Investment

- **get_cf_iea_tmp** — Calibrates capacity factors for existing (base-year) capacity by comparing GCAM's secondary-energy output to IEA reported capacity, computing implied capacity factor by technology (capped at 0.99), checking for mapping mismatches (`handle_warning`) and restricted to USA as reference region. Input: `GCAM_version`. Output: sets global `cf_iea`.
- **get_elec_cf_tmp** — Builds a full technology/region/vintage capacity-factor table combining GCAM's own technology-level assumptions (`cf_gcam`), region-specific overrides for wind/solar (`cf_rgn`), and IEA-calibrated values (`cf_iea`) for vintages not otherwise covered, interpolated/extrapolated across all years present in the project. Input: `GCAM_version`. Output: sets global `elec_cf`.
- **get_elec_capacity_tot** — Computes total installed electricity generation capacity by technology/vintage, converting generation (EJ) to capacity (GW) using `elec_cf` and `conv_EJ_GW`, cleaning technology name variants (cooling/load-segment suffixes) and excluding grid/aggregate regions. Input: `GCAM_version`. Output: sets global `elec_capacity_tot_clean`.
- **get_elec_capacity_add_tmp** — Computes new (vintage-year) electricity capacity additions post-2015 (annualized over the 5-year timestep), converted EJ→GW via `elec_cf`. Input: `GCAM_version`. Output: sets global `elec_capacity_add`.
- **get_refliq_capacity_add_tmp** — Analogous capacity-additions calculation for refined-liquids production technologies (marked TODO for a dedicated cf source; currently reuses `elec_cf`). Input: `GCAM_version`. Output: sets global `refliq_capacity_add`.
- **get_hydrogen_capacity_add_tmp** — Analogous capacity-additions calculation for hydrogen production technologies (also TODO, reuses `elec_cf`). Input: `GCAM_version`. Output: sets global `hydrogen_capacity_add`.
- **get_elec_capacity_add** — Converts `elec_capacity_add` (GW) into final `Capacity Additions|*` reporting variables, with a special case for storage capacity (multiplied by hours/year instead of unit_conv). Input: `GCAM_version`. Output: sets global `elec_capacity_add_clean`.
- **get_elec_capital** — Computes capital (overnight) cost per technology from a static GCAM capital-cost table, converted 1975$→2010$/kW, expanded across regions/scenarios, plus a global-average variant. Input: `GCAM_version`. Output: sets global `elec_capital_clean`.
- **get_elec_investment** — Computes electricity investment as annual capacity additions (GW) × interpolated capital costs ($/kW), converted to billion 2010$. Input: `GCAM_version`. Output: sets global `elec_investment_clean`.
- **get_transmission_invest** — Scales a fixed 2020 external benchmark (McCollum et al. 2018, converted 2015$→2010$) for T&D investment across scenarios/regions proportional to each region's share of total electricity capacity additions. Input: `GCAM_version`. Output: sets global `transmission_invest_clean`.
- **get_resource_investment** — Computes fossil/uranium extraction investment by scaling a benchmark external 2015/2020 investment figure proportionally to each resource's/region's production growth rate relative to a reference region and year, using resource prices to weight initial investment shares. Input: `GCAM_version`. Output: sets global `resource_investment_clean`.
- **get_total_investment** — Sums the aggregated "Investment|Energy Supply" components from resource, electricity, and non-electricity investment into one total, then strips that aggregate line back out of the individual investment tables (to avoid double counting downstream). Input: `GCAM_version`. Output: sets global `total_investment_clean`; also mutates `resource_investment_clean`, `elec_investment_clean`, `nonelec_investment_clean`.
- **get_nonelec_investment** — Computes investment for non-electricity energy-supply sectors (hydrogen, refining, gas processing) from GCAM's native "capital investment demands by tech" query, annualizing over the 5-year timestep and converting 1975$→billion 2010$. Input: `GCAM_version`. Output: sets global `nonelec_investment_clean`.

### Load-Queries Functions — Transport

- **get_transport_sales** — Computes new vehicle sales (million vehicles) by dividing new-vintage transport service output by load factor and annual-travel-per-vehicle (from the UCD dataset mapped to GCAM regions/modes), assuming constant sales over the 5-year period; includes unit-consistency checks on UCD data. Input: `GCAM_version`. Output: sets global `trn_sales_clean`.
- **get_transport_stock** — Computes total vehicle stock (all surviving vintages, not just new sales) analogous to `get_transport_sales`, dividing transport service by load factor and annual travel per vehicle. Input: `GCAM_version`. Output: sets global `trn_stock_clean`.

### Bind-to-Template & Vetting Functions

- **do_bind_results**
  - What it does: Assembles all required reporting variables (from `.myGlobals$variables.global`) into one long dataset, computes World totals (summed from regions, excluding variables already global like prices/shares/rates/yield/food-intake), reshapes to wide (year columns) and joins against the version's reporting `template` to produce the final IAMC-style report; optionally fills in all Tier-1 variables as 0 when missing.
  - Input: `GCAM_version`, `all_tier1` (logical, default FALSE).
  - Output: Sets global `report` (wide data frame: `Model, Scenario, Region, Variable, Unit` plus year columns).

- **do_check_inf**
  - What it does: Checks the final `report` for any infinite values across year columns.
  - Input: `GCAM_version`.
  - Output: A list `list(message, summary)` — "OK" or "ERROR" with the offending rows.

- **do_check_na**
  - What it does: Checks the final `report` for any NA values across year columns.
  - Input: `GCAM_version`.
  - Output: A list `list(message, summary)` — "OK" or "ERROR" with offending rows.

- **do_check_vetting**
  - What it does: Compares computed report values against an external vetting reference dataset (`global_vet_values`) within a tolerance range, flags "ERROR" where the relative difference exceeds the allowed range, and produces/saves a diagnostic bar-chart plot (`output/figure/vetting.tiff`).
  - Input: `GCAM_version`.
  - Output: A list `list(message, summary)`; side effect of saving a plot file.

### Internal / Maintenance Functions

- **update_template**
  - What it does: Regenerates the package's variable reporting template by merging in newly reportable variables (from the current `report`) and flagging/removing variables no longer produced; prints which variables were added/removed, then writes the updated template to both a CSV (`inst/extdata`) and an `.rda` data object.
  - Input: `GCAM_version`.
  - Output: None returned; side effect of writing files (developer/maintenance utility, not intended for end users).

## gcamreport.R

This file contains **no functions**. It is a package-level roxygen documentation stub (`@docType _PACKAGE`) describing the `gcamreport` package as a whole (links to GitHub/webpage). No function definitions are present.

## main.R

The package's primary user-facing entry points: creating/loading GCAM projects, listing available regions/variables/continents, generating the standardized report, and launching the Shiny UI.

- **data_query**
  - What it does: Fetches large "non-CO2 emissions" query results (by region or by subsector) directly from a GCAM database/project in batches of up to 21 emission species at a time (to avoid overly large single queries), building the XML query dynamically from a template, then binds all scenario results into one data frame and cleans column names.
  - Input: `type` — which non-CO2 query ("nonCO2 emissions by region" or "...by subsector"); `db_path`, `db_name`, `prj_name` — database/project identifiers; `scenarios` — scenario names; `desired_regions` — regions to include (default "All"); `GCAM_version`; `queries_nonCO2_file` — optional custom XML query file/list.
  - Output: A data frame with the combined non-CO2 emissions query results across scenarios.

- **load_project**
  - What it does: Loads an existing `rgcam` project file from disk into the global environment, restricts it to the requested scenarios (validating that requested scenarios exist) and, if not all regions are wanted, filters each scenario/query's data down to the desired regions via `filter_loading_regions`.
  - Input: `project_path` — path to project file; `desired_regions` — regions to keep (default "All"); `scenarios` — scenarios to keep (default all); `GCAM_version`.
  - Output: None directly; assigns the loaded/filtered project to the global variable `prj` and `scenarios.global`.

- **create_project**
  - What it does: Creates a new `rgcam` project by connecting to a GCAM database, running the general and non-CO2 XML batch queries for the requested scenarios/regions (optionally restricting to only the queries needed for `desired_variables`), merging results into one project object, filling in a placeholder "CO2 prices" query if absent, saving the project to disk, and exposing it globally.
  - Input: `db_path`, `db_name`, `prj_name` — DB/project identifiers; `scenarios`; `desired_regions`; `desired_variables`; `GCAM_version`; `queries_general_file`, `queries_nonCO2_file` — optional custom query files.
  - Output: None directly; saves the project file to disk and assigns it to global `prj` and `scenarios.global`.

- **load_variable**
  - What it does: Recursively ensures a given internal variable and all of its declared dependencies are loaded (computed) exactly once, by looking up and calling each variable's associated loader function (`var$fun`) with the appropriate `GCAM_version`/`GWP_version` arguments based on its formal parameters, then records it as loaded.
  - Input: `var` — a row/record describing the variable (name, dependencies, associated function); `GCAM_version`; `GWP_version`.
  - Output: None directly (side-effecting); loads the variable's data into the environment and appends its name to the global `loaded_internal_variables.global`.

- **load_query**
  - What it does: Recursively collects the list of GCAM queries needed to compute a given internal variable, first gathering the queries needed for all of its dependencies, then appending its own required queries.
  - Input: `var` — a variable's metadata record (with `dependencies` and `queries` fields); `base_data` — full variable/query metadata table; `final_queries` — accumulator vector of query names collected so far.
  - Output: A character vector of all query names required (including those from dependencies).

- **available_regions**
  - What it does: Returns (and optionally prints) the list of all region names available for reporting for a given GCAM version, collapsing continent-level "World" rows into a single "World" label.
  - Input: `print` — logical, whether to print each region (default TRUE); `GCAM_version`.
  - Output: An invisible character vector of unique available region names.

- **available_continents**
  - What it does: Returns (and optionally prints) the list of all continent/region-group names available for reporting for a given GCAM version.
  - Input: `print` — logical (default TRUE); `GCAM_version`.
  - Output: An invisible character vector of available continent/region-group names.

- **available_variables**
  - What it does: Returns (and optionally prints) the list of all standardized IAMC variable names available for reporting for a given GCAM version, based on the internal reporting template.
  - Input: `print` — logical (default TRUE); `GCAM_version`.
  - Output: An invisible character vector of available variable names.

- **generate_report**
  - What it does: The main package entry point/orchestrator. Validates all user inputs (GCAM/GWP version, regions, continents, variables including `*` wildcard expansion and inverse selection), loads or creates the GCAM project, determines the available/final reporting years, builds the set of required internal variables and their dependency/query metadata, loads every required variable via `load_variable`, binds all results into the final standardized report (`do_bind_results`), saves it as RData/CSV/XLSX, runs Inf/NA/historical-vetting checks (`do_check_inf`, `do_check_na`, `do_check_vetting`) and prints a vetting summary, cleans up temporary globals, and optionally launches the Shiny UI.
  - Input: `db_path`, `db_name`, `prj_name`, `scenarios`, `final_year` (default 2100), `desired_variables`, `inverse_desired_variables`, `ignore`, `desired_regions`, `desired_continents`, `save_output`, `output_file`, `launch_ui`, `GCAM_version`, `GWP_version`, `queries_general_file`, `queries_nonCO2_file`, `interactive`, `all_tier1`.
  - Output: None directly (side-effecting); writes RData/CSV/XLSX report files to disk, sets the global `vetting_summary`, and (if `launch_ui = TRUE`) launches the Shiny app.

- **launch_gcamreport_ui**
  - What it does: Launches the Shiny interactive UI for exploring a standardized gcamreport dataset — loads the data (from a path or an in-memory object), splits the `Variable` column into hierarchical sub-columns, determines the available reporting years, builds the nested region/variable selector trees, and starts the Shiny app.
  - Input: `data_path` — optional path to an RData file; `data` — optional in-memory data frame/list (exactly one of the two must be supplied); `GCAM_version`.
  - Output: None directly; sets several globals (`sdata`, `available_years`, `cols.global`, `tree_vars`, `tree_reg`, `all_varss`) and starts the Shiny application (`shiny::runApp`).

## zzz.R

Package-load hook.

- **.onLoad**
  - What it does: Standard R package load hook, automatically called by R when the `gcamreport` namespace is loaded. It initializes the package's private mutable-state environment (`.myGlobals`) by resetting its fields (`ignore.global`, `interactive.global`, `variables.global`, `GCAM_version`) to `NULL`, providing a clean slate for each new R session.
  - Input: `libname`, `pkgname` — standard `.onLoad` arguments supplied by R (library path and package name); not called directly by users.
  - Output: None (side effect only); initializes `.myGlobals` environment fields.
