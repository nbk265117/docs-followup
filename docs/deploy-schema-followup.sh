#!/bin/bash
# ============================================
# Script de déploiement du schéma Follow Up
# Usage: ./deploy-schema-followup.sh [integ|recette]
# ============================================

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration des environnements
INTEG_HOST="10.211.53.35"
INTEG_PORT="5432"
INTEG_DB="db_followup"
INTEG_USER="pg17_user"
INTEG_PASS="pg17_p@ssw0rd"

RECETTE_HOST="10.211.52.22"
RECETTE_PORT="5432"
RECETTE_DB="db_followup"
RECETTE_USER="pg17_user"
RECETTE_PASS="pg17_p@ssw0rd"

# Chemin du DDL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DDL_FILE="$SCRIPT_DIR/followup-ddl-complet.sql"

usage() {
    echo "Usage: $0 [integ|recette|local]"
    echo ""
    echo "Environnements:"
    echo "  integ   - Déploie sur l'environnement d'intégration (${INTEG_HOST})"
    echo "  recette - Déploie sur l'environnement de recette (${RECETTE_HOST})"
    echo "  local   - Déploie en local (localhost:5432/db_followup)"
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_psql() {
    if ! command -v psql &> /dev/null; then
        log_error "psql n'est pas installé. Installez PostgreSQL client."
        exit 1
    fi
}

check_ddl_file() {
    if [ ! -f "$DDL_FILE" ]; then
        log_error "Fichier DDL non trouvé: $DDL_FILE"
        exit 1
    fi
    log_info "Fichier DDL: $DDL_FILE"
}

deploy_schema() {
    local HOST=$1
    local PORT=$2
    local DB=$3
    local USER=$4
    local PASS=$5
    local ENV_NAME=$6

    log_info "=========================================="
    log_info "Déploiement sur: $ENV_NAME"
    log_info "Host: $HOST:$PORT"
    log_info "Database: $DB"
    log_info "Schema: schema_followup"
    log_info "=========================================="

    # Test de connexion
    log_info "Test de connexion..."
    PGPASSWORD="$PASS" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "SELECT 1;" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_error "Impossible de se connecter à la base de données"
        exit 1
    fi
    log_info "Connexion OK"

    # Vérifier si le schema existe déjà
    SCHEMA_EXISTS=$(PGPASSWORD="$PASS" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'schema_followup');" | tr -d ' ')

    if [ "$SCHEMA_EXISTS" = "t" ]; then
        log_warn "Le schema schema_followup existe déjà."
        read -p "Voulez-vous supprimer et recréer le schema? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Suppression du schema existant..."
            PGPASSWORD="$PASS" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "DROP SCHEMA IF EXISTS schema_followup CASCADE;"
        else
            log_info "Annulation du déploiement."
            exit 0
        fi
    fi

    # Exécution du DDL
    log_info "Exécution du DDL..."
    PGPASSWORD="$PASS" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -f "$DDL_FILE"

    if [ $? -eq 0 ]; then
        log_info "=========================================="
        log_info "Déploiement réussi!"
        log_info "=========================================="

        # Vérification des tables créées
        log_info "Tables créées dans schema_followup:"
        PGPASSWORD="$PASS" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB" -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'schema_followup' ORDER BY table_name;"
    else
        log_error "Erreur lors du déploiement"
        exit 1
    fi
}

# Main
check_psql
check_ddl_file

case "${1:-}" in
    integ)
        deploy_schema "$INTEG_HOST" "$INTEG_PORT" "$INTEG_DB" "$INTEG_USER" "$INTEG_PASS" "INTEGRATION"
        ;;
    recette)
        deploy_schema "$RECETTE_HOST" "$RECETTE_PORT" "$RECETTE_DB" "$RECETTE_USER" "$RECETTE_PASS" "RECETTE"
        ;;
    local)
        deploy_schema "localhost" "5432" "db_followup" "postgres" "followup" "LOCAL"
        ;;
    *)
        usage
        ;;
esac
