#!/bin/bash

# ==============================================================================
# Script de Configuração do Workload Identity Federation (WIF) para GitHub Actions
# ==============================================================================

# Defina as variáveis abaixo antes de executar o script:
export PROJECT_ID="seu projeto"
export REPO_OWNER="seu_usuario_ou_organizacao_github"
export REPO_NAME="seu-repo"
export REGION="us-central1"

# Limpa qualquer barra extra (como "DaviFerreiraLima/") do REPO_OWNER
REPO_OWNER=$(echo "${REPO_OWNER}" | sed 's/\/$//')

echo "1. Ativando APIs necessárias no Google Cloud..."
gcloud services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    --project="${PROJECT_ID}"

echo "2. Criando repositório no Artifact Registry..."
gcloud artifacts repositories create cloud-run-demo-repo \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Repositorio Docker para o Cloud Run Demo" \
    --project="${PROJECT_ID}" || echo "Repositório já existe ou ocorreu um erro."

echo "3. Criando Workload Identity Pool..."
gcloud iam workload-identity-pools create "github-actions-pool" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --display-name="GitHub Actions Pool" || echo "Pool já existe ou ocorreu um erro."

echo "4. Criando Workload Identity Provider..."
gcloud iam workload-identity-pools providers create-oidc "github-actions-provider" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="github-actions-pool" \
    --display-name="GitHub Actions Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \

    --attribute-condition="assertion.repository == '${REPO_OWNER}/${REPO_NAME}'" \
    --issuer-uri="https://token.actions.githubusercontent.com" || echo "Provider já existe ou ocorreu um erro."

echo "5. Criando Service Account para deploy..."
gcloud iam service-accounts create "github-actions-deployer" \
    --project="${PROJECT_ID}" \
    --display-name="SA para Deploy via GitHub Actions" || echo "Service account já existe ou ocorreu um erro."

echo "Buscando o número do projeto automaticamente..."
# Captura o Project Number logo no início para usar em todo o script
export PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')

if [ -z "$PROJECT_NUMBER" ]; then
    echo "Erro: Não foi possível obter o número do projeto. Verifique o PROJECT_ID."
    exit 1
fi

echo "6. Vinculando o repositório GitHub à Service Account..."
gcloud iam service-accounts add-iam-policy-binding "github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/${REPO_OWNER}/${REPO_NAME}"

echo "7. Concedendo permissões de IAM para a Service Account..."

# Permissão de escrita no Artifact Registry
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"

# Permissão de administrador do Cloud Run
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/run.admin"

# Permissão para agir como Service Account User nela mesma
gcloud iam service-accounts add-iam-policy-binding "github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.serviceAccountUser" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

# Permissão para agir como Service Account User no Default Compute Service Account (necessário para o Cloud Run)
gcloud iam service-accounts add-iam-policy-binding "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.serviceAccountUser" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"


# Exibe as informações finais que devem ser colocadas nas secrets do GitHub
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider"
SA_EMAIL="github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

echo ""
echo "=========================================================================="
echo " CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!"
echo "=========================================================================="
echo "Agora adicione as seguintes Secrets nas configurações do seu GitHub (Actions Secrets):"
echo ""
echo "1. Nome: GCP_PROJECT_ID"
echo "   Valor: ${PROJECT_ID}"
echo ""
echo "2. Nome: GCP_WIF_PROVIDER"
echo "   Valor: ${WIF_PROVIDER}"
echo ""
echo "3. Nome: GCP_WIF_SERVICE_ACCOUNT"
echo "   Valor: ${SA_EMAIL}"
echo "4. O serviço do Cloud Run foi configurado no workflow do GitHub Actions (.github/workflows/deploy.yml) para:"
echo "   - NÃO ser público (--no-allow-unauthenticated)"
echo "   - Utilizar apenas 1 instância máxima (--max-instances=1)"
echo "   - Utilizar recursos mínimos de CPU/Memória (--cpu=1 --memory=256Mi)"

echo "=========================================================================="

