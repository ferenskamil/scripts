#!/bin/bash

# ==============================================================================
# KONFIGURACJA GLOBALNA I DOMYŚLNE WARTOŚCI
# ==============================================================================

# Stałe
PACKAGE="apache2"
PHP_VERSION="8.2"
IP_ADDRESS="127.0.0.1"
HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Zmienne dynamiczne (ustawiane przez użytkownika lub argument)
REPO_URL="${1}" # Użyj pierwszego argumentu skryptu jako domyślnego URL
APP_NAME=""
DOMAIN=""
TARGET_DIR=""

# ==============================================================================
# FUNKCJE INICJALIZUJĄCE
# ==============================================================================

# Weryfikacja wejścia i ustawienie zmiennych globalnych
initial_setup() {
    echo -e "\n${YELLOW}--- ETAP 0.0: Wstępna Konfiguracja ---${NC}"

    # 1. Pobranie adresu URL repozytorium (z argumentu lub interaktywnie)
    if [ -z "${REPO_URL}" ]; then
        read -p "Podaj pełny URL repozytorium do sklonowania (np. https://...): " REPO_URL
    fi

    if [ -z "$REPO_URL" ]; then
        echo -e "${RED}Anulowano: Adres URL repozytorium nie został podany.${NC}"
        return 1
    fi

    # 2. Pobranie nazwy aplikacji
    read -p "Podaj nazwę aplikacji do utworzenia domeny lokalnej (np. myapp): " APP_NAME

    if [ -z "$APP_NAME" ]; then
        echo -e "${RED}Anulowano: Nazwa aplikacji jest pusta.${NC}"
        return 1
    fi

    # 3. Ustawienie zmiennych pochodnych (globalnych)
    DOMAIN="$APP_NAME.local"
    TARGET_DIR="/var/www/localhost/htdocs/$APP_NAME"

    echo -e "${GREEN}Weryfikacja Konfiguracji:${NC}"
    echo -e "  > Nazwa Aplikacji: ${GREEN}$APP_NAME${NC}"
    echo -e "  > Domena Lokalna:  ${GREEN}$DOMAIN${NC}"
    echo -e "  > Katalog Docelowy: ${GREEN}$TARGET_DIR${NC}"
    echo -e "  > URL Repozytorium: ${GREEN}$REPO_URL${NC}"
    return 0
}

# ==============================================================================
# FUNKCJE ETAPÓW INSTALACJI
# ==============================================================================

# Weryfikacja i instalacja podstawowych pakietów systemowych
install_base_packages() {
    echo -e "\n${YELLOW}--- ETAP 1.0: Instalacja Wymaganych Pakietów Systemowych ---${NC}"
    local required_packages="mariadb-server mariadb-client git"

    # 1. Aktualizacja listy pakietów
    echo -e "${YELLOW}Aktualizowanie listy pakietów (apt update)...${NC}"
    sudo apt update || { echo -e "${RED}BŁĄD: Nie udało się zaktualizować listy pakietów.${NC}"; return 1; }

    # 2. Instalacja/Aktualizacja Apache2
    if dpkg -s $PACKAGE &>/dev/null; then
        echo -e "${YELLOW}Aktualizowanie '${PACKAGE}'...${NC}"
        sudo apt install --only-upgrade -y $PACKAGE
    else
        echo -e "${YELLOW}Instalowanie '${PACKAGE}'...${NC}"
        sudo apt install -y $PACKAGE
    fi
    # Systemctl - używamy go tylko w funkcji końcowej configure_apache_vhost

    # 3. Instalacja pozostałych pakietów
    echo -e "${YELLOW}Instalacja MariaDB i Git...${NC}"
    sudo apt install -y $required_packages

    echo -e "${GREEN}Pakiety bazowe i bazy danych zainstalowane/zaktualizowane.${NC}"
    return 0
}

# Instalacja i konfiguracja PHP oraz narzędzi
install_and_configure_php() {
    echo -e "\n${YELLOW}--- ETAP 1.5: Instalacja i Konfiguracja PHP/Zależności ---${NC}"

    # Moduły PHP krytyczne dla Laravela
    local PHP_PACKAGES="php$PHP_VERSION php$PHP_VERSION-cli libapache2-mod-php$PHP_VERSION php$PHP_VERSION-mysql php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-bcmath php$PHP_VERSION-zip composer npm"

    echo -e "${YELLOW}Instalowanie PHP $PHP_VERSION i modułów...${NC}"
    if ! sudo apt install -y $PHP_PACKAGES; then
        echo -e "${RED}BŁĄD: Nie udało się zainstalować wymaganych pakietów PHP/zależności.${NC}"
        return 1
    fi

    # Włączenie modułów Apache
    echo -e "${YELLOW}Włączanie modułów Apache (PHP i Rewrite)...${NC}"
    sudo a2enmod php$PHP_VERSION &>/dev/null
    sudo a2enmod rewrite &>/dev/null

    echo -e "${GREEN}PHP, Composer, NPM i moduły Apache skonfigurowane.${NC}"
    return 0
}

# Klonowanie projektu i wstępna konfiguracja uprawnień
clone_repository() {
    echo -e "\n${YELLOW}--- ETAP 2.0: Klonowanie Repozytorium Git ---${NC}"

    # Wstępne uprawnienia dla tworzenia katalogu
    sudo mkdir -p /var/www/localhost/htdocs
    # Nie używamy 777, wystarczy 755 i poprawne chown

    # Sprawdzenie, czy katalog docelowy już istnieje (uniknięcie błędu klonowania)
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}Ostrzeżenie: Katalog '${TARGET_DIR}' już istnieje - pomijam klonowanie.${NC}"
    else
        echo -e "${YELLOW}Klonowanie ${REPO_URL} do ${TARGET_DIR}...${NC}"
        if ! sudo git clone "$REPO_URL" "$TARGET_DIR"; then
            echo -e "${RED}BŁĄD: Nie udało się sklonować repozytorium. Sprawdź URL i klucze SSH.${NC}"
            return 1
        fi
        echo -e "${GREEN}Repozytorium sklonowane pomyślnie.${NC}"
    fi

    # Ustawienie właściciela - krytyczne dla Apache (www-data)
    sudo chown -R www-data:www-data "$TARGET_DIR"
    echo -e "${YELLOW}Ustawiono właściciela katalogu na www-data.${NC}"
    return 0
}

# Tworzenie, włączanie VirtualHosta Apache i restart usługi
configure_apache_vhost() {
    echo -e "\n${YELLOW}--- ETAP 3.0: Konfiguracja Apache Virtual Host ---${NC}"

    local SERV_CONF_FILENAME="$DOMAIN.conf"
    local SERV_CONF_ERROR_LOG_PATH="/var/log/apache2/${DOMAIN}_error.log"
    local SERV_CONF_CUSTOM_LOG_PATH="/var/log/apache2/${DOMAIN}_access.log"
    local VHOST_PATH="/etc/apache2/sites-available/$SERV_CONF_FILENAME"

    # Definicja pliku VirtualHost
    local SERV_CONF_FILECONTENT=$(cat << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName $DOMAIN
    # DocumentRoot wskazuje na katalog 'public' Laravela
    DocumentRoot $TARGET_DIR/public

    ErrorLog $SERV_CONF_ERROR_LOG_PATH
    CustomLog $SERV_CONF_CUSTOM_LOG_PATH combined

    # Wymagane dla mod_rewrite i .htaccess w Laravelu
    <Directory $TARGET_DIR/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
    # Zapis do pliku
    echo "$SERV_CONF_FILECONTENT" | sudo tee "$VHOST_PATH" > /dev/null
    echo -e "${GREEN}Plik konfiguracyjny '$SERV_CONF_FILENAME' został pomyślnie utworzony.${NC}"

    # Włączenie i restart
    sudo a2ensite "$SERV_CONF_FILENAME" &>/dev/null
    sudo a2dissite 000-default.conf &>/dev/null
    sudo systemctl restart apache2
    sudo systemctl enable apache2
    echo -e "${GREEN}Wirtualny host włączony i Apache zrestartowany.${NC}"
    return 0
}

# Konfiguracja pliku hosts w Windows (dla WSL)
configure_windows_hosts() {
    echo -e "\n${YELLOW}--- ETAP 3.5: Konfiguracja Pliku Hosts (Windows/WSL) ---${NC}"

    local NEW_ENTRY="$IP_ADDRESS $DOMAIN"

    if [ ! -w "$HOSTS_FILE" ]; then
        echo -e "${RED}🚨 UWAGA: Aby edytować plik hosts, wymagane są uprawnienia administratora Windows, i może pojawić się prośba o hasło.${NC}"
    fi

    # 1. Sprawdzenie i usunięcie starego wpisu, jeśli istnieje
    if sudo grep -q "$DOMAIN" "$HOSTS_FILE"; then
        echo -e "${YELLOW}Znaleziono stary wpis dla $DOMAIN. Usuwanie...${NC}"
        sudo sed -i "/$DOMAIN/d" "$HOSTS_FILE"
    fi

    # 2. Dodanie nowego, prawidłowego wpisu
    echo -e "${YELLOW}Dodawanie nowego wpisu: $NEW_ENTRY...${NC}"
    echo "" | sudo tee -a "$HOSTS_FILE" > /dev/null
    echo "# Wirtualny Host - Dodany przez skrypt WSL" | sudo tee -a "$HOSTS_FILE" > /dev/null
    echo "$NEW_ENTRY" | sudo tee -a "$HOSTS_FILE" > /dev/null

    echo -e "${GREEN}Wpis $NEW_ENTRY dodany/zaktualizowany w pliku hosts.${NC}"
    return 0
}

# Finalna konfiguracja projektu Laravel
configure_laravel_project() {
    echo -e "\n${YELLOW}--- ETAP 4.0: Finalizacja Projektu Laravel ---${NC}"

    cd "$TARGET_DIR" || { echo -e "${RED}BŁĄD: Nie można przejść do katalogu projektu ($TARGET_DIR).${NC}"; return 1; }

    # 1. Instalacja Zależności (Composer i NPM)
    echo -e "${YELLOW}Instalacja i aktualizacja zależności Composer...${NC}"
    # Używamy --optimize-autoloader dla produkcji/deweloperki
    composer install --no-interaction --optimize-autoloader || { echo -e "${RED}BŁĄD: Composer install zawiódł.${NC}"; return 1; }

    echo -e "${YELLOW}Instalacja zależności NPM...${NC}"
    npm install || { echo -e "${RED}BŁĄD: NPM install zawiódł.${NC}"; return 1; }

    # 2. Konfiguracja Środowiska (.env)
    if [ ! -f .env ]; then
        cp .env.example .env 2>/dev/null
        echo -e "${GREEN}Utworzono plik .env.${NC}"
    fi

    # 3. Generowanie klucza (krytyczne)
    # --force jest bezpieczne, jeśli plik .env nie jest na serwerze produkcyjnym
    php artisan key:generate --force || { echo -e "${RED}BŁĄD: Nie udało się wygenerować klucza aplikacji (APP_KEY).${NC}"; }
    echo -e "${GREEN}Wygenerowano klucz aplikacji (APP_KEY).${NC}"

    # 4. Poprawa Uprawnień (Właściciel www-data, zapis 775)
    echo -e "${YELLOW}Korekta uprawnień dla kluczowych katalogów (storage, cache)...${NC}"
    sudo chown -R www-data:www-data "$TARGET_DIR"
    sudo chmod -R 775 "$TARGET_DIR/storage"
    sudo chmod -R 775 "$TARGET_DIR/bootstrap/cache"

    echo -e "${GREEN}--- Finalizacja projektu Laravel zakończona pomyślnie ---${NC}"
    return 0
}


# ==============================================================================
# GŁÓWNA FUNKCJA KONTROLUJĄCA PRZEPŁYW
# ==============================================================================

main() {
    echo "
##################################################
## ⚙️  AUTOMATYCZNY SETUP ŚRODOWISKA LARAVEL (WSL)
##################################################
"
    # Faza 1: Wstępna konfiguracja i walidacja
    # Zakończ, jeśli konfiguracja (APP_NAME lub REPO_URL) jest nieprawidłowa
    initial_setup || return 1

    # Faza 2: Instalacje i konfiguracje systemowe
    install_base_packages || return 1
    install_and_configure_php || return 1

    # Faza 3: Repozytorium i Apache
    clone_repository || return 1
    configure_apache_vhost || return 1
    configure_windows_hosts || return 1

    # Faza 4: Konfiguracja Projektu Laravel
    configure_laravel_project || return 1

    # Faza 5: Podsumowanie
    echo "
##################################################
## ✅ SUKCES
##################################################
${GREEN}Twoja aplikacja Laravel jest gotowa pod adresem: http://$DOMAIN${NC}
Projekt znajduje się w: $TARGET_DIR
"
}

# Uruchomienie głównej funkcji
main