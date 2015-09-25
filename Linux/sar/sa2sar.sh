#!/bin/bash
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.com)
#
# Date: 25.09.2015
#
# Das Skript wird benoetigt, wenn man sa-Dateien fuer kSar aufbereiten moechte.
# Problem ist, das kSar in den Ausgabedateien das Zeitformat europäisch mit 0-23h
# benütigt.
#
unset LANG
S_TIME_FORMAT=ISO ; export S_TIME_FORMAT
sar $*

