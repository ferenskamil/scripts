#!/bin/bash

# Nazwa pakietu do sprawdzenia i instalacji
PACKAGE="apache2"

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# -----------------------------------------------
# Funkcja do zarządzania instalacją i aktualizacją Apache2
# -----------------------------------------------
manage_apache2() {
    echo -e "${YELLOW}--- Rozpoczynanie operacji dla ${PACKAGE} ---${NC}"

    # 1. Sprawdzenie uprawnień root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}BŁĄD: Ten skrypt wymaga uprawnień root (sudo).${NC}"
        return 1 # Zwrócenie niezerowego kodu wyjścia
    fi

    # 2. Aktualizacja listy pakietów
    echo -e "${YELLOW}Aktualizowanie listy pakietów (apt update)...${NC}"
    if ! apt update; then
        echo -e "${RED}BŁĄD: Nie udało się zaktualizować listy pakietów.${NC}"
        return 1
    fi

    # 3. Sprawdzenie, czy pakiet jest zainstalowany
    if dpkg -s $PACKAGE &>/dev/null; then
        # Pakiet jest zainstalowany - aktualizacja
        echo -e "${GREEN}Status: Pakiet '${PACKAGE}' jest już zainstalowany. Rozpoczynanie aktualizacji...${NC}"

        # Aktualizacja pakietu (apt upgrade)
        if apt install --only-upgrade -y $PACKAGE; then
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
        if apt install -y $PACKAGE; then
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

    # Pytanie o adres URL
    read -p "Podaj pełny URL repozytorium do sklonowania (np. https://github.com/user/repo.git): " REPO_URL
    if [ -z "$REPO_URL" ]; then
        echo -e "${RED}Anulowano klonowanie: Adres URL repozytorium nie został podany.${NC}"
        return 0 # Zakończenie etapu, ale bez błędu dla całego skryptu
    fi

    # Pytanie o docelową ścieżkę
    read -p "Podaj ścieżkę docelową do sklonowania (np. /var/www/html/projekt): " TARGET_DIR
    if [ -z "$TARGET_DIR" ]; then
        echo -e "${RED}Anulowano klonowanie: Ścieżka docelowa nie została podana.${NC}"
        return 0
    fi

    # Sprawdzenie, czy katalog docelowy już istnieje
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}Ostrzeżenie: Katalog docelowy '${TARGET_DIR}' już istnieje i NIE jest pusty.${NC}"
        read -r -p "Czy na pewno chcesz kontynuować i sklonować do niego? (t/n): " confirm
        if [[ $confirm != [tT] ]]; then
            echo -e "${RED}Anulowano klonowanie przez użytkownika.${NC}"
            return 0
        fi
    fi

    echo -e "${YELLOW}Klonowanie repozytorium ${REPO_URL} do ${TARGET_DIR}...${NC}"

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