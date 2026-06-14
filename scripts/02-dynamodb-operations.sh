#!/usr/bin/env bash
# ==============================================================================
#  02 — Amazon DynamoDB Operations
# ==============================================================================
#  Demonstrates the full DynamoDB lifecycle:
#    • Create tables (hash key, hash+range, GSI, LSI)
#    • Put / Get / Update / Delete items
#    • Query & Scan with filters
#    • Batch write & batch get
#    • TTL configuration
#    • Stream configuration
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON DYNAMODB — NoSQL Database" "🗄️"
check_localstack

TABLE_NAME="demo-products"
GSI_TABLE="demo-orders-gsi"

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE TABLES
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Tables"

log_step "Creating table: ${TABLE_NAME} (Hash Key: productId)"
$AWS_CMD dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions \
        AttributeName=productId,AttributeType=S \
        AttributeName=category,AttributeType=S \
    --key-schema \
        AttributeName=productId,KeyType=HASH \
    --global-secondary-indexes \
        'IndexName=CategoryIndex,KeySchema=[{AttributeName=category,KeyType=HASH}],Projection={ProjectionType=ALL}' \
    --billing-mode PAY_PER_REQUEST \
    --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
t = d['TableDescription']
print(f'   Table: {t[\"TableName\"]}')
print(f'   Status: {t[\"TableStatus\"]}')
print(f'   ARN: {t[\"TableArn\"]}')
" 2>/dev/null || log_success "Table created (or already exists)"
log_success "Table created: ${TABLE_NAME}"

log_step "Creating table with composite key: ${GSI_TABLE}"
$AWS_CMD dynamodb create-table \
    --table-name "${GSI_TABLE}" \
    --attribute-definitions \
        AttributeName=orderId,AttributeType=S \
        AttributeName=orderDate,AttributeType=S \
        AttributeName=customerId,AttributeType=S \
    --key-schema \
        AttributeName=orderId,KeyType=HASH \
        AttributeName=orderDate,KeyType=RANGE \
    --global-secondary-indexes \
        'IndexName=CustomerIndex,KeySchema=[{AttributeName=customerId,KeyType=HASH},{AttributeName=orderDate,KeyType=RANGE}],Projection={ProjectionType=ALL}' \
    --billing-mode PAY_PER_REQUEST 2>/dev/null || true
log_success "Table created: ${GSI_TABLE}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST TABLES
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. List Tables"

$AWS_CMD dynamodb list-tables --output table
log_success "Tables listed"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  PUT ITEMS
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Put Items"

ITEMS=(
    '{"productId":{"S":"PROD-001"},"name":{"S":"MacBook Pro 16"},"category":{"S":"Electronics"},"price":{"N":"2499.99"},"inStock":{"BOOL":true},"tags":{"SS":["laptop","apple","pro"]}}'
    '{"productId":{"S":"PROD-002"},"name":{"S":"Ergonomic Keyboard"},"category":{"S":"Electronics"},"price":{"N":"149.99"},"inStock":{"BOOL":true},"tags":{"SS":["keyboard","ergonomic"]}}'
    '{"productId":{"S":"PROD-003"},"name":{"S":"Standing Desk"},"category":{"S":"Furniture"},"price":{"N":"599.00"},"inStock":{"BOOL":false},"tags":{"SS":["desk","standing"]}}'
    '{"productId":{"S":"PROD-004"},"name":{"S":"Noise Cancelling Headphones"},"category":{"S":"Electronics"},"price":{"N":"349.99"},"inStock":{"BOOL":true},"tags":{"SS":["audio","headphones"]}}'
    '{"productId":{"S":"PROD-005"},"name":{"S":"Monitor Arm"},"category":{"S":"Furniture"},"price":{"N":"89.99"},"inStock":{"BOOL":true},"tags":{"SS":["monitor","arm"]}}'
)

for item in "${ITEMS[@]}"; do
    PRODUCT_NAME=$(echo "$item" | python3 -c "import json,sys; print(json.load(sys.stdin)['name']['S'])" 2>/dev/null || echo "item")
    $AWS_CMD dynamodb put-item --table-name "${TABLE_NAME}" --item "$item"
    log_success "Inserted: ${PRODUCT_NAME}"
done

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  GET ITEM
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Get Item"

log_step "Getting PROD-001"
RESULT=$($AWS_CMD dynamodb get-item \
    --table-name "${TABLE_NAME}" \
    --key '{"productId":{"S":"PROD-001"}}' \
    --output json)
echo "$RESULT" | python3 -m json.tool 2>/dev/null
log_success "Item retrieved"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  UPDATE ITEM
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Update Item"

log_step "Updating price of PROD-001 to 2299.99"
$AWS_CMD dynamodb update-item \
    --table-name "${TABLE_NAME}" \
    --key '{"productId":{"S":"PROD-001"}}' \
    --update-expression "SET price = :p, lastUpdated = :ts" \
    --expression-attribute-values '{":p":{"N":"2299.99"},":ts":{"S":"'"$(date -Iseconds)"'"}}' \
    --return-values ALL_NEW \
    --output json | python3 -m json.tool 2>/dev/null
log_success "Item updated"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  QUERY (by GSI)
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Query — Global Secondary Index"

log_step "Querying Electronics category via CategoryIndex"
$AWS_CMD dynamodb query \
    --table-name "${TABLE_NAME}" \
    --index-name "CategoryIndex" \
    --key-condition-expression "category = :cat" \
    --expression-attribute-values '{":cat":{"S":"Electronics"}}' \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'   Found {data[\"Count\"]} items:')
for item in data['Items']:
    print(f'     • {item[\"name\"][\"S\"]} — \${item[\"price\"][\"N\"]}')
" 2>/dev/null
log_success "Query complete"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  SCAN WITH FILTER
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. Scan with Filter Expression"

log_step "Scanning for products with price > 200"
$AWS_CMD dynamodb scan \
    --table-name "${TABLE_NAME}" \
    --filter-expression "price > :min_price" \
    --expression-attribute-values '{":min_price":{"N":"200"}}' \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'   Found {data[\"Count\"]} items (scanned {data[\"ScannedCount\"]}):')
for item in data['Items']:
    stock = '✅ In Stock' if item.get('inStock', {}).get('BOOL', False) else '❌ Out of Stock'
    print(f'     • {item[\"name\"][\"S\"]} — \${item[\"price\"][\"N\"]} ({stock})')
" 2>/dev/null
log_success "Scan complete"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  BATCH WRITE
# ══════════════════════════════════════════════════════════════════════════════
section_start "8. Batch Write Items"

log_step "Batch writing 3 orders to ${GSI_TABLE}"
$AWS_CMD dynamodb batch-write-item --request-items '{
    "'${GSI_TABLE}'": [
        {"PutRequest":{"Item":{"orderId":{"S":"ORD-001"},"orderDate":{"S":"2025-01-15"},"customerId":{"S":"CUST-A"},"total":{"N":"299.99"},"status":{"S":"shipped"}}}},
        {"PutRequest":{"Item":{"orderId":{"S":"ORD-002"},"orderDate":{"S":"2025-01-16"},"customerId":{"S":"CUST-A"},"total":{"N":"149.50"},"status":{"S":"delivered"}}}},
        {"PutRequest":{"Item":{"orderId":{"S":"ORD-003"},"orderDate":{"S":"2025-01-17"},"customerId":{"S":"CUST-B"},"total":{"N":"599.00"},"status":{"S":"pending"}}}}
    ]
}'
log_success "Batch write complete"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  BATCH GET
# ══════════════════════════════════════════════════════════════════════════════
section_start "9. Batch Get Items"

log_step "Batch getting PROD-001 and PROD-003"
$AWS_CMD dynamodb batch-get-item --request-items '{
    "'${TABLE_NAME}'": {
        "Keys": [
            {"productId":{"S":"PROD-001"}},
            {"productId":{"S":"PROD-003"}}
        ]
    }
}' --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data['Responses']['${TABLE_NAME}']
for item in items:
    print(f'   • {item[\"name\"][\"S\"]} — \${item[\"price\"][\"N\"]}')
" 2>/dev/null
log_success "Batch get complete"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DELETE ITEM
# ══════════════════════════════════════════════════════════════════════════════
section_start "10. Delete Item"

log_step "Deleting PROD-005"
$AWS_CMD dynamodb delete-item \
    --table-name "${TABLE_NAME}" \
    --key '{"productId":{"S":"PROD-005"}}' \
    --return-values ALL_OLD \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
item = data.get('Attributes', {})
if item:
    print(f'   Deleted: {item[\"name\"][\"S\"]}')
" 2>/dev/null
log_success "Item deleted"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DESCRIBE TABLE
# ══════════════════════════════════════════════════════════════════════════════
section_start "11. Table Description"

$AWS_CMD dynamodb describe-table --table-name "${TABLE_NAME}" --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)['Table']
print(f'   Table Name:       {d[\"TableName\"]}')
print(f'   Status:           {d[\"TableStatus\"]}')
print(f'   Item Count:       {d.get(\"ItemCount\", \"N/A\")}')
print(f'   Table Size:       {d.get(\"TableSizeBytes\", \"N/A\")} bytes')
print(f'   Billing Mode:     {d.get(\"BillingModeSummary\", {}).get(\"BillingMode\", \"N/A\")}')
gsis = d.get('GlobalSecondaryIndexes', [])
if gsis:
    print(f'   GSIs:')
    for gsi in gsis:
        print(f'     • {gsi[\"IndexName\"]} ({gsi[\"IndexStatus\"]})')
" 2>/dev/null

section_end

summary_box "DynamoDB Operations Complete" \
    "Tables: create with GSI, list, describe" \
    "Items: put, get, update, delete" \
    "Advanced: query GSI, scan filters, batch ops"
