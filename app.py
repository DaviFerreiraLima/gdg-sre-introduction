import os
import time
import logging
import threading
from flask import Flask, jsonify

# Configuração de logging padrão para o stdout/stderr
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Função executada na thread de segundo plano para gerar logs automaticamente
def log_generator():
    logger.info("Gerador automático de logs iniciado.")
    while True:
        # Lê a variável de ambiente GENERATE_ERRORS (padrão: False)
        generate_errors_env = os.environ.get('GENERATE_ERRORS', 'false').lower()
        should_generate_error = generate_errors_env in ('true', '1', 'yes')
        
        if should_generate_error:
            logger.error("SIMULATION ERROR: Ocorreu um erro interno simulado no processamento em segundo plano.")
        else:
            logger.info("SIMULATION INFO: Aplicação executando tarefas rotineiras sem erros.")
            
        # Espera 5 segundos antes de logar novamente
        time.sleep(5)

# Iniciando a thread de logs em background
bg_thread = threading.Thread(target=log_generator, daemon=True)
bg_thread.start()

# Rota de health check para satisfazer as validações de startup do Cloud Run
@app.route('/')
@app.route('/health')
def health():
    generate_errors_env = os.environ.get('GENERATE_ERRORS', 'false').lower()
    return jsonify({
        "status": "healthy",
        "generate_errors_enabled": generate_errors_env in ('true', '1', 'yes')
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
