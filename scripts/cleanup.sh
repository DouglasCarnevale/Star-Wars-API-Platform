#!/bin/bash

###############################################################################
# Script de Limpeza de Recursos GCP
#Remove todos os recursos criados
###############################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configurações
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
API_ID="${API_ID:-star-wars-api}"
CONFIG_ID="${CONFIG_ID:-star-wars-api-config}"
GATEWAY_ID="${GATEWAY_ID:-star-wars-gateway}"

if [ -z "$PROJECT_ID" ]; then
    read -p "Digite o ID do seu projeto GCP: " PROJECT_ID
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID é obrigatório"
    exit 1
fi

print_warning "ATENÇÃO: Este script irá DELETAR todos os recursos da Star Wars API"
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo ""
read -p "Tem certeza que deseja continuar? Digite 'yes' para confirmar: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Operação cancelada"
    exit 0
fi

gcloud config set project "$PROJECT_ID"

# Deletar Gateway
print_info "Deletando Gateway..."
if gcloud api-gateway gateways describe "$GATEWAY_ID" --location="$REGION" &>/dev/null; then
    gcloud api-gateway gateways delete "$GATEWAY_ID" \
        --location="$REGION" \
        --quiet
    print_info "✓ Gateway deletado"
else
    print_warning "Gateway não encontrado"
fi

# Deletar API Config
print_info "Deletando API Config..."
if gcloud api-gateway api-configs describe "$CONFIG_ID" --api="$API_ID" &>/dev/null; then
    gcloud api-gateway api-configs delete "$CONFIG_ID" \
        --api="$API_ID" \
        --quiet
    print_info "✓ API Config deletado"
else
    print_warning "API Config não encontrado"
fi

# Deletar API
print_info "Deletando API..."
if gcloud api-gateway apis describe "$API_ID" &>/dev/null; then
    gcloud api-gateway apis delete "$API_ID" --quiet
    print_info "✓ API deletada"
else
    print_warning "API não encontrada"
fi

# Deletar Cloud Functions
declare -a FUNCTIONS=(
    "get_people"
    "get_films"
    "get_planets"
    "get_starships"
    "get_vehicles"
    "health_check"
)

print_info "Deletando Cloud Functions..."
for FUNCTION_NAME in "${FUNCTIONS[@]}"; do
    if gcloud functions describe "$FUNCTION_NAME" --gen2 --region="$REGION" &>/dev/null; then
        gcloud functions delete "$FUNCTION_NAME" \
            --gen2 \
            --region="$REGION" \
            --quiet
        print_info "✓ Function $FUNCTION_NAME deletada"
    else
        print_warning "Function $FUNCTION_NAME não encontrada"
    fi
done

echo ""
print_info "Limpeza concluída!"
print_warning "Nota: As APIs habilitadas não foram desabilitadas automaticamente"
