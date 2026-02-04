# 🧪 Guia de Testes da Star Wars API no Google Cloud Platform

Este guia detalha como testar a Star Wars API implantada no Google Cloud Platform, utilizando o API Gateway como ponto de entrada unificado. Ele inclui exemplos para as funcionalidades básicas e avançadas (cache, enriquecimento, ordenação e consultas correlacionadas).

## 🔗 URL Base da API

Primeiro, obtenha a URL do seu API Gateway. Se você seguiu o guia de implantação, pode obtê-la com o comando:

```cmd
gcloud api-gateway gateways describe star-wars-gateway-final --location=us-central1 --project=SEU-ID-DO-PROJETO --format="value(defaultHostname)"
```

Substitua `SEU-ID-DO-PROJETO` pelo ID real do seu projeto. A URL será algo como: `https://star-wars-gateway-final-xxxx.uc.gateway.dev`.

Vamos chamar esta URL de `SUA_URL_GATEWAY` nos exemplos abaixo.

## 🚀 Testes Básicos

### 1. Health Check
Verifica se a API está operacional e se consegue se comunicar com a SWAPI.

*   **Endpoint**: `/api/v1/health`
*   **Método**: `GET`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/health`
*   **Resposta Esperada**: `{"status": "operational", "features": ["cache", "enrichment", "sorting", "correlation"]}`

### 2. Consulta de Personagens (Luke Skywalker)
Busca um personagem específico pelo nome.

*   **Endpoint**: `/api/v1/people`
*   **Método**: `GET`
*   **Parâmetro**: `search=luke`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/people?search=luke`
*   **Resposta Esperada**: JSON com detalhes do Luke Skywalker, incluindo `homeworld_name` enriquecido.

### 3. Consulta de Filmes (A New Hope)
Busca um filme específico pelo nome.

*   **Endpoint**: `/api/v1/films`
*   **Método**: `GET`
*   **Parâmetro**: `search=A New Hope`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/films?search=A New Hope`
*   **Resposta Esperada**: JSON com detalhes do filme "A New Hope", incluindo `characters_names` enriquecidos.

## ✨ Testes Avançados (Funcionalidades de Complexidade)

### 1. Consulta por ID (Filme 1)

Acessa um recurso diretamente pelo seu ID na URL.

*   **Endpoint**: `/api/v1/films/{id}`
*   **Método**: `GET`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/films/1`
*   **Resposta Esperada**: JSON com detalhes do filme "A New Hope".

### 2. Tratamento de ID Inexistente (Veículo 10)

Demonstra a resiliência da API ao lidar com IDs que não existem na SWAPI.

*   **Endpoint**: `/api/v1/vehicles/{id}`
*   **Método**: `GET`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/vehicles/10`
*   **Resposta Esperada**: JSON com mensagem de erro clara:
    ```json
    {
      "error": "Não Encontrado",
      "message": "O identificador '10' não corresponde a nenhum(a) vehicles na base de dados Star Wars. Note que os IDs não são necessariamente sequenciais.",
      "suggestion": "Consulte a listagem geral para ver os IDs disponíveis."
    }
    ```

### 3. Ordenação Dinâmica (Pessoas mais altas)

Ordena os resultados de uma consulta por um campo específico. A API suporta ordenação por campos numéricos e textuais.

*   **Endpoint**: `/api/v1/people`
*   **Método**: `GET`
*   **Parâmetros**: `sort_by=height&order=desc`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/people?sort_by=height&order=desc`
*   **Resposta Esperada**: Uma lista de personagens ordenada por altura (do maior para o menor). Verifique o campo `sorted_by` no objeto `metadata` da resposta.

### 4. Consultas Correlacionadas (Personagens do Filme 1)

Busca recursos relacionados a outro recurso em uma única requisição. Esta funcionalidade é otimizada para performance.

*   **Endpoint**: `/api/v1/people`
*   **Método**: `GET`
*   **Parâmetro**: `related_to=films/1`
*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/people?related_to=films/1`
*   **Resposta Esperada**: Uma lista de personagens que aparecem no filme "A New Hope", com seus dados enriquecidos (ex: `homeworld_name`).

### 5. Verificação de Cache e Metadados

Todas as respostas incluem um objeto `metadata` que fornece informações de auditoria e performance, incluindo o uso do cache.

*   **Exemplo**: `SUA_URL_GATEWAY/api/v1/people/1`
*   **Resposta Esperada**: 
    ```json
    {
      "results": { ... },
      "audit": {
        "timestamp": "2026-02-03T12:00:00.000000Z",
        "version": "2.6.0",
        "request_id": "local-dev"
      },
      "metadata": {
        "latency_ms": 150, // Latência da requisição em milissegundos
        "cached": false,   // true se a resposta veio do cache, false se foi para a SWAPI
        "complexity": "Expert (Sorting + Correlation)"
      }
    }
    ```
    Faça a mesma requisição novamente e observe como `latency_ms` diminui drasticamente e `cached` se torna `true`, demonstrando o funcionamento do cache.

## 💡 Dicas de Teste

*   Utilize ferramentas como **Postman**, **Insomnia** ou o próprio navegador para realizar as requisições.
*   Para testar a ordenação, experimente diferentes campos como `name`, `mass`, `diameter`, `population`.
*   Para consultas correlacionadas, tente `related_to=planets/1` para ver os residentes de Tatooine. 
    (`SUA_URL_GATEWAY/api/v1/people?related_to=planets/1`).

Este guia deve fornecer uma base sólida para validar todas as funcionalidades da sua Star Wars API. Que a Força esteja com você nos testes!
