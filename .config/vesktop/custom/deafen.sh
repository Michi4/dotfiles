#!/bin/bash
# Mutes MIC
pactl -f json list source-outputs | jq -r '.[] | select(.properties["application.name"] == "Vesktop" or .properties["application.process.binary"] == "vesktop") | .index' | xargs -I {} pactl set-source-output-mute {} toggle

# Mutes SOUND
pactl -f json list sink-inputs | jq -r '.[] | select(.properties["application.name"] == "Vesktop" or .properties["application.process.binary"] == "vesktop") | .index' | xargs -I {} pactl set-sink-input-mute {} toggle
