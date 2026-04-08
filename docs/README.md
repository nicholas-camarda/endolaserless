# Docs Mirrors

The PNG files in this folder are lightweight display mirrors used by the repo README.

They are not canonical analysis outputs and should not be edited by hand as if they were source figures.

Traceability rules:

- Treat runtime outputs and subproject archives as canonical sources for regenerated figures or tables.
- Use repo `docs/*.png` only for lightweight publication-display mirrors.
- When a figure is refreshed, record the runtime or archive artifact it came from in the relevant README, OpenSpec change, or manuscript workflow notes.

Current state:

- The existing PNG mirrors correspond to the NPI manuscript track.
- Neovascularization published mirrors should be copied from runtime through `scripts/neovascularization_project.R`, which excludes transient files such as logs, caches, temp files, `.DS_Store`, and `output_log.txt`.
