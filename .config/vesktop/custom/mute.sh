#!/bin/bash
# Mutes ONLY Vesktop's microphone
pactl list source-outputs | grep -B20 "application.name = \"Vesktop\"" | grep "Source Output #" | awk '{print $3}' | xargs -I {} pactl set-source-output-mute {} toggle
