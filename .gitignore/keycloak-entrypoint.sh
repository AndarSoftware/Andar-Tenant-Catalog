#!/bin/sh
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
DB_SECRET_FILE="/run/secrets/postgresPassword"
ADMIN_SECRET_FILE="/run/secrets/keycloak_admin_password"
KC_CONFIG_FILE="/opt/keycloak/conf/keycloak.conf"
DB_CONFIG_KEY="db-password"

# --- Database Password Handling (Reads secret and writes to keycloak.conf) ---
echo "Entrypoint: Handling database password..."
if [ -f "$DB_SECRET_FILE" ]; then
    echo "Entrypoint: Database secret file found at $DB_SECRET_FILE."
    DB_PASSWORD=$(cat "$DB_SECRET_FILE" | tr -d '\n')
    mkdir -p /opt/keycloak/conf
    touch "$KC_CONFIG_FILE"
    echo "Entrypoint: Updating $KC_CONFIG_FILE with database password."
    sed -i "/^${DB_CONFIG_KEY}=/d" "$KC_CONFIG_FILE"
    echo "${DB_CONFIG_KEY}=${DB_PASSWORD}" >> "$KC_CONFIG_FILE"
    echo "Entrypoint: Database password configured in $KC_CONFIG_FILE."
else
    echo "Entrypoint: WARNING - Database secret file $DB_SECRET_FILE not found!"
fi

# --- Bootstrap Admin Credentials Handling (Reads env/secret and prepares CLI args) ---
echo "Entrypoint: Handling bootstrap admin credentials..."
# Store original command arguments (e.g., "start")
ORIGINAL_ARGS=("$@")
# Prepare array for potentially modified arguments
MODIFIED_ARGS=("$@")

# Check if admin username env var is set
if [ -n "$KC_BOOTSTRAP_ADMIN_USERNAME" ]; then
    echo "Entrypoint: KC_BOOTSTRAP_ADMIN_USERNAME is set to '$KC_BOOTSTRAP_ADMIN_USERNAME'."

    # Check if admin password secret file exists and is readable
    if [ -f "$ADMIN_SECRET_FILE" ] && [ -r "$ADMIN_SECRET_FILE" ]; then
        echo "Entrypoint: Admin secret file found and readable at $ADMIN_SECRET_FILE."
        # Read password from secret file, removing potential trailing newline
        ADMIN_PASSWORD=$(cat "$ADMIN_SECRET_FILE" | tr -d '\n')

        # Check if password is non-empty (important!)
        if [ -n "$ADMIN_PASSWORD" ]; then
            echo "Entrypoint: Read non-empty admin password from secret file."
            # Add the bootstrap arguments to the command Keycloak will run
            MODIFIED_ARGS+=("--bootstrap-admin-username=${KC_BOOTSTRAP_ADMIN_USERNAME}")
            MODIFIED_ARGS+=("--bootstrap-admin-password=${ADMIN_PASSWORD}")
            echo "Entrypoint: Added --bootstrap-admin-username and --bootstrap-admin-password to command arguments."
        else
            echo "Entrypoint: WARNING - Admin secret file $ADMIN_SECRET_FILE is empty!"
        fi
    else
        echo "Entrypoint: WARNING - Admin secret file $ADMIN_SECRET_FILE not found or not readable. Cannot add bootstrap CLI arguments."
    fi
else
    echo "Entrypoint: KC_BOOTSTRAP_ADMIN_USERNAME environment variable not set. Skipping admin CLI argument injection."
fi

# --- Start Keycloak ---
echo "Entrypoint: Starting Keycloak with potentially modified arguments: ${MODIFIED_ARGS[@]}"
# Execute the original Keycloak entrypoint script or command with the potentially modified arguments
# Use exec to replace the shell process
exec /opt/keycloak/bin/kc.sh "${MODIFIED_ARGS[@]}"
