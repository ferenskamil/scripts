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

# Opcjonalnie: Sprawdzenie kodu wyjścia funkcji
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Skrypt zakończył działanie z sukcesem.${NC}"
else
    echo -e "${RED}Skrypt zakończył działanie z błędami.${NC}"
fi