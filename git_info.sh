# #!/bin/bash

# # --- Zmienne do przechowywania informacji z Git ---

# # Bieżący branch (nazwa)
# CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# # Krótki hash ostatniego commita
# LAST_COMMIT_HASH_SHORT=$(git rev-parse --short HEAD 2>/dev/null)

# # Pełny hash ostatniego commita
# LAST_COMMIT_HASH_FULL=$(git rev-parse HEAD 2>/dev/null)

# # Autor ostatniego commita
# LAST_COMMIT_AUTHOR=$(git log -1 --pretty=format:'%an' 2>/dev/null)

# # Data ostatniego commita
# LAST_COMMIT_DATE=$(git log -1 --pretty=format:'%cd' --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null)

# # Tytuł ostatniego commita (pierwsza linia)
# LAST_COMMIT_SUBJECT=$(git log -1 --pretty=format:'%s' 2>/dev/null)

# # Adres URL repozytorium zdalnego (origin)
# REMOTE_URL=$(git remote get-url origin 2>/dev/null)

# # Sprawdzenie, czy jesteśmy w repozytorium Git
# if [ -z "$LAST_COMMIT_HASH_SHORT" ]; then
#     echo "🚨 Błąd: Nie jesteś w repozytorium Git."
#     exit 1
# fi

# # --- Wyświetlenie zebranych informacji ---

# echo "--- Informacje o Repozytorium Git ---"
# echo ""
# echo "🚀 Bieżący Branch:   *$CURRENT_BRANCH*"
# echo "🔢 Krótki Hash Commita: *$LAST_COMMIT_HASH_SHORT*"
# echo "🔍 Pełny Hash Commita:  $LAST_COMMIT_HASH_FULL"
# echo "👤 Autor Commita:     $LAST_COMMIT_AUTHOR"
# echo "📅 Data Commita:      $LAST_COMMIT_DATE"
# echo "📝 Opis Commita:      $LAST_COMMIT_SUBJECT"
# echo "🔗 Zdalne Repozytorium: $REMOTE_URL"
# echo ""
# echo "-------------------------------------"

#!/bin/bash

# --- Funkcja pomocnicza do pobierania informacji ---
# Używamy zmiennej lokalnej do przechowywania tagu, jeśli istnieje.
TAG_INFO=$(git describe --tags --exact-match 2>/dev/null)

# Sprawdzenie, czy jesteśmy w repozytorium Git (po raz pierwszy)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "🚨 Błąd: Nie jesteś w repozytorium Git."
    exit 1
fi

# --- Zmienne do przechowywania informacji z Git ---

# Bieżący branch (nazwa) - używamy 'git symbolic-ref' do czystszego sprawdzenia.
# Jeśli jesteśmy w trybie 'detached HEAD', ta komenda zwróci pusty ciąg.
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)

# Krótki hash ostatniego commita (będzie to hash taga, jeśli pod nim jesteśmy)
LAST_COMMIT_HASH_SHORT=$(git rev-parse --short HEAD 2>/dev/null)

# Pełny hash ostatniego commita
LAST_COMMIT_HASH_FULL=$(git rev-parse HEAD 2>/dev/null)

# Autor, Data, Tytuł
LAST_COMMIT_AUTHOR=$(git log -1 --pretty=format:'%an' 2>/dev/null)
LAST_COMMIT_DATE=$(git log -1 --pretty=format:'%cd' --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null)
LAST_COMMIT_SUBJECT=$(git log -1 --pretty=format:'%s' 2>/dev/null)

# Adres URL repozytorium zdalnego (origin)
REMOTE_URL=$(git remote get-url origin 2>/dev/null)


# --- Wyświetlenie zebranych informacji ---

echo "--- ELEARNING ---"
echo ""

# WARUNEK: Sprawdzenie, czy znaleziono dokładny tag
echo "🔗 Repozytorium: $REMOTE_URL"
if [ -n "$TAG_INFO" ]; then
    echo "🎉 Jesteś na Tagu: \"$TAG_INFO\""
    echo "🔍 Detached HEAD (wskazuje na tag)"
    echo "🔢 Hash Commita (Taga): \"$LAST_COMMIT_HASH_SHORT\""
    echo ""
else
    # Jeśli nie ma taga, wyświetlamy normalny branch
    if [ -n "$CURRENT_BRANCH" ]; then
        echo "🚀 Bieżący Branch:   \"$CURRENT_BRANCH\""
        echo "🔢 Krótki Hash Commita: \"$LAST_COMMIT_HASH_SHORT\""
    else
        # Obsługa 'detached HEAD' niebędącego tagiem (np. checkout na sam hash commita)
        echo "⚠️ Detached HEAD (Nie na branchu ani na tagu)"
        echo "🔢 Krótki Hash Commita: \"$LAST_COMMIT_HASH_SHORT\""
    fi
fi

echo "🔍 Pełny Hash Commita:  $LAST_COMMIT_HASH_FULL"
# echo "👤 Autor Commita:     $LAST_COMMIT_AUTHOR"
echo "📅 Data Commita:        $LAST_COMMIT_DATE"
echo "📝 Opis Commita:        $LAST_COMMIT_SUBJECT"
echo ""
echo "-------------------------------------"