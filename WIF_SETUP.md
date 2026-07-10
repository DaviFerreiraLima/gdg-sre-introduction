# Guia de Configuração: Workload Identity Federation (WIF) no GCP

Este guia fornece os comandos necessários da CLI do Google Cloud (`gcloud`) para configurar a federação de identidade (OIDC) entre o GitHub Actions e o Google Cloud Platform (GCP). Isso permite que o GitHub Actions faça deploy com segurança sem usar chaves de Service Account permanentes.

---

## 🛠️ Passo 1: Definir Variáveis

Abra seu terminal e configure as variáveis de ambiente abaixo para facilitar a execução dos comandos:

```bash
export PROJECT_ID="SEU_PROJECT_ID"
export REPO_OWNER="SEU_USUARIO_OU_ORGANIZACAO_GITHUB"
export REPO_NAME="SEU_REPOSITORIO_GITHUB" # ex: "cloud-run-demo"
export REGION="us-central1"
```

---

## 🔑 Passo 2: Ativar as APIs Necessárias

```bash
gcloud services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    --project="${PROJECT_ID}"
```

---

## 📦 Passo 3: Criar Repositório no Artifact Registry

Crie o repositório Docker para armazenar a imagem construída pela pipeline:

```bash
gcloud artifacts repositories create cloud-run-demo-repo \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Repositorio Docker para o Cloud Run Demo" \
    --project="${PROJECT_ID}"
```

---

## 🛡️ Passo 4: Configurar o Workload Identity Federation

### 1. Criar o Pool de Identidade
```bash
gcloud iam workload-identity-pools create "github-pool" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --display-name="GitHub Actions Pool"
```

### 2. Criar o Provedor OIDC para o GitHub
```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --display-name="GitHub Actions Provider" \
    --attribute-mapping="google.subject=assertion.subject,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"
```

---

## 👤 Passo 5: Criar e Vincular a Service Account

### 1. Criar a Service Account dedicada ao deploy
```bash
gcloud iam service-accounts create "github-actions-deployer" \
    --project="${PROJECT_ID}" \
    --display-name="SA para Deploy via GitHub Actions"
```

### 2. Dar permissão para o GitHub Actions se autenticar usando essa Service Account (Binding IAM)
Este comando vincula apenas o repositório especificado ao provedor OIDC criado:

```bash
gcloud iam service-accounts add-iam-policy-binding "github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/attribute.repository/${REPO_OWNER}/${REPO_NAME}"
```

---

## 📝 Passo 6: Dar as Permissões de Deploy à Service Account

Para que a Service Account consiga criar o container e deployar no Cloud Run:

```bash
# 1. Permissão de escrita no Artifact Registry
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"

# 2. Permissão de administrador do Cloud Run
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/run.admin"

# 3. Permissão para agir como a própria service account (User) e associá-la ao container
gcloud iam service-accounts add-iam-policy-binding "github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.serviceAccountUser" \
    --member="serviceAccount:github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
```

---

## ⚙️ Passo 7: Configurar Secrets no GitHub

No repositório do seu projeto no GitHub, navegue em:
`Settings > Secrets and variables > Actions > New repository secret`

Adicione as seguintes Secrets:

1. **`GCP_PROJECT_ID`**: O ID do seu projeto no GCP (ex: `meu-projeto-12345`).
2. **`GCP_WIF_PROVIDER`**: O caminho completo do seu Workload Identity Provider.
   * *Como obter*:
     ```bash
     gcloud iam workload-identity-pools providers describe "github-provider" \
         --project="${PROJECT_ID}" \
         --location="global" \
         --workload-identity-pool="github-pool" \
         --format="value(name)"
     ```
   * *Formato esperado*: `projects/NÚMERO_DO_PROJETO/locations/global/workloadIdentityPools/github-pool/providers/github-provider`
3. **`GCP_WIF_SERVICE_ACCOUNT`**: O email da service account criada.
   * *Formato esperado*: `github-actions-deployer@ID_DO_PROJETO.iam.gserviceaccount.com`
