# Zotero fixes still to do

These corrections were applied directly to `C:/AIMS/tmp/ADRIA-mod.bib` so the manuscript
renders correctly today. **They are not in Zotero.** Re-exporting the library will undo
all of them. This file lists what to change in Zotero so the fix becomes permanent.

Generated 2026-08-06. Backups: `ADRIA-mod.bib.backup` (pre-author),
`ADRIA-mod.bib.backup2` (pre-journal).

---

## 1. Author fields containing "et al."

Science and Science Advances both forbid `et al.` in the reference list — the full author
list is required. Zotero field: **Author**. Full lists retrieved from Crossref by DOI.

12 entries (7 cited in this paper):

### ✅ cited — `baskettm.et.al.SymbiontDiversityMay2009`
*Symbiont diversity may help coral reefs survive moderate climate change*

```
was : Baskett, M. et. al.
now : Baskett, Marissa L. and Gaines, Steven D. and Nisbet, Roger M.
```

### ✅ cited — `feldtRobertfeldtBlackBoxOptimjl2023`
*robertfeldt/BlackBoxOptim.jl*

```
was : Feldt, Robert and et al
now : Feldt, Robert and Stukalov, Alexey and Rackauckas, Christopher
```

### ✅ cited — `hughest.p.kerryj.t.bairda.h.etal.GlobalWarmingTransforms2018`
*Global warming transforms coral reef assemblages*

```
was : Hughes, T.P., Kerry, J.T., Baird, A.H. et al.
now : Hughes, Terry P. and Kerry, James T. and Baird, Andrew H. and Connolly, Sean R. and Dietzel, Andreas and Eakin, C. Mark and Heron, Scott F. and Hoey, Andrew S. and Hoogenboom, Mia O. and Liu, Gang and McWilliam, Michael J. and Pears, Rachel J. and Pratchett, Morgan S. and Skirving, William J. and Stella, Jessica S. and Torda, Gergely
```

### ✅ cited — `lewisd.m.et.al.PredictingShiftsDemography2022`
*Predicting shifts in demography of Orbicella franksi following simulated disturbance and restoration*

```
was : Lewis, D.M. et. al.
now : Lewis, Dakota M. and Vardi, Tali and Maher, Rebecca L. and Correa, Adrienne M.S. and Cook, Geoffrey S.
```

### ✅ cited — `mcdonaldr.a.et.al.ZigzagPersistenceCoral2023`
*Zigzag persistence for coral reef resilience using a stochastic spatial model*

```
was : McDonald R.A., et. al.
now : McDonald, R. A. and Neuhausler, R. and Robinson, M. and Larsen, L. G. and Harrington, H. A. and Bruna, M.
```

### ✅ cited — `vanwoesikrobertet.al.PredictingCoralDynamics2018`
*Predicting coral dynamics through climate change*

```
was : van Woesik, Robert et. al.
now : Woesik, Robert van and Köksal, Semen and Ünal, Arzu and Cacciapaglia, Chris W. and Randall, Carly J.
```

### ✅ cited — `zhaom.et.al.ModelSuggestsPotential2016`
*Model suggests potential for Porites coral population recovery after removal of anthropogenic distur*

```
was : Zhao, M. et. al.
now : Zhao, Meixia and Riegl, Bernhard and Yu, Kefu and Shi, Qi and Zhang, Qiaomin and Liu, Guohui and Yang, Hongqiang and Yan, Hongqiang
```

### not cited — `hughest.barnesm.bellwoodd.etal.CoralReefsAnthropocene2017`
*Coral reefs in the Anthropocene*

```
was : Hughes, T., Barnes, M., Bellwood, D. et al.
now : Hughes, Terry P. and Barnes, Michele L. and Bellwood, David R. and Cinner, Joshua E. and Cumming, Graeme S. and Jackson, Jeremy B. C. and Kleypas, Joanie and van de Leemput, Ingrid A. and Lough, Janice M. and Morrison, Tiffany H. and Palumbi, Stephen R. and van Nes, Egbert H. and Scheffer, Marten
```

### not cited — `kleypasj.et.al.DesigningBlueprintCoral2021`
*Designing a blueprint for coral reef survival*

```
was : Kleypas, J. et. al.
now : Kleypas, Joan and Allemand, Denis and Anthony, Ken and Baker, Andrew C. and Beck, Michael W. and Hale, Lynne Zeitlin and Hilmi, Nathalie and Hoegh-Guldberg, Ove and Hughes, Terry and Kaufman, Les and Kayanne, Hajime and Magnan, Alexandre K. and Mcleod, Elizabeth and Mumby, Peter and Palumbi, Stephen and Richmond, Robert H. and Rinkevich, Baruch and Steneck, Robert S. and Voolstra, Christian R. and Wachenfeld, David and Gattuso, Jean-Pierre
```

### not cited — `ortizj.c.et.al.GlobalDisparityEcological2014`
*Global disparity in the ecological benefits of reducing carbon emissions for coral reefs*

```
was : Ortiz, J.C. et. al.
now : Ortiz, Juan Carlos and Bozec, Yves-Marie and Wolff, Nicholas H. and Doropoulos, Christopher and Mumby, Peter J.
```

### not cited — `vanwoesikr.et.al.CoralbleachingResponsesClimate2022`
*Coral-bleaching responses to climate change across biological scales*

```
was : van Woesik, R. et. al.
now : van Woesik, Robert and Shlesinger, Tom and Grottoli, Andréa G. and Toonen, Rob J. and Vega Thurber, Rebecca and Warner, Mark E. and Marie Hulver, Ann and Chapron, Leila and McLachlan, Rowan H. and Albright, Rebecca and Crandall, Eric and DeCarlo, Thomas M. and Donovan, Mary K. and Eirin‐Lopez, Jose and Harrison, Hugo B. and Heron, Scott F. and Huang, Danwei and Humanes, Adriana and Krueger, Thomas and Madin, Joshua S. and Manzello, Derek and McManus, Lisa C. and Matz, Mikhail and Muller, Erinn M. and Rodriguez‐Lanetty, Mauricio and Vega‐Rodriguez, Maria and Voolstra, Christian R. and Zaneveld, Jesse
```

### not cited — `wolffn.h.et.al.VulnerabilityGreatBarrier2018`
*Vulnerability of the Great Barrier Reef to climate change and local pressures*

```
was : Wolff, N.H. et. al.
now : Wolff, Nicholas H. and Mumby, Peter J. and Devlin, Michelle and Anthony, Kenneth R. N.
```

> **Note on `feldtRobertfeldtBlackBoxOptimjl2023`** — BlackBoxOptim.jl declares no authors in
> `Project.toml` and has no `CITATION.bib`, so the three substantive GitHub contributors were
> used (Feldt 641 commits, Stukalov 497, Rackauckas 33). Everyone else has =<5 commits, plus
> two bots. This is a judgement call, not a lookup — revisit if you disagree.

---

## 2. Journal names -> Science-style abbreviations

Zotero field: **Journal Abbr**. Filling it there is the durable fix; Zotero can auto-populate
it in bulk, but check the output — it produces MEDLINE style (`Sci Rep`) whereas Science wants
periods (`Sci. Rep.`).

76 entries changed, covering these distinct journals:

| Journal (as exported) | Should be | entries | cited |
|---|---|---:|---:|
| American Naturalist | **Am. Nat.** | 1 | 1 |
| Biological Conservation | **Biol. Conserv.** | 2 | 1 |
| Ecological Applications | **Ecol. Appl.** | 3 | 2 |
| Ecological Indicators | **Ecol. Indic.** | 2 | 1 |
| Ecological Modelling | **Ecol. Modell.** | 4 | 2 |
| Ecological Monographs | **Ecol. Monogr.** | 1 | 1 |
| Ecology and Evolution | **Ecol. Evol.** | 1 | 1 |
| Environmental Modelling \& Software | **Environ. Model. Softw.** | 8 | 4 |
| Global Change Biology | **Glob. Change Biol.** | 10 | 4 |
| Global Ecol Biogeogr | **Glob. Ecol. Biogeogr.** | 3 | 1 |
| Global Environmental Change | **Glob. Environ. Change** | 1 | 1 |
| J of Evolutionary Biology | **J. Evol. Biol.** | 1 | 1 |
| J. Environ. Manage.; (United States) | **J. Environ. Manage.** | 1 | 1 |
| Journal of Evolutionary Biology | **J. Evol. Biol.** | 1 | 1 |
| Journal of the Royal Society, Interface | **J. R. Soc. Interface** | 1 | 1 |
| Marine Pollution Bulletin | **Mar. Pollut. Bull.** | 1 | 1 |
| Methods in Ecology and Evolution | **Methods Ecol. Evol.** | 1 | 1 |
| Molecular Ecology | **Mol. Ecol.** | 2 | 2 |
| Nat Commun | **Nat. Commun.** | 3 | 2 |
| Nat Ecol Evol | **Nat. Ecol. Evol.** | 3 | 2 |
| Ocean Modelling | **Ocean Modell.** | 1 | 1 |
| PLOS Computational Biology | **PLoS Comput. Biol.** | 1 | 1 |
| Reliability Engineering \& System Safety | **Reliab. Eng. Syst. Saf.** | 1 | 1 |
| Remote Sensing | **Remote Sens.** | 2 | 1 |
| SIAM/ASA J. Uncertainty Quantification | **SIAM/ASA J. Uncertain. Quantif.** | 1 | 1 |
| Sci Rep | **Sci. Rep.** | 10 | 3 |
| Science Advances | **Sci. Adv.** | 3 | 2 |
| Science of The Total Environment | **Sci. Total Environ.** | 1 | 1 |
| Scientific Reports | **Sci. Rep.** | 3 | 2 |
| Technological Forecasting and Social Change | **Technol. Forecast. Soc. Change** | 2 | 2 |
| Water Sci Technol | **Water Sci. Technol.** | 1 | 1 |

### Malformed values worth fixing at source

| Problem | Entry value | Fixed to |
|---|---|---|
| Stray country suffix | `J. Environ. Manage.; (United States)` | `J. Environ. Manage.` |
| Escaped ampersand | `Environmental Modelling \& Software` | `Environ. Model. Softw.` |
| Escaped ampersand | `Reliability Engineering \& System Safety` | `Reliab. Eng. Syst. Saf.` |
| Same journal, two spellings | `J of Evolutionary Biology` + `Journal of Evolutionary Biology` | both -> `J. Evol. Biol.` |

---

## 3. After fixing Zotero

```shell
# re-export the library over C:/AIMS/tmp/ADRIA-mod.bib, then:
python paper/make-references-bib.py
quarto render paper/paper.qmd
```

Then confirm nothing regressed:

- no `et al.` in the rendered bibliography
- journal names abbreviated **with periods**
- still 81 entries