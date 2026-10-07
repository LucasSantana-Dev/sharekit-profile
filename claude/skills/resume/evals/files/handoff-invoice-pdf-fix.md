# Handoff: invoice PDF font fallback
## Active Objective
Fix missing glyphs in invoice PDFs for pt-BR accents.
## Blockers
- none
## ⚡ IMPLEMENT THIS
1. Register NotoSans fallback in src/pdf/fonts.ts:27
2. Snapshot test for "Cobrança" in tests/pdf.test.ts:60
