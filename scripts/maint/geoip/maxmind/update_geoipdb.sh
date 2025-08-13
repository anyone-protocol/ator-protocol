#!/bin/bash
set -e

if [ -z "$MAXMIND_LICENSE_KEY" ]; then
  echo " MAXMIND_LICENSE_KEY env variable is not set"
  exit 1
fi

if [ -z "$MAXMIND_ACCOUNT_ID" ]; then
  echo " MAXMIND_ACCOUNT_ID env variable is not set"
  exit 1
fi

LICENSE_KEY="$MAXMIND_LICENSE_KEY"
ACCOUNT_ID="$MAXMIND_ACCOUNT_ID"
ZIP_FILE="geoip.zip"
CSV_DIR="geoip-csv"
OUT_DIR="../../../../src/config"

cleanup() {
  echo "Cleaning up..."
  rm -f "$ZIP_FILE"
  rm -rf "$CSV_DIR"
  rm -f geoip geoip6
}
trap cleanup EXIT

echo "Downloading GeoLite2 CSV..."
curl -L -o "$ZIP_FILE" -u "$ACCOUNT_ID:$LICENSE_KEY" \
  "https://download.maxmind.com/geoip/databases/GeoLite2-Country-CSV/download?suffix=zip"

echo "Extracting CSV files..."
mkdir -p "$CSV_DIR"
unzip -j "$ZIP_FILE" '*.csv' -d "$CSV_DIR"
ls -lh "$CSV_DIR"

echo "Running geoipgen Rust converter..."
cargo run --release --manifest-path=geoipgen/Cargo.toml

echo "Moving output files to $OUT_DIR..."
mkdir -p "$OUT_DIR"
mv geoip geoip6 "$OUT_DIR/"

echo "Done!"