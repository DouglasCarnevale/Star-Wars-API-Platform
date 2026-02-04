#!/bin/bash

###############################################################################
# Script de Deploy das Cloud Functions
###############################################################################

set -e  # Exit on error

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Verificar se gcloud está instalado
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI não está instalado."
    exit 1
fi

# Configurações
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
# O diretório source DEVE conter o arquivo main.py na raiz
FUNCTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../functions" && pwd)"

# Solicitar PROJECT_ID se não estiver definido
if [ -z "$PROJECT_ID" ]; then
    print_warning "GCP_PROJECT_ID não está definido"
    read -p "Digite o ID do seu projeto GCP: " PROJECT_ID
fi

if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID é obrigatório"
    exit 1
fi

# Validar se main.py existe no diretório
if [ ! -f "$FUNCTIONS_DIR/main.py" ]; then
    print_error "ERRO: main.py não encontrado em $FUNCTIONS_DIR"
    exit 1
fi

print_info "Iniciando deploy das funções..."
print_info "Diretório de origem: $FUNCTIONS_DIR"

gcloud config set project "$PROJECT_ID"

# Array de funções para deploy
declare -a FUNCTIONS=(
    "get_people"
    "get_films"
    "get_planets"
    "get_starships"
    "get_vehicles"
    "health_check"
)

for FUNCTION_NAME in "${FUNCTIONS[@]}"; do
    print_info "Implantando função: $FUNCTION_NAME"
    
    # O segredo é garantir que o --source aponte para a pasta que contém o main.py
    # E que o --entry-point seja o nome da função dentro do main.py
    gcloud functions deploy "$FUNCTION_NAME" \
        --gen2 \
        --runtime=python311 \
        --region="$REGION" \
        --source="$FUNCTIONS_DIR" \
        --entry-point="$FUNCTION_NAME" \
        --trigger-http \
        --allow-unauthenticated \
        --timeout=60s \
        --memory=256MB \
        --quiet
    
    if [ $? -eq 0 ]; then
        print_info "✓ Função $FUNCTION_NAME implantada com sucesso"
    else
        print_error "✗ Falha no deploy de $FUNCTION_NAME"
        exit 1
    fi
done

print_info "Deploy das funções concluído!"
