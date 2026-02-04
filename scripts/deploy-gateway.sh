#!/bin/bash

###############################################################################
# Script de Deploy do API Gateway
###############################################################################

set -e  # Exit on error

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para print colorido
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

# Verificar se gcloud está instalado
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI não está instalado"
    exit 1
fi

# Configurações
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
API_ID="${API_ID:-star-wars-api}"
CONFIG_ID="${CONFIG_ID:-star-wars-api-config}"
GATEWAY_ID="${GATEWAY_ID:-star-wars-gateway}"
OPENAPI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../openapi" && pwd)"
OPENAPI_FILE="$OPENAPI_DIR/openapi-spec.yaml"
OPENAPI_PROCESSED="$OPENAPI_DIR/openapi-spec-processed.yaml"

# Solicitar PROJECT_ID se não estiver definido
if [ -z "$PROJECT_ID" ]; then
    print_warning "GCP_PROJECT_ID não está definido"
    read -p "Digite o ID do seu projeto GCP: " PROJECT_ID
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID é obrigatório"
    exit 1
fi

print_info "Configurações:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  API ID: $API_ID"
echo "  Config ID: $CONFIG_ID"
echo "  Gateway ID: $GATEWAY_ID"
echo "  OpenAPI File: $OPENAPI_FILE"
echo ""

# Verificar se arquivo OpenAPI existe
if [ ! -f "$OPENAPI_FILE" ]; then
    print_error "Arquivo OpenAPI não encontrado: $OPENAPI_FILE"
    exit 1
fi

# Confirmar deploy
if [ -z "$AUTO_CONFIRM" ]; then
    read -p "Deseja continuar com o deploy? (y/n) " -n 1 -r
    echo
fi

if [[ ! $REPLY =~ ^[Yy]$ && -z "$AUTO_CONFIRM" ]]; then
    print_warning "Deploy cancelado"
    exit 0
fi

# Configurar projeto
print_info "Configurando projeto GCP..."
gcloud config set project "$PROJECT_ID"

# Obter service account
print_info "Obtendo service account..."
SERVICE_ACCOUNT=$(gcloud iam service-accounts list \
    --filter="email:$PROJECT_ID@appspot.gserviceaccount.com" \
    --format="value(email)")

if [ -z "$SERVICE_ACCOUNT" ]; then
    SERVICE_ACCOUNT=$(gcloud projects describe "$PROJECT_ID" \
        --format="value(projectNumber)")-compute@developer.gserviceaccount.com
fi

print_info "Service Account: $SERVICE_ACCOUNT"

# Processar arquivo OpenAPI (substituir placeholders)
print_info "Processando arquivo OpenAPI..."
sed -e "s/PROJECT_ID/$PROJECT_ID/g" \
    -e "s/REGION/$REGION/g" \
    "$OPENAPI_FILE" > "$OPENAPI_PROCESSED"

print_info "Arquivo OpenAPI processado: $OPENAPI_PROCESSED"

# Criar API
print_info "Criando API no API Gateway..."
if gcloud api-gateway apis describe "$API_ID" &>/dev/null; then
    print_warning "API $API_ID já existe, pulando criação"
else
    gcloud api-gateway apis create "$API_ID" \
        --project="$PROJECT_ID"
    
    print_info "✓ API criada: $API_ID"
fi

# Criar API Config
print_info "Criando API Config..."
print_warning "Este processo pode levar vários minutos..."

gcloud api-gateway api-configs create "$CONFIG_ID" \
    --api="$API_ID" \
    --openapi-spec="$OPENAPI_PROCESSED" \
    --backend-auth-service-account="$SERVICE_ACCOUNT" \
    --project="$PROJECT_ID"

if [ $? -eq 0 ]; then
    print_info "✓ API Config criado: $CONFIG_ID"
else
    print_error "Falha ao criar API Config"
    print_info "Você pode verificar o status com:"
    echo "  gcloud api-gateway api-configs describe $CONFIG_ID --api=$API_ID"
    exit 1
fi

# Aguardar API Config ficar ativo
print_info "Aguardando API Config ficar ativo..."
for i in {1..30}; do
    STATE=$(gcloud api-gateway api-configs describe "$CONFIG_ID" \
        --api="$API_ID" \
        --format="value(state)" 2>/dev/null || echo "UNKNOWN")
    
    if [ "$STATE" = "ACTIVE" ]; then
        print_info "✓ API Config está ativo"
        break
    fi
    
    echo -n "."
    sleep 10
done
echo ""

# Criar Gateway
print_info "Criando Gateway..."
if gcloud api-gateway gateways describe "$GATEWAY_ID" --location="$REGION" &>/dev/null; then
    print_warning "Gateway $GATEWAY_ID já existe"
        if [ -z "$AUTO_CONFIRM" ]; then
        read -p "Deseja atualizar o gateway? (y/n) " -n 1 -r
        echo
    fi
    if [[ $REPLY =~ ^[Yy]$ || -n "$AUTO_CONFIRM" ]]; then
        print_info "Atualizando gateway..."
        gcloud api-gateway gateways update "$GATEWAY_ID" \
            --api="$API_ID" \
            --api-config="$CONFIG_ID" \
            --location="$REGION" \
            --project="$PROJECT_ID"
    fi
else
    gcloud api-gateway gateways create "$GATEWAY_ID" \
        --api="$API_ID" \
        --api-config="$CONFIG_ID" \
        --location="$REGION" \
        --project="$PROJECT_ID"
    
    print_info "✓ Gateway criado: $GATEWAY_ID"
fi

# Aguardar Gateway ficar ativo
print_info "Aguardando Gateway ficar ativo..."
for i in {1..30}; do
    STATE=$(gcloud api-gateway gateways describe "$GATEWAY_ID" \
        --location="$REGION" \
        --format="value(state)" 2>/dev/null || echo "UNKNOWN")
    
    if [ "$STATE" = "ACTIVE" ]; then
        print_info "✓ Gateway está ativo"
        break
    fi
    
    echo -n "."
    sleep 10
done
echo ""

# Obter URL do Gateway
GATEWAY_URL=$(gcloud api-gateway gateways describe "$GATEWAY_ID" \
    --location="$REGION" \
    --format="value(defaultHostname)")

echo ""
echo "=========================================="
print_success "Deploy concluído com sucesso!"
echo "=========================================="
echo ""
echo "Gateway URL: https://$GATEWAY_URL"
echo ""
echo "Endpoints disponíveis:"
echo "  - GET https://$GATEWAY_URL/api/v1/people"
echo "  - GET https://$GATEWAY_URL/api/v1/films"
echo "  - GET https://$GATEWAY_URL/api/v1/planets"
echo "  - GET https://$GATEWAY_URL/api/v1/starships"
echo "  - GET https://$GATEWAY_URL/api/v1/vehicles"
echo "  - GET https://$GATEWAY_URL/api/v1/health"
echo ""
echo "Exemplos de uso:"
echo "  curl https://$GATEWAY_URL/api/v1/people?search=luke"
echo "  curl https://$GATEWAY_URL/api/v1/planets?climate=arid"
echo "  curl https://$GATEWAY_URL/api/v1/starships/9"
echo ""
echo "Documentação completa: README.md"
echo ""

# Limpar arquivo processado
rm -f "$OPENAPI_PROCESSED"

print_info "Para visualizar logs:"
echo "  gcloud logging read 'resource.type=api' --limit=50 --format=json"
