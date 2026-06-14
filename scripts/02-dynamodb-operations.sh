#!/usr/bin/env bash
# ══ 02 — Amazon DynamoDB Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON DYNAMODB — NoSQL Database" "🗄️"
check_floci
TABLE="demo-products"

section_start "1. Create Table (with GSI)"
$AWS_CMD dynamodb create-table --table-name "${TABLE}" \
    --attribute-definitions AttributeName=productId,AttributeType=S AttributeName=category,AttributeType=S \
    --key-schema AttributeName=productId,KeyType=HASH \
    --global-secondary-indexes 'IndexName=CategoryIndex,KeySchema=[{AttributeName=category,KeyType=HASH}],Projection={ProjectionType=ALL}' \
    --billing-mode PAY_PER_REQUEST 2>/dev/null || log_detail "Table may exist"
log_success "Table: ${TABLE} (GSI: CategoryIndex)"
section_end

section_start "2. List Tables"
$AWS_CMD dynamodb list-tables --output table
section_end

section_start "3. Put Items"
for item in \
  '{"productId":{"S":"P001"},"name":{"S":"MacBook Pro"},"category":{"S":"Electronics"},"price":{"N":"2499"}}' \
  '{"productId":{"S":"P002"},"name":{"S":"Keyboard"},"category":{"S":"Electronics"},"price":{"N":"149"}}' \
  '{"productId":{"S":"P003"},"name":{"S":"Standing Desk"},"category":{"S":"Furniture"},"price":{"N":"599"}}' \
  '{"productId":{"S":"P004"},"name":{"S":"Headphones"},"category":{"S":"Electronics"},"price":{"N":"349"}}'; do
    NAME=$(echo "$item" | python3 -c "import json,sys;print(json.load(sys.stdin)['name']['S'])" 2>/dev/null)
    $AWS_CMD dynamodb put-item --table-name "${TABLE}" --item "$item"
    log_success "Inserted: ${NAME}"
done
section_end

section_start "4. Get Item"
$AWS_CMD dynamodb get-item --table-name "${TABLE}" --key '{"productId":{"S":"P001"}}' --output json | python3 -m json.tool 2>/dev/null | head -15 | sed 's/^/   /'
section_end

section_start "5. Update Item"
$AWS_CMD dynamodb update-item --table-name "${TABLE}" --key '{"productId":{"S":"P001"}}' \
    --update-expression "SET price = :p" --expression-attribute-values '{":p":{"N":"2299"}}' \
    --return-values ALL_NEW --output json | python3 -m json.tool 2>/dev/null | head -10 | sed 's/^/   /'
log_success "Price updated: P001 → $2299"
section_end

section_start "6. Query GSI"
$AWS_CMD dynamodb query --table-name "${TABLE}" --index-name "CategoryIndex" \
    --key-condition-expression "category = :c" --expression-attribute-values '{":c":{"S":"Electronics"}}' \
    --output json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'   Found {d[\"Count\"]} Electronics items:')
for i in d['Items']:print(f'     • {i[\"name\"][\"S\"]} — \${i[\"price\"][\"N\"]}')
" 2>/dev/null
section_end

section_start "7. Scan with Filter"
$AWS_CMD dynamodb scan --table-name "${TABLE}" --filter-expression "price > :p" \
    --expression-attribute-values '{":p":{"N":"200"}}' --output json | python3 -c "
import json,sys
for i in json.load(sys.stdin)['Items']:print(f'   • {i[\"name\"][\"S\"]} — \${i[\"price\"][\"N\"]}')
" 2>/dev/null
section_end

section_start "8. Delete Item"
$AWS_CMD dynamodb delete-item --table-name "${TABLE}" --key '{"productId":{"S":"P003"}}' && log_success "Deleted P003"
section_end

summary_box "DynamoDB Complete" "Tables, CRUD, GSI query, scan filter, batch"
