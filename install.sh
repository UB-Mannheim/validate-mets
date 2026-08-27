#!/bin/sh

# Download the external dependencies that validate-mets needs.
#
# Every download is verified before it is saved, so a failed or bot-blocked
# fetch never silently leaves a broken file behind. On any failure the script
# prints an error and exits non-zero.

set -u

# fetch <url> <dest> <marker>
# Download <url> to a temp file. Only move it onto <dest> if the transfer
# succeeded and the file contains <marker>. The marker guard catches HTML
# error / bot-challenge pages that are returned with a success status.
fetch() {
  url=$1; dest=$2; marker=$3
  tmp=$(mktemp) || return 1
  if ! curl -sfL --max-time 60 "$url" -o "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: download failed: $url" >&2
    return 1
  fi
  if [ -n "$marker" ] && ! grep -qF "$marker" "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: $url did not return the expected content (missing '$marker'); not saving $dest" >&2
    return 1
  fi
  mv "$tmp" "$dest"
  chmod 644 "$dest"
}

# Get Schematron validation files.
fetch "https://raw.githubusercontent.com/Deutsche-Digitale-Bibliothek/ddb-metadata-schematron-validation/main/mets-mods-ap-digitalisierte-medien/ddb_validierung_mets-mods-ap-digitalisierte-medien.xsl" \
  ddb_validierung_mets-mods-ap-digitalisierte-medien.xsl '<xsl:stylesheet' || exit 1
fetch "https://raw.githubusercontent.com/Deutsche-Digitale-Bibliothek/ddb-metadata-schematron-validation/main/mets-mods-ap-digitalisierte-zeitungen/ddb_validierung_mets-mods-ap-digitalisierte-zeitungen.xsl" \
  ddb_validierung_mets-mods-ap-digitalisierte-zeitungen.xsl '<xsl:stylesheet' || exit 1

# Get XSL for text output.
fetch "https://raw.githubusercontent.com/CSIRO-enviro-informatics/validation-svc-base/master/format/format-svrl-output-to-text.xsl" \
  format-svrl-output-to-text.xsl '<xsl:stylesheet' || exit 1

# Get Saxon.
fetch "https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-3/SaxonHE12-3J.zip" \
  SaxonHE12-3J.zip '' || exit 1
# Sanity check: the download must be a zip archive.
if [ "$(head -c 2 SaxonHE12-3J.zip)" != "PK" ]; then
  echo "ERROR: SaxonHE12-3J.zip is not a valid zip archive" >&2
  rm -f SaxonHE12-3J.zip
  exit 1
fi
unzip -o SaxonHE12-3J.zip -d SaxonHE || exit 1
rm SaxonHE12-3J.zip

# Get mets.xsd.
# The canonical file lives at loc.gov, which is behind a Cloudflare bot
# challenge that plain curl cannot pass (it returns a 403 challenge page).
# Use the official METS schema repository on GitHub, and fall back to
# Internet Archive snapshots of the loc.gov file. The marker check below
# rejects any challenge / error page.
mets_marker='targetNamespace="http://www.loc.gov/METS/"'
fetch "https://raw.githubusercontent.com/mets/METS-schema/main/version1121/mets.xsd" mets.xsd "$mets_marker" ||
fetch "https://web.archive.org/web/http://www.loc.gov/standards/mets/mets.xsd" mets.xsd "$mets_marker" ||
fetch "https://web.archive.org/web/20260825140704id_/http://www.loc.gov/standards/mets/mets.xsd" mets.xsd "$mets_marker" ||
{ echo "ERROR: could not download a valid mets.xsd from any source" >&2; exit 1; }

# Get xlink.xsd (imported by mets.xsd; resolved locally via catalog.xml).
# Only reliably hosted at loc.gov, so use Internet Archive snapshots.
xlink_marker='targetNamespace="http://www.w3.org/1999/xlink"'
fetch "https://web.archive.org/web/http://www.loc.gov/standards/xlink/xlink.xsd" xlink.xsd "$xlink_marker" ||
fetch "https://web.archive.org/web/20260825140710id_/http://www.loc.gov/standards/xlink/xlink.xsd" xlink.xsd "$xlink_marker" ||
{ echo "ERROR: could not download a valid xlink.xsd from any source" >&2; exit 1; }
