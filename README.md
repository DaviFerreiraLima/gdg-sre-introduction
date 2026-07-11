#  Tutorial: Deploy no Cloud Run & Monitoramento de Logs com GitHub Actions

Este repositório foi desenvolvido para uma demonstração de como implantar uma aplicação serverless no **Google Cloud Run** usando integração contínua (CI/CD) via **GitHub Actions** com autenticação segura via **Workload Identity Federation (WIF)**, além de como coletar e analisar logs de erro no **Cloud Logging**.

A aplicação foi escrita em Python (Flask) e funciona de maneira autônoma, gerando logs em segundo plano a cada 5 segundos de acordo com as variáveis de ambiente fornecidas.

---

## 📋 Sumário
1. [Sobre a Aplicação](#-sobre-a-aplicação)
2. [Execução Local](#-execução-local)
3. [Configuração do Ambiente GCP (Workload Identity Federation)](#-configuração-do-ambiente-gcp-workload-identity-federation)
4. [Configuração do GitHub Secrets](#-configuração-do-github-secrets)
5. [Pipeline de CI/CD (GitHub Actions)](#-pipeline-de-cicd-github-actions)
6. [Monitoramento e Alertas no Google Cloud](#-monitoramento-e-alertas-no-google-cloud)

---

## ⚙️ Sobre a Aplicação

A aplicação possui um gerador de logs em segundo plano configurado pela variável de ambiente:
- **`GENERATE_ERRORS`**:
  - `true` (ou `1`): Gera logs com gravidade `ERROR` (simulando falhas críticas).
  - `false` (ou vazia): Gera logs comuns de saúde com gravidade `INFO`.

---

## 💻 Execução Local

Você pode validar a aplicação localmente antes de enviá-la para a nuvem.

### Executando com Python 3.9+
1. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```
2. Para simular logs normais:
   ```bash
   export GENERATE_ERRORS=false
   python app.py
   ```
3. Para simular logs de erro:
   ```bash
   export GENERATE_ERRORS=true
   python app.py
   ```

### Executando com Docker
1. Faça o build do container:
   ```bash
   docker build -t cloud-run-demo .
   ```
2. Execute-o definindo a variável de ambiente:
   ```bash
   docker run -p 8080:8080 -e GENERATE_ERRORS=true cloud-run-demo
   ```

---

## ☁️ Configuração do Ambiente GCP (Workload Identity Federation)

Para que o GitHub Actions faça deploy no seu Google Cloud sem expor chaves fixas (arquivos JSON), utilizamos o **Workload Identity Federation (WIF)**. 

Criamos um script automatizador chamado `setup_wif.sh`. Siga os passos abaixo para executá-lo:

1. Abra o arquivo [setup_wif.sh](file:///Users/daviferreiralima/Documents/gdg/gdg-sre-introduction/setup_wif.sh) no editor.
2. Configure as variáveis iniciais com os dados do seu projeto GCP e repositório do GitHub:
   ```bash
   export PROJECT_ID="SEU_PROJECT_ID"
   export REPO_OWNER="SEU_USUARIO_OU_ORGANIZACAO_GITHUB"
   export REPO_NAME="gdg-sre-introduction"
   ```
3. Execute o script no terminal:
   ```bash
   bash setup_wif.sh
   ```

### O que o script realiza de forma automática?
* Ativa as APIs do IAM, Artifact Registry e Cloud Run no seu projeto.
* Cria um repositório Docker privado no Artifact Registry (`cloud-run-demo-repo`).
* Configura o Pool de Identidade (`github-pool`) e Provedor OIDC para o GitHub Actions.
* Cria uma Service Account dedicada ao deploy (`github-actions-deployer`).
* Associa as permissões IAM necessárias à Service Account para permitir compilação de imagem e administração do Cloud Run.

---

## 🔑 Configuração do GitHub Secrets

Após rodar o script anterior, ele exibirá no terminal os valores prontos para copiar. Crie os seguintes segredos em seu repositório no GitHub (`Settings > Secrets and variables > Actions > New repository secret`):

1. **`GCP_PROJECT_ID`**: O ID do seu projeto no GCP.
2. **`GCP_WIF_PROVIDER`**: O recurso completo do provedor OIDC configurado.
3. **`GCP_WIF_SERVICE_ACCOUNT`**: O email da Service Account criada pelo script.

---

## 🛠️ Pipeline de CI/CD (GitHub Actions)

A pipeline está declarada em `.github/workflows/deploy.yml` e dispara automaticamente a cada `git push` na branch `main`.

A pipeline executa os seguintes passos:
1. Faz o checkout do código.
2. Conecta de forma segura com o GCP via OIDC (Workload Identity Federation).
3. Efetua o build do Docker e faz o push para o Artifact Registry.
4. Efetua o deploy/atualização do serviço no **Cloud Run** com as seguintes restrições de segurança e desempenho:
   * **Serviço Privado**: Acesso público desativado (`--no-allow-unauthenticated`).
   * **Instância Reduzida**: Máximo de 1 instância ativa (`--max-instances=1`) para evitar custos inesperados.
   * **Recursos Mínimos**: 1 CPU e 256Mi de memória RAM.

---

## 📊 Monitoramento e Alertas no Google Cloud

A principal utilidade desse setup é demonstrar os recursos de SRE (Site Reliability Engineering) usando a plataforma de monitoramento do Google Cloud:

### 1. Visualizando os Logs
1. Acesse o console do **Google Cloud**.
2. Vá em **Logging > Logs Explorer**.
3. No campo de filtros de recurso, selecione: **Cloud Run Revision > Nome do Serviço (cloud-run-demo)**.
4. Observe as mensagens geradas a cada 5 segundos.

### 2. Alternando entre Sucesso e Falha
Você pode alternar o tipo de log sem precisar rebuildar o container ou subir novo código:
1. Vá até o painel do **Cloud Run** e selecione o serviço `cloud-run-demo`.
2. Clique em **Editar e implantar nova revisão**.
3. Acesse a guia de **Variáveis de Ambiente** e altere `GENERATE_ERRORS` para `true` (ou `false`).
4. Clique em **Implantar**.
5. Vá ao **Logs Explorer** e observe a gravidade dos logs mudando instantaneamente (de `INFO` em azul para `ERROR` em vermelho).

### 3. Criando Alertas de Erro 
No Logs Explorer ou no Cloud Monitoring, você pode demonstrar como criar uma **Log-based Metric** (métrica baseada em logs) para contar a quantidade de logs `ERROR` e, a partir disso, criar um canal de alerta para enviar notificações (por e-mail, Slack ou PagerDuty) sempre que a aplicação começar a falhar.
