#! /bin/bash

echo "Installing invoke & poetry cli tool globally"
pip3 install invoke
pip3 install poetry

echo "Installing dependencies locally for local running / IDE"
inv activate_venv
poetry install

echo "Available commands"
inv -l