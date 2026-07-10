# Usar uma imagem base leve do Python
FROM python:3.11-slim

# Evitar que o Python grave arquivos .pyc no disco
ENV PYTHONDONTWRITEBYTECODE=1

# Impedir que o Python armazene em buffer stdout e stderr (importante para Cloud Logging)
ENV PYTHONUNBUFFERED=1

# Definir diretório de trabalho
WORKDIR /app

# Instalar dependências
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar o código fonte do projeto
COPY . .

# Expõe a porta padrão que o Cloud Run usa
EXPOSE 8080

# Comando para rodar com gunicorn, ouvindo na porta especificada pela env PORT
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app:app
