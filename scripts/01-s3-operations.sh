#!/usr/bin/env bash
# ══ 01 — Amazon S3 Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON S3 — Simple Storage Service" "📦"
check_floci
BUCKET="demo-s3-$(date +%s)"
VBUCKET="demo-versioned"
TMP=$(mktemp -d)

section_start "1. Create Buckets"
$AWS_CMD s3 mb "s3://${BUCKET}" && log_success "Bucket: ${BUCKET}"
$AWS_CMD s3 mb "s3://${VBUCKET}" 2>/dev/null || true
$AWS_CMD s3api put-bucket-versioning --bucket "${VBUCKET}" --versioning-configuration Status=Enabled
log_success "Versioned bucket: ${VBUCKET}"
section_end

section_start "2. List Buckets"
$AWS_CMD s3 ls
section_end

section_start "3. Upload Objects"
echo '{"msg":"Hello from Floci!","ts":"'$(date -Iseconds)'"}' > "${TMP}/data.json"
echo "id,name,email\n1,Alice,alice@ex.com\n2,Bob,bob@ex.com" > "${TMP}/users.csv"
$AWS_CMD s3 cp "${TMP}/data.json" "s3://${BUCKET}/data/data.json" && log_success "Uploaded data.json"
$AWS_CMD s3 cp "${TMP}/users.csv" "s3://${BUCKET}/data/users.csv" --content-type "text/csv" && log_success "Uploaded users.csv"
section_end

section_start "4. List Objects"
$AWS_CMD s3 ls "s3://${BUCKET}/" --recursive --human-readable
section_end

section_start "5. Download"
$AWS_CMD s3 cp "s3://${BUCKET}/data/data.json" "${TMP}/dl.json" && log_success "Downloaded"
log_detail "Content: $(cat "${TMP}/dl.json")"
section_end

section_start "6. Copy & Move"
$AWS_CMD s3 cp "s3://${BUCKET}/data/data.json" "s3://${BUCKET}/backup/data.json" && log_success "Copied"
section_end

section_start "7. Presigned URL"
URL=$($AWS_CMD s3 presign "s3://${BUCKET}/data/data.json" --expires-in 3600)
log_success "URL: ${URL}"
section_end

section_start "8. Versioning"
echo '{"v":1}' > "${TMP}/ver.json"
$AWS_CMD s3 cp "${TMP}/ver.json" "s3://${VBUCKET}/ver.json" && log_success "v1 uploaded"
echo '{"v":2}' > "${TMP}/ver.json"
$AWS_CMD s3 cp "${TMP}/ver.json" "s3://${VBUCKET}/ver.json" && log_success "v2 uploaded"
$AWS_CMD s3api list-object-versions --bucket "${VBUCKET}" --prefix "ver.json" --output table 2>/dev/null || true
section_end

section_start "9. Cleanup"
$AWS_CMD s3 rb "s3://${BUCKET}" --force && log_success "Deleted: ${BUCKET}"
rm -rf "${TMP}"
section_end

summary_box "S3 Complete" "Buckets, upload/download, versioning, presign"
