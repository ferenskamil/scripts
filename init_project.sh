#!/bin/bash

# Nazwa pakietu do sprawdzenia i instalacji
PACKAGE="apache2"

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color


read -p "Podaj nazwę aplikacja do utworzenia domeny lokalnej (np. app.local):
"  APP_NAME
if [ -z "$APP_NAME" ]; then
    echo -e "${RED}Anulowano: Domena \"$APP_NAME\" nieprawidłowa.${NC}"
    return 0 # Zakończenie etapu, ale bez błędu dla całego skryptu
fi

#domain
DOMAIN="$APP_NAME.local";

# ścieżka docelowa projektu
TARGET_DIR="/var/www/localhost/htdocs/$APP_NAME"

# Ścieżka do pliku hosts w systemie Windows (dostępna przez WSL)
HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

# ip - localhost
IP_ADDRESS="127.0.0.1"

# Pytanie o adres URL
# read -p "Podaj pełny URL repozytorium do sklonowania (np. https://github.com/user/repo.git):
# " REPO_URL
# if [ -z "$REPO_URL" ]; then
#     echo -e "${RED}Anulowano klonowanie: Adres URL repozytorium nie został podany.${NC}"
#     return 0 # Zakończenie etapu, ale bez błędu dla całego skryptu
# fi
REPO_URL="git@github.com:ferenskamil/home-budget-app.git"



# -----------------------------------------------
# Instalacje
# -----------------------------------------------
sudo apt install composer
sudo apt install npm
sudo apt install -y php8.2-mysql


#mariadb
# Instalacja serwera MariaDB oraz klienta
sudo apt install -y mariadb-server mariadb-client
sudo systemctl enable mariadb
sudo systemctl start mariadb

# -----------------------------------------------
# Nowa funkcja do zarządzania zależnościami (w tym PHP)
# -----------------------------------------------
manage_dependencies() {
    echo -e "\n${YELLOW}--- ETAP 1.5: Instalacja i konfiguracja PHP/Zależności ---${NC}"

    # Lista wymaganych pakietów PHP dla Laravel (dla Ubuntu 20.04+)
    PHP_VERSION="8.2" # Dostosuj wersję PHP jeśli potrzebujesz innej
    PHP_PACKAGES="php$PHP_VERSION php$PHP_VERSION-cli php$PHP_VERSION-common libapache2-mod-php$PHP_VERSION php$PHP_VERSION-mysql php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-bcmath php$PHP_VERSION-zip"

    echo -e "${YELLOW}Instalowanie PHP i modułów...${NC}"
    # Zapewnienie, że repozytorium jest dostępne, jeśli używamy nowszej wersji PHP
    # sudo add-apt-repository ppa:ondrej/php -y
    # sudo apt update

    if sudo apt install -y $PHP_PACKAGES composer npm; then
        echo -e "${GREEN}Sukces: PHP, Composer i NPM zostały pomyślnie zainstalowane.${NC}"
    else
        echo -e "${RED}BŁĄD: Nie udało się zainstalować wymaganych pakietów PHP/zależności. Sprawdź, czy wersja PHP jest poprawna.${NC}"
        return 1
    fi

    # Włączenie modułu PHP dla Apache (jeśli się nie włączył automatycznie)
    if a2enmod php$PHP_VERSION; then
        echo -e "${GREEN}Włączono moduł PHP $PHP_VERSION w Apache.${NC}"
    fi

    # Włączenie modułu PHP dla Apache
    if a2enmod php$PHP_VERSION; then
        echo -e "${GREEN}Włączono moduł PHP $PHP_VERSION w Apache.${NC}"
        sudo systemctl restart apache2 # <--- DODAJ TO
    fi

    # Włączenie mod_rewrite (KRYTYCZNE dla Laravel)
    if a2enmod rewrite; then # Zmień na 'if a2enmod' dla czystszego kodu
        echo -e "${GREEN}Włączono moduł mod_rewrite.${NC}"
        sudo systemctl restart apache2 # <--- DODAJ TO
    else
        echo -e "${RED}BŁĄD: Nie udało się włączyć modułu mod_rewrite.${NC}"
        return 1
    fi


    # Włączenie mod_rewrite (KRYTYCZNE dla Laravel)
    if ! a2enmod rewrite; then
        echo -e "${RED}BŁĄD: Nie udało się włączyć modułu mod_rewrite.${NC}"
        return 1
    fi

    echo -e "${YELLOW}--- Konfiguracja Zależności zakończona pomyślnie ---${NC}"
    return 0
}


# -----------------------------------------------
# Funkcja do zarządzania instalacją i aktualizacją Apache2
# -----------------------------------------------
manage_apache2() {
    echo -e "${YELLOW}--- Rozpoczynanie operacji dla ${PACKAGE} ---${NC}"

    # # 1. Sprawdzenie uprawnień root
    # if [ "$(id -u)" -ne 0 ]; then
    #     echo -e "${RED}BŁĄD: Ten skrypt wymaga uprawnień root (sudo).${NC}"
    #     return 1 # Zwrócenie niezerowego kodu wyjścia
    # fi

    # 2. Aktualizacja listy pakietów
    echo -e "${YELLOW}Aktualizowanie listy pakietów (apt update)...${NC}"
    if ! sudo apt update; then
        echo -e "${RED}BŁĄD: Nie udało się zaktualizować listy pakietów.${NC}"
        return 1
    fi

    # 3. Sprawdzenie, czy pakiet jest zainstalowany
    if dpkg -s $PACKAGE &>/dev/null; then
        # Pakiet jest zainstalowany - aktualizacja
        echo -e "${GREEN}Status: Pakiet '${PACKAGE}' jest już zainstalowany. Rozpoczynanie aktualizacji...${NC}"

        # Aktualizacja pakietu (apt upgrade)
        if sudo apt install --only-upgrade -y $PACKAGE; then
            echo -e "${GREEN}Sukces: Pakiet '${PACKAGE}' został pomyślnie zaktualizowany.${NC}"

            # Opcjonalnie: restart usługi po aktualizacji (częsta praktyka)
            echo -e "${YELLOW}Sprawdzanie statusu i ewentualny restart usługi...${NC}"
            systemctl restart $PACKAGE
        else
            echo -e "${RED}BŁĄD: Nie udało się zaktualizować pakietu '${PACKAGE}'.${NC}"
            return 1
        fi
    else
        # Pakiet nie jest zainstalowany - instalacja
        echo -e "${YELLOW}Status: Pakiet '${PACKAGE}' nie jest zainstalowany. Rozpoczynanie instalacji...${NC}"

        # Instalacja pakietu
        if sudo apt install -y $PACKAGE; then
            echo -e "${GREEN}Sukces: Pakiet '${PACKAGE}' został pomyślnie zainstalowany.${NC}"

            # Włączenie i uruchomienie usługi po instalacji
            echo -e "${YELLOW}Włączanie i uruchamianie usługi apache2...${NC}"
            systemctl enable $PACKAGE
            systemctl start $PACKAGE
        else
            echo -e "${RED}BŁĄD: Nie udało się zainstalować pakietu '${PACKAGE}'.${NC}"
            return 1
        fi
    fi

    echo -e "${YELLOW}--- Operacja zakończona pomyślnie ---${NC}"
    return 0
}

# -----------------------------------------------
# Nowa funkcja do klonowania repozytorium Git
# -----------------------------------------------
clone_repository() {
    echo -e "\n${YELLOW}--- ETAP 2: Klonowanie Repozytorium Git ---${NC}"

    # Sprawdzenie, czy Git jest zainstalowany
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Narzędzie 'git' nie zostało znalezione. Instalowanie...${NC}"
        apt install -y git || { echo -e "${RED}BŁĄD: Nie udało się zainstalować Git.${NC}"; return 1; }
    fi

    # Sprawdzenie, czy katalog docelowy już istnieje
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}Ostrzeżenie: Katalog docelowy '${TARGET_DIR}' już istnieje i NIE jest pusty.${NC}"
        read -r -p "Czy na pewno chcesz kontynuować i sklonować do niego? (t/n):
        " confirm
        if [[ $confirm != [tT] ]]; then
            echo -e "${RED}Anulowano klonowanie przez użytkownika.${NC}"
            return 0
        fi
    fi

    echo -e "${YELLOW}Klonowanie repozytorium ${REPO_URL} do ${TARGET_DIR}...${NC}"

    # uprawnienia
    sudo chmod -R 777 /var/www

    # Wykonanie klonowania
    if git clone "$REPO_URL" "$TARGET_DIR"; then
        echo -e "${GREEN}Sukces: Repozytorium zostało pomyślnie sklonowane.${NC}"
        # Ustawienie odpowiednich uprawnień dla katalogu webowego (często przydatne)
        if [ -d "/var/www" ]; then
            chown -R www-data:www-data "$TARGET_DIR" 2>/dev/null
            echo -e "${YELLOW}Ustawiono właściciela katalogu na www-data (jeśli istnieje).${NC}"
        fi

    else
        echo -e "${RED}BŁĄD: Nie udało się sklonować repozytorium. Sprawdź URL i uprawnienia SSH/HTTPS.${NC}"
        return 1
    fi

    echo -e "${YELLOW}--- Klonowanie zakończone pomyślnie ---${NC}"
    return 0
}

# -----------------------------------------------
# Główna część skryptu - wywołanie funkcji
# -----------------------------------------------
echo "
##############################
##
## Instalacja/aktualizacja apache2
##
##############################
"
manage_apache2
APACHE_STATUS=$?

echo "
##############################
##
## Instalacja PHP i zależności
##
##############################
"
if [ $APACHE_STATUS -eq 0 ]; then
    manage_dependencies
    DEPENDENCY_STATUS=$?
else
    echo -e "${RED}Pominięto instalację zależności, ponieważ zarządzanie Apache2 zakończyło się błędem.${NC}"
    DEPENDENCY_STATUS=1
fi

echo "
##############################
##
## Klonowanie repozytorium
##
##############################
"
# Jeśli Apache2 się powiódł, przechodzimy do klonowania
if [ $APACHE_STATUS -eq 0 ]; then
    clone_repository
    GIT_STATUS=$?
else
    # Jeśli instalacja Apache2 się nie powiodła, klonowanie nie ma sensu
    echo -e "${RED}Pominięto klonowanie, ponieważ zarządzanie Apache2 zakończyło się błędem.${NC}"
    GIT_STATUS=1
fi

# Opcjonalnie: Sprawdzenie końcowego kodu wyjścia skryptu
if [ $APACHE_STATUS -eq 0 ] && [ $GIT_STATUS -eq 0 ]; then
    echo -e "\n${GREEN}Skrypt zakończył działanie z sukcesem na wszystkich etapach.${NC}"
else
    echo -e "\n${RED}Skrypt zakończył działanie z błędami w jednym lub więcej etapach.${NC}"
fi

# -----
# W projekcie
# -----

cd $TARGET_DIR

#composer
composer install
composer update

#npm
npm install

# # Uprawnienia dla www-data
# sudo chown -R www-data:www-data $TARGET_DIR/public
# sudo chmod -R 755 /var/www


# Użyj chown dla całego katalogu projektu po klonowaniu
sudo chown -R www-data:www-data "$TARGET_DIR"

# Ustaw uprawnienia zapisu dla katalogów storage i bootstrap/cache (KRYTYCZNE dla Laravela!)
sudo chmod -R 775 "$TARGET_DIR/storage"
sudo chmod -R 775 "$TARGET_DIR/bootstrap/cache"


#-------------
# konfiguracja serwera
#-------------
SERV_CONF_FILENAME="$DOMAIN.conf"
SERV_CONF_ERROR_LOG_PATH="/var/log/apache2/${DOMAIN}_error.log"
SERV_CONF_CUSTOM_LOG_PATH="/var/log/apache2/${DOMAIN}_access.log"
SERV_CONF_FILECONTENT=$(cat << EOF
<VirtualHost *:8080>
    ServerAdmin webmaster@localhost
    # Kluczowe dyrektywy:
    ServerName $DOMAIN
 #   ServerAlias www.$DOMAIN
    DocumentRoot $TARGET_DIR/public

    ErrorLog $SERV_CONF_ERROR_LOG_PATH
    CustomLog $SERV_CONF_CUSTOM_LOG_PATH combined

    # Jeśli używasz .htaccess (np. dla ładnych URL-i), dodaj:
    <Directory $TARGET_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)

# Weryfikacja (zawsze w cudzysłowach, żeby zachować formatowanie)
echo "--- Zweryfikowana i rozwinięta treść zmiennej ---"
echo "$SERV_CONF_FILECONTENT"
echo "-------------------------------------------------"

# Zapis do pliku
echo "$SERV_CONF_FILECONTENT" | sudo tee /etc/apache2/sites-available/$SERV_CONF_FILENAME > /dev/null

echo "✅ Plik konfiguracyjny został pomyślnie utworzony."


# Włączenie wirtualnego hosta: Użyj narzędzia a2ensite i wyłącz domyślny host, aby uniknąć konfliktów.
sudo a2ensite $DOMAIN.conf
sudo a2dissite 000-default.conf # Opcjonalne, ale zalecane

# restart apache
sudo systemctl restart apache2


#-------------------
# konfiguracja wirtualnego hosta
#------------------
# Wymagane uprawnienia administratora do edycji pliku hosts
if [ ! -w "$HOSTS_FILE" ]; then
    echo "🚨 UWAGA: Aby edytować plik hosts, wymagane są uprawnienia administratora Windows."
fi

# Tworzenie wpisu, którego szukamy
NEW_ENTRY="$IP_ADDRESS $DOMAIN"

# 1. Sprawdzenie, czy domena już istnieje
# Używamy grep -q, aby sprawdzić, czy linia jest obecna, bez wyświetlania jej
if grep -q "$DOMAIN" "$HOSTS_FILE"; then

    # Domena została znaleziona

    # Sprawdzenie, czy linia jest DOKŁADNIE taka, jakiej oczekujemy (IP + DOMENA)
    if grep -q "^$IP_ADDRESS[[:space:]]\+$DOMAIN$" "$HOSTS_FILE"; then
        echo "✅ Sukces: Wpis dla $DOMAIN (z IP $IP_ADDRESS) już istnieje i jest poprawny. Nie wprowadzono zmian."

    else
        # Domena jest, ale ma inny adres IP lub format. Usuwamy starą i dodajemy nową.
        echo "🔄 Aktualizacja: Znaleziono starszy/inny wpis dla $DOMAIN."

        # Usuwamy starą linię z użyciem sudo i sed, aby mieć pewność uprawnień
        sudo sed -i "/$DOMAIN/d" "$HOSTS_FILE"

        # Dodajemy nowy, prawidłowy wpis
        echo "$NEW_ENTRY" | sudo tee -a "$HOSTS_FILE" > /dev/null
        echo "✅ Zaktualizowano: Usunięto stary wpis i dodano nowy: $NEW_ENTRY"
    fi

else
    # Domena nie została znaleziona - dodajemy nowy wpis

    echo "🆕 Dodawanie: Wpis dla $DOMAIN nie został znaleziony."

    # Dodajemy nowy wpis
    echo "" | sudo tee -a "$HOSTS_FILE" > /dev/null # Dodanie pustej linii dla czystości
    echo "# Wirtualny Host - Dodany przez skrypt WSL" | sudo tee -a "$HOSTS_FILE" > /dev/null
    echo "$NEW_ENTRY" | sudo tee -a "$HOSTS_FILE" > /dev/null

    echo "✅ Zakończono: Nowy wpis $NEW_ENTRY został dodany do pliku hosts."
fi


# ...
# Koniec sekcji sprawdzania statusów:
if [ $APACHE_STATUS -eq 0 ] && [ $GIT_STATUS -eq 0 ]; then
    echo -e "\n${GREEN}--- ETAP 4: Finalizacja Projektu Laravel ---${NC}"

    # Wymagane: Upewnij się, że jesteś w katalogu projektu
    cd "$TARGET_DIR" || { echo -e "${RED}BŁĄD: Nie można przejść do katalogu projektu ($TARGET_DIR).${NC}"; exit 1; }

    ## 1. Instalacja Zależności
    echo -e "${YELLOW}Instalacja zależności Composer...${NC}"
    # Użycie --no-interaction dla automatycznego potwierdzania

    sudo chmod 777 -R ./
    composer update --no-interaction || { echo -e "${RED}BŁĄD: Composer install zawiódł.${NC}"; exit 1; }

    echo -e "${YELLOW}Instalacja zależności NPM...${NC}"
    npm install || { echo -e "${RED}BŁĄD: NPM install zawiódł.${NC}"; exit 1; }

    ## 2. Konfiguracja Środowiska (.env)

    # 2.1 Kopiowanie .env (naprawia błąd "No such file or directory")
    if [ ! -f .env ]; then
        cp .env.example .env 2>/dev/null
        echo -e "${GREEN}Utworzono plik .env.${NC}"
    fi

    # 2.2 Generowanie klucza aplikacji (krytyczne dla Laravela)
    # Wywołanie musi być wykonane przez PHP w konsoli, co jest automatyczne w 'artisan'
    php artisan key:generate || { echo -e "${RED}BŁĄD: Nie udało się wygenerować klucza aplikacji (APP_KEY).${NC}"; }
    echo -e "${GREEN}Wygenerowano klucz aplikacji (APP_KEY).${NC}"

    # Opcjonalnie: Uruchomienie migracji
    # php artisan migrate --force 2>/dev/null


    ## 3. Poprawa Uprawnień (Naprawia błąd "Permission denied")

    echo -e "${YELLOW}Korekta uprawnień dla katalogu projektu (storage, cache, logi)...${NC}"

    # 3.1 Zmiana właściciela wszystkich plików na www-data (użytkownik Apache)
    # Dodatkowo przekazujemy uprawnienia dla bieżącego użytkownika ($USER), aby mógł pracować na plikach
    sudo chown -R www-data:www-data "$TARGET_DIR"

    # 3.2 Ustawienie uprawnień zapisu (775) dla kluczowych katalogów
    sudo chmod -R 775 "$TARGET_DIR/storage"
    sudo chmod -R 775 "$TARGET_DIR/bootstrap/cache"

    # Jeśli nadal masz błąd w WSL, to dodanie setfacl jest najlepszym rozwiązaniem:
    # Umożliwia grupie i właścicielowi (www-data) oraz innym użytkownikom (Tobie) pełny dostęp
    # sudo setfacl -R -m u:www-data:rwx "$TARGET_DIR/storage"
    # sudo setfacl -R -m u:www-data:rwx "$TARGET_DIR/bootstrap/cache"


    echo -e "${GREEN}--- Finalizacja projektu zakończona pomyślnie ---${NC}"

else
    echo -e "\n${RED}Skrypt zakończył działanie z błędami w jednym lub więcej etapach. Finalizacja projektu pominięta.${NC}"
fi

# ...


# Ustawia www-data jako właściciela (user) i grupę (group) katalogu projektu
sudo chown -R www-data:www-data /var/www/localhost/htdocs/$APP_NAME

# Nadaje uprawnienia zapisu (775) dla katalogów storage i cache
sudo chmod -R 775 /var/www/localhost/htdocs/$APP_NAME/storage
sudo chmod -R 775 /var/www/localhost/htdocs/$APP_NAME/bootstrap/cache

#!!!! notatka - to było potrzebne na samym kończu gdy wyświetlał kod phpa zamiast go wykonywać
# sudo apt install -y libapache2-mod-php8.1
# sudo a2enmod php8.1
