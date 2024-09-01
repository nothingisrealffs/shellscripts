#!/bin/bash

# Define the new values for the EXIF tags
new_tags="New Tags"
new_subject="New Subject"
new_date="2024:09:01 12:00:00"
new_notes="These are new notes."

# Loop through all the images in the current directory
for image in *.jpg; do
  # Update the EXIF tags
  exiftool -Keywords="$new_tags" -Subject="$new_subject" -DateTimeOriginal="$new_date" -UserComment="$new_notes" "$image"
done
