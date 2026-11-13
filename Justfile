# Totem Bar for Gamepad

addons := "/Applications/World of Warcraft/_forever_/Interface/AddOns"
dest := addons / "TotemBarForGamepad"

# List the recipes
default:
    @just --list

# Run the offline test suite (default: src; or pass another addon folder)
test dir="src":
    cd test && ./run-all.sh "{{absolute_path(dir)}}"

# Test, then install src into the game's AddOns folder (then /reload in game)
build: test
    @test -d "{{addons}}" || { echo "AddOns folder not found: {{addons}}"; exit 1; }
    rsync -a --delete --exclude .DS_Store src/ "{{dest}}/"
    @echo "Installed to {{dest}}"
