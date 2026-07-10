# Cloud Run & Monitoring Demo App

Esta é uma aplicação demonstrativa simples em Python (Flask) projetada para rodar no **Google Cloud Run** e demonstrar a geração de logs automáticos e o monitoramento/alertas de erros no **Google Cloud Logging & Monitoring**.

A aplicação executa uma thread em segundo plano que gera logs periodicamente (a cada 5 segundos) sem a necessidade de interações com endpoints externos. O tipo de log gerado é controlado por uma variável de ambiente.

---

## ⚙️ Variável de Controle de Erro

A aplicação lê a variável de ambiente:
- **`GENERATE_ERRORS`**: 
  - Se configurada como `true` (ou `1`), a thread gerará logs de erro (`logger.error`).
  - Se configurada como `false` (ou não configurada), a thread gerará logs normais de informação (`logger.info`).

---

## 🚀 Como Executar Localmente

### Opção 1: Diretamente com Python

1. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```

2. Execute gerando logs **normais**:
   ```bash
   export GENERATE_ERRORS=false
   python app.py
   ```

3. Execute gerando logs de **erro**:
   ```bash
   export GENERATE_ERRORS=true
   python app.py
   ```

### Opção 2: Usando Docker

1. Construa a imagem Docker:
   ```bash
   docker build -t cloud-run-demo .
   ```

2. Execute simulando erros:
   ```bash
   docker run -p 8080:8080 -e GENERATE_ERRORS=true cloud-run-demo
   ```

---

## ☁️ Como Deployar no Google Cloud Run

Você pode realizar o deploy da aplicação definindo a variável de ambiente diretamente no comando do `gcloud`:

```bash
# Deploy gerando logs normais
gcloud run deploy cloud-run-demo \
    --source . \
    --region us-central1 \
    --set-env-vars GENERATE_ERRORS=false \
    --allow-unauthenticated

# Alternar para gerar logs de ERRO (sem precisar reinstalar ou re-buildar a imagem)
gcloud run services update cloud-run-demo \
    --region us-central1 \
    --set-env-vars GENERATE_ERRORS=true
```

---

## 📊 Testando o Monitoramento no Google Cloud Console

1. Com o serviço deployado e `GENERATE_ERRORS=true`, a aplicação começará a registrar entradas de erro automaticamente a cada 5 segundos.
2. Acesse o **Google Cloud Logging (Logs Explorer)** no Console do GCP.
3. Filtre pelo recurso `Cloud Run Revision` e verifique a geração contínua de alertas em nível `ERROR` com a mensagem:
   `"SIMULATION ERROR: Ocorreu um erro interno simulado no processamento em segundo plano."`
