# AGENTS.md

This is a small shell-script project that validates METS files against the
Schematron rules of the Deutsche Digitale Bibliothek (DDB), using Saxon-HE.

## Repository layout

Tracked in git:

- `validate-mets` — main shell script (POSIX sh)
- `install.sh` — downloads all external dependencies (verifies each download)
- `catalog.xml` — XML catalog mapping the XLink schema URL used by `mets.xsd` to the local `xlink.xsd`
- `README.md`, `LICENSE` (Apache 2.0)

**Not tracked** (gitignored, downloaded by `install.sh` — do not commit these):

- `ddb_validierung_mets-mods-ap-digitalisierte-medien.xsl` — DDB Schematron rules for books/other media
- `ddb_validierung_mets-mods-ap-digitalisierte-zeitungen.xsl` — DDB Schematron rules for newspapers
- `format-svrl-output-to-text.xsl` — formats SVRL output as a human-readable text report
- `SaxonHE/` — Saxon-HE 12.3 JARs (pinned version, referenced as `saxon-he-12.3.jar` in `validate-mets`)
- `mets.xsd` — METS XSD 1.12.1
- `xlink.xsd` — XLink schema imported by `mets.xsd`

## Setup

- System packages (Debian): `sudo apt install default-jre-headless libxml2-utils xsltproc`
- Then run `./install.sh`

## Usage / testing

```
./validate-mets [-script] [METSFILE ...]
```

- Default: human-readable textual report (SVRL piped through `format-svrl-output-to-text.xsl`).
- `--script`: raw SVRL XML on stdout, for further processing.
- Test files:
  - Positive test (passes XSD, runs Schematron): the DDB example files,
    e.g. "METS/MODS Datei einer einteiligen Monographie" (page 48103891)
    under https://deutsche-digitale-bibliothek.atlassian.net/wiki/spaces/DFD/pages/48103804/Beispiele+DDB+METS+MODS
    — extract the XML from the page's `<pre>` block (Confluence REST:
    `/wiki/rest/api/content/48103891?expand=body.view`).
  - Negative test (fails XSD, gets skipped):
    `wget https://tudigit.ulb.tu-darmstadt.de/mets/43-A-1634.xml` — it uses
    `MDTYPE="IIIF"`, which is not in the METS 1.12.1 enumeration.
- METS notes: `mets:metsHdr` is optional in the schema and unchecked by the
  DDB rules, but DDB delivered files conventionally contain it with a
  `mets:agent ROLE="CREATOR" TYPE="ORGANIZATION"` whose `mets:name` is the
  delivering institution's ISIL (mandatory for DDB data providers).

## How validation works

For each METS file given on the command line, `validate-mets`:

1. Runs XSD validation with `XML_CATALOG_FILES=$BASE/catalog.xml xmllint --quiet --noout --schema $BASE/mets.xsd` (`--quiet` suppresses the "validates" success line); the catalog resolves the XLink schema import of `mets.xsd` from the local `xlink.xsd` instead of the network. If validation fails, the file is skipped for Schematron validation.
2. Detects newspapers via `grep -q 'mods:detail.*type=.issue'`; newspapers use the `...-zeitungen.xsl` ruleset, everything else the `...-medien.xsl` ruleset.
3. Runs the selected Schematron stylesheet with Saxon-HE.

## Upstream sources

The downloaded files come from upstream repositories; **never hand-edit**
the `.xsl` files or JARs — update them by changing the download URLs in
`install.sh` (and the Saxon jar name in `validate-mets` if the version changes):

- DDB rules: https://github.com/Deutsche-Digitale-Bibliothek/ddb-metadata-schematron-validation
- SVRL-to-text XSL: https://github.com/CSIRO-enviro-informatics/validation-svc-base
- Saxon-HE: https://github.com/Saxonica/Saxon-HE
- METS XSD 1.12.1: https://github.com/mets/METS-schema (`version1121/mets.xsd`)
- XLink XSD: `http://www.loc.gov/standards/xlink/xlink.xsd`, only via
  Internet Archive snapshots (https://web.archive.org) because loc.gov is
  behind a Cloudflare bot challenge

`install.sh` verifies every download (HTTP status + a content marker) and
fails without leaving a broken file behind.

## Pitfalls

- `http://www.loc.gov` (both `mets.xsd` and the XLink schema) sits behind a
  Cloudflare bot challenge that returns a 403 HTML page to plain `curl`.
  `install.sh` therefore fetches `mets.xsd` from the METS schema repo on
  GitHub and `xlink.xsd` from Internet Archive snapshots. If validation
  fails for *every* file, check that `mets.xsd`/`xlink.xsd` start with XML
  (not `<!DOCTYPE html>`) and that `catalog.xml` still matches the import
  URL in `mets.xsd`.
- The Saxon JAR version is hardcoded in both `install.sh` and `validate-mets`.

## Conventions

- Shell scripts are POSIX `sh`; comments in `validate-mets` are in German — keep that style when extending the script.
- Commit messages are short and imperative (e.g. "Update validation script").
- Per the user's global rules, every commit message must include an
  `Assisted-by: OpenCode / <model name> (<vendor>)` line (vendor of Qwen models: Alibaba Cloud)
  followed by a `Signed-off-by:` line.
