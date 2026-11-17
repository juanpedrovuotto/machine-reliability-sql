# Machine Reliability Analysis – Contoso Retail (2007–2009)

SQL Server analysis of equipment failures across a retail chain: **MTBF**, **MTTR** and **availability** by machine type, to decide where maintenance efforts should focus.

🇪🇸 [Versión en español](README_es.md)

**Author:** Juan · **Tools:** SQL Server, SSMS · **Database:** ContosoRetailDW (Microsoft)

---

## Questions

1. How often does each machine type fail? → **MTBF** (mean time between failures)
2. How long does it take to repair? → **MTTR** (mean time to repair)
3. What percentage of the time was it running? → **Availability**
4. Where should maintenance focus?

## Data

| Table | Content |
|---|---|
| `FactITSLA` | One row per failure: machine, store, failure type, start, end and downtime minutes |
| `DimMachine` | Machine catalog: type, service start date and decommission date |
| `DimOutage` | Failure type catalog |

- **4,925 failures**, from 01/01/2007 to 12/31/2009 (3 full years).
- **7,816 machines** across 9 types; **2,553 (33%)** had at least one failure.

## Data validation

Before calculating, the following was checked:

- **`DownTime` unit:** the column doesn't state its unit. It was compared with the difference in minutes between each failure's start and end: it matches in 100% of rows, with no empty dates → it is in **minutes**.
- **JOIN integrity:** failures by machine type add up to 4,925, the same as the `FactITSLA` total → no failures are lost when joining tables.
- **Decommissions:** no machine has an empty decommission date, but the earliest is June 2010 → no machine was decommissioned during the period.
- **Late starts:** 221 machines started service after 01/01/2007 → only their hours from their start date are counted.

## Methodology

- **Service hours** per machine: from 01/01/2007 (or its service start date, if later) to 01/01/2010. Full period = 26,304 hours.
- **MTBF by type** = service hours of **all** machines of that type ÷ failures of that type. It is calculated at group level so that machines that never failed still add their hours; otherwise MTBF would be underestimated.
- **MTTR** = downtime minutes ÷ failures.
- **Availability** = (service hours − downtime hours) ÷ service hours.

## Results

| Type | Machines | Failures | MTBF (h) | MTTR (min) | Downtime hours | % of downtime | Availability |
|---|---:|---:|---:|---:|---:|---:|---:|
| POS01 | 2,679 | 3,495 | 20,163 | 72.5 | 4,226 | 64% | 99.9940% |
| POS02 | 102 | 781 | 2,666 | 79.7 | 1,038 | 16% | 99.9502% |
| HUB01 | 460 | 90 | 134,443 | 535.4 | 803 | 12% | 99.9934% |
| WSR01 | 3,040 | 185 | 432,239 | 49.8 | 154 | 2% | 99.9998% |
| WSR02 | 1,060 | 155 | 179,885 | 54.4 | 141 | 2% | 99.9995% |
| RUT01 | 10 | 105 | 2,505 | 65.0 | 114 | 2% | 99.9568% |
| POS03 | 73 | 33 | 25,100 | 141.1 | 78 | 1% | 99.9906% |
| MSR01 | 346 | 80 | 113,765 | 44.3 | 59 | 1% | 99.9994% |
| POS04 | 46 | 1 | — | 22.0 | 0 | 0% | 99.9998% |

**Total:** 6,612 hours of machine downtime over 3 years. Overall MTTR: 80.6 minutes.

## Findings

**1. POS02 and RUT01 are the least reliable types.**
Each machine fails on average every ~2,500–2,700 hours, about **3.5 months**. A POS01 fails every ~20,000 hours (about 2.3 years): POS02 and RUT01 fail **about 8 times more often**. These are **reliability** problems (low MTBF), not repair problems: their MTTR is normal.

**2. POS01 accounts for 64% of downtime because of volume, not poor performance.**
It has the most failures (3,495) because there are 2,679 machines, but per machine its MTBF and MTTR are reasonable. Looking only at total downtime leads to the wrong conclusion: separating MTBF and MTTR shows where the real problems are.

**3. HUB01 has a repair problem, not a failure problem.**
It rarely fails (MTBF of 134,443 h), but each failure takes **535 minutes, almost 9 hours**: 6.6 times the average. If HUB01 is network equipment, each failure may leave other machines in the store without service, and the real impact would be greater than its own 803 hours.

**4. Availability is high for every type (> 99.95%) and is not enough to compare them.**
Differences between types show up in MTBF and MTTR, not in availability. That's why both KPIs should be tracked separately.

**5. Workstations (WSR01, WSR02) and MSR01 need no action.**
High MTBF, low MTTR and only 5% of downtime between the three.

## Failure type analysis

**6. Pareto: 4 failure types cause two thirds of downtime.**
Out of 54 failure types, almost all are resolved in 25–40 minutes. Four stand out:

| Failure type | Failures | MTTR (min) | Where it appears |
|---|---:|---:|---|
| Server | 131 | 732 | 6 machine types (mostly POS01 and POS02) |
| POS | 195 | 598 | Only POS terminals (POS01, POS02, POS03) |
| Hub | 90 | 535 | Only HUB01 |
| Router | 2 | 526 | Only RUT01 |

They are **8.5% of failures and 66% of downtime**. Reducing repair time for these 4 types has far more impact than improving the other 50.

**7. POS01's "normal" MTTR hides very long failures.**
Of POS01's 3,495 failures, only 248 (7%) are POS or Server type, but they last 9–13 hours each and generate **62% of its downtime hours**. The rest are resolved in about half an hour.

**8. HUB01 has only one way of failing.**
All 90 of its failures are of type "Hub", with the same 535-minute MTTR. The problem isn't varied: it's a repair that always takes about 9 hours.

**9. Hypothesis tested and rejected: server failures are not shared outages.**
Since "Server" failures appear across 6 machine types, the hypothesis was that a central server outage brought down several machines at once. If so, there would be multiple Server failures in the same store at the same time. Result: 0 cases with the same start and end time, and only 1 case (2 machines) on the same day, out of 131 failures. **Server failures are isolated**: they affect one machine at a time.

## Recommendations

| Priority | Type | Problem | Action |
|---|---|---|---|
| 1 | POS02, RUT01 | Fail very often (low MTBF) | Preventive maintenance; analyze failure causes; evaluate replacing the model |
| 2 | HUB01 | Very slow repairs (high MTTR) | Spare parts in store, assigned technician, standard repair procedure |
| 3 | POS03 | MTTR twice the average | Review the repair process |
| 4 | POS01 | Few but very long failures (POS and Server) | Target those two failure types: they account for 62% of its downtime |
| 5 | Server failures (all machines) | 12-hour MTTR, the highest | Review the server repair procedure; since failures are isolated, the fix lies in each device, not in a central server |

## Limitations

- **POS04** has a single failure: its MTBF and MTTR are not representative.
- **RUT01** has only 10 machines: the result is reliable for those machines, but the sample is small.
- Availability is calculated over 24 h/day. If stores operate fewer hours, availability during business hours would be somewhat lower.
- ContosoRetailDW is a Microsoft demo database: the data is simulated.

## How to reproduce

1. Restore the **ContosoRetailDW** database in SQL Server.
2. Open `proyecto_final_MTBF_MTTR.sql` in SSMS and run it in full.
   - Section 1: data validation
   - Section 2: MTTR by type
   - Section 3: final table with MTBF, MTTR and availability
   - Section 4: failure type analysis and hypothesis test

*(Script comments are in Spanish.)*
