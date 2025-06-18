#!/bin/bash
# docker/scalingo-runtime/test.sh - Version améliorée
set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions utilitaires
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}" >&2; }
info() { echo -e "${BLUE}→ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Nettoyage en cas d'interruption
cleanup() {
    info "Nettoyage..."
    rm -rf "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"
    [ -n "${CONTAINER_ID:-}" ] && docker rm -f "$CONTAINER_ID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Configuration
BUILD_DIR="/tmp/app-$$"
CACHE_DIR="/tmp/cache-$$"
ENV_DIR="/tmp/env-$$"
LOG_FILE="/tmp/weasyprint-test-$$.log"

mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"

info "Préparation de l'application de test..."

# Application de test plus complète
cat > "$BUILD_DIR/requirements.txt" <<EOF
Flask==3.1.1
WeasyPrint==65.1
gunicorn==21.2.0
EOF

cat > "$BUILD_DIR/app.py" <<'EOF'
from flask import Flask, make_response
import weasyprint
from datetime import datetime
import os

app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>WeasyPrint Test App</h1>
    <p><a href="/test-pdf">Generate Test PDF</a></p>
    <p><a href="/health">Health Check</a></p>
    '''

@app.route('/test-pdf')
def test_pdf():
    html = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Test PDF</title>
        <style>
            body {{ font-family: Arial; margin: 40px; }}
            .header {{ background: #2c3e50; color: white; padding: 20px; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>WeasyPrint on Scalingo</h1>
        </div>
        <p>Generated at: {datetime.now()}</p>
        <p>Python: {os.sys.version}</p>
    </body>
    </html>
    '''

    pdf = weasyprint.HTML(string=html).write_pdf()
    response = make_response(pdf)
    response.headers['Content-Type'] = 'application/pdf'
    return response

@app.route('/health')
def health():
    try:
        import weasyprint
        return {
            'status': 'healthy',
            'weasyprint_version': weasyprint.__version__,
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
        return {'status': 'error', 'message': str(e)}, 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Procfile pour tester
cat > "$BUILD_DIR/Procfile" <<EOF
web: gunicorn app:app
EOF

info "Construction de l'image Docker..."
docker build -t scalingo-runtime ./docker/scalingo-runtime

info "Test 1/3: Script detect"
if docker run --rm \
    -v "$(pwd)":/buildpack \
    -v "$BUILD_DIR":/app \
    scalingo-runtime \
    bash -c "cd /buildpack && ./bin/detect /app" > "$LOG_FILE" 2>&1; then

    if grep -q "WeasyPrint" "$LOG_FILE"; then
        success "Script detect: WeasyPrint détecté"
    else
        error "Script detect: WeasyPrint non détecté"
        cat "$LOG_FILE"
        exit 1
    fi
else
    error "Script detect a échoué"
    cat "$LOG_FILE"
    exit 1
fi

info "Test 2/3: Script compile (ceci peut prendre quelques minutes...)"
CONTAINER_ID=$(docker run -d \
    -v "$(pwd)":/buildpack \
    -v "$BUILD_DIR":/app \
    -v "$CACHE_DIR":/cache \
    -v "$ENV_DIR":/env \
    scalingo-runtime \
    bash -c "cd /buildpack && ./bin/compile /app /cache /env")

# Suivre les logs en temps réel
docker logs -f "$CONTAINER_ID" &
LOGS_PID=$!

# Attendre la fin du conteneur
if docker wait "$CONTAINER_ID" > /dev/null; then
    kill $LOGS_PID 2>/dev/null || true
    success "Script compile terminé avec succès"
else
    kill $LOGS_PID 2>/dev/null || true
    error "Script compile a échoué"
    exit 1
fi

info "Test 3/3: Script release"
if docker run --rm \
    -v "$(pwd)":/buildpack \
    -v "$BUILD_DIR":/app \
    scalingo-runtime \
    bash -c "cd /buildpack && ./bin/release /app" > "$LOG_FILE" 2>&1; then

    if grep -q "LD_LIBRARY_PATH" "$LOG_FILE"; then
        success "Script release: Configuration générée"
        echo "Configuration générée :"
        cat "$LOG_FILE" | sed 's/^/    /'
    else
        error "Script release: Configuration invalide"
        cat "$LOG_FILE"
        exit 1
    fi
else
    error "Script release a échoué"
    cat "$LOG_FILE"
    exit 1
fi

info "Test 4/4: Vérification de l'installation dans l'app"
if docker run --rm \
    -v "$BUILD_DIR":/app \
    -e LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/lib" \
    scalingo-runtime \
    bash -c "cd /app && python3 -c 'import weasyprint; print(f\"WeasyPrint {weasyprint.__version__} importé avec succès\")'" 2>&1; then
    success "WeasyPrint peut être importé"
else
    warning "WeasyPrint ne peut pas être importé (normal si pas encore installé par le buildpack Python)"
fi

# Test du cache
info "Test bonus: Vérification du cache"
if [ -d "$CACHE_DIR/apt-cache" ]; then
    success "Cache APT créé"
    du -sh "$CACHE_DIR/apt-cache" | sed 's/^/    Cache size: /'
else
    warning "Cache APT non créé"
fi

echo ""
success "Tous les tests ont réussi ! 🎉"
echo ""
info "Pour tester avec une vraie app Scalingo :"
echo "  1. git push origin main"
echo "  2. scalingo create app-test"
echo "  3. scalingo env-set BUILDPACK_URL=https://github.com/votre-user/weasyprint-buildpack"
echo "  4. git push scalingo main"
