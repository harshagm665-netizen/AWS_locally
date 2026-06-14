#!/usr/bin/env bash
# ==============================================================================
#  01 — Amazon S3 Operations
# ==============================================================================
#  Demonstrates the full S3 lifecycle:
#    • Create buckets (with versioning, encryption, lifecycle policies)
#    • Upload / download objects
#    • Presigned URLs
#    • Bucket policies
#    • List, copy, move, delete operations
#    • Multipart upload simulation
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON S3 — Simple Storage Service" "📦"
check_localstack

BUCKET_NAME="demo-s3-bucket-$(date +%s)"
VERSIONED_BUCKET="demo-versioned-bucket"

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE BUCKETS
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Buckets"

log_step "Creating bucket: ${BUCKET_NAME}"
$AWS_CMD s3 mb "s3://${BUCKET_NAME}"
log_success "Bucket created: ${BUCKET_NAME}"

log_step "Creating versioned bucket: ${VERSIONED_BUCKET}"
$AWS_CMD s3 mb "s3://${VERSIONED_BUCKET}" 2>/dev/null || true

# Enable versioning
$AWS_CMD s3api put-bucket-versioning \
    --bucket "${VERSIONED_BUCKET}" \
    --versioning-configuration Status=Enabled
log_success "Versioning enabled on: ${VERSIONED_BUCKET}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST BUCKETS
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. List All Buckets"

$AWS_CMD s3 ls
log_success "Buckets listed"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  UPLOAD OBJECTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Upload Objects"

# Create sample files
TMPDIR=$(mktemp -d)
echo '{"message": "Hello from LocalStack S3!", "timestamp": "'$(date -Iseconds)'"}' > "${TMPDIR}/data.json"
echo "This is a sample text file for S3 upload testing." > "${TMPDIR}/readme.txt"
echo "id,name,email" > "${TMPDIR}/users.csv"
echo "1,Alice,alice@example.com" >> "${TMPDIR}/users.csv"
echo "2,Bob,bob@example.com" >> "${TMPDIR}/users.csv"

log_step "Uploading data.json"
$AWS_CMD s3 cp "${TMPDIR}/data.json" "s3://${BUCKET_NAME}/data/data.json"
log_success "Uploaded: data/data.json"

log_step "Uploading readme.txt with metadata"
$AWS_CMD s3 cp "${TMPDIR}/readme.txt" "s3://${BUCKET_NAME}/docs/readme.txt" \
    --metadata '{"author":"localstack-demo","version":"1.0"}'
log_success "Uploaded: docs/readme.txt"

log_step "Uploading users.csv"
$AWS_CMD s3 cp "${TMPDIR}/users.csv" "s3://${BUCKET_NAME}/data/users.csv" \
    --content-type "text/csv"
log_success "Uploaded: data/users.csv"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST OBJECTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. List Objects"

log_step "Listing all objects in ${BUCKET_NAME}"
$AWS_CMD s3 ls "s3://${BUCKET_NAME}/" --recursive --human-readable

log_step "Listing objects with prefix 'data/'"
$AWS_CMD s3 ls "s3://${BUCKET_NAME}/data/"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DOWNLOAD OBJECTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Download Objects"

DOWNLOAD_DIR="${TMPDIR}/downloads"
mkdir -p "${DOWNLOAD_DIR}"

log_step "Downloading data.json"
$AWS_CMD s3 cp "s3://${BUCKET_NAME}/data/data.json" "${DOWNLOAD_DIR}/data.json"
log_success "Downloaded to: ${DOWNLOAD_DIR}/data.json"
log_detail "Content: $(cat "${DOWNLOAD_DIR}/data.json")"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  COPY & MOVE OBJECTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Copy & Move Objects"

log_step "Copying data.json to backup location"
$AWS_CMD s3 cp "s3://${BUCKET_NAME}/data/data.json" "s3://${BUCKET_NAME}/backup/data.json"
log_success "Copied: data/data.json → backup/data.json"

log_step "Moving readme.txt to archive"
$AWS_CMD s3 mv "s3://${BUCKET_NAME}/docs/readme.txt" "s3://${BUCKET_NAME}/archive/readme.txt"
log_success "Moved: docs/readme.txt → archive/readme.txt"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  BUCKET POLICY
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. Bucket Policy"

POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::'${BUCKET_NAME}'/public/*"
        }
    ]
}'

log_step "Applying bucket policy (public read on /public/*)"
$AWS_CMD s3api put-bucket-policy --bucket "${BUCKET_NAME}" --policy "$POLICY"
log_success "Bucket policy applied"

log_step "Retrieving bucket policy"
$AWS_CMD s3api get-bucket-policy --bucket "${BUCKET_NAME}" --output json 2>/dev/null | python3 -m json.tool 2>/dev/null || log_detail "Policy retrieved"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  PRESIGNED URL
# ══════════════════════════════════════════════════════════════════════════════
section_start "8. Presigned URL"

log_step "Generating presigned URL (expires in 3600s)"
PRESIGNED_URL=$($AWS_CMD s3 presign "s3://${BUCKET_NAME}/data/data.json" --expires-in 3600)
log_success "Presigned URL generated"
log_detail "URL: ${PRESIGNED_URL}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  VERSIONING DEMO
# ══════════════════════════════════════════════════════════════════════════════
section_start "9. Versioning Demo"

echo '{"version": 1, "data": "initial"}' > "${TMPDIR}/versioned.json"
$AWS_CMD s3 cp "${TMPDIR}/versioned.json" "s3://${VERSIONED_BUCKET}/versioned.json"
log_success "Uploaded version 1"

echo '{"version": 2, "data": "updated"}' > "${TMPDIR}/versioned.json"
$AWS_CMD s3 cp "${TMPDIR}/versioned.json" "s3://${VERSIONED_BUCKET}/versioned.json"
log_success "Uploaded version 2"

log_step "Listing object versions"
$AWS_CMD s3api list-object-versions --bucket "${VERSIONED_BUCKET}" --prefix "versioned.json" \
    --output table 2>/dev/null || \
$AWS_CMD s3api list-object-versions --bucket "${VERSIONED_BUCKET}" --prefix "versioned.json"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CLEANUP
# ══════════════════════════════════════════════════════════════════════════════
section_start "10. Cleanup"

log_step "Emptying and deleting demo bucket"
$AWS_CMD s3 rb "s3://${BUCKET_NAME}" --force
log_success "Bucket deleted: ${BUCKET_NAME}"

rm -rf "${TMPDIR}"

section_end

summary_box "S3 Operations Complete" \
    "Buckets: create, list, versioning, policies" \
    "Objects: upload, download, copy, move, presign" \
    "Cleanup: empty & delete"
