# Structural models

Read by repos that estimate a structural model, in addition to `research.md`. Defaults, not rules.

- **Fit and economics.** The model must fit the moments that matter and keep the economics the paper is about. The two often conflict. Take the trade-off to the user (`research.md`, Judgment): choose by what the research question needs, and say what the chosen model gets wrong; every model is wrong in some way. The plan and STRATEGY adjust.
- **Check each block before real data.** Check a new model block against an independent reference and recover its parameters from data simulated from the model.
- **Moments and counterfactuals.** Use static or reduced-form work to learn which moments inform which parameters; counterfactuals come from the estimated model.
- **Data first.** Tabulate the data that define a block before designing it.
- **Build, then tune.** Get an end-to-end estimate at baseline settings before tuning approximations, and stop speeding up code once an estimate fits the time budget.
- **Framing.** When the fit or the needed heterogeneity changes, revisit the framing in STRATEGY.
