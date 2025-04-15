#!/bin/bash
#Published under the MIT licence 


#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Define the path to the boilerplate and the exclusion file
read -p "Enter the directory you would like to use as a complete or relative path." working_directory
cd $working_directory
echo "Working directory is $PWD"
BOILERPLATE="./boilerplate.html"
EXCLUDE_FILE="excludedFiles.txt"

# Check if the boilerplate file exists
if [[ ! -f "$BOILERPLATE" ]]; then
  echo "Error: $BOILERPLATE not found!"
  exit 1
fi

# Check if the exclusion file exists
if [[ ! -f "$EXCLUDE_FILE" ]]; then
  echo "Warning: $EXCLUDE_FILE not found! No files will be excluded."
fi

# Read content from boilerplate's header and nav sections
header_content=$(grep -oP '(?<=<header>).*?(?=</header>)' "$BOILERPLATE")
nav_content=$(grep -oP '(?<=<nav>).*?(?=</nav>)' "$BOILERPLATE")

# Loop through all HTML files in the current directory
for file in *.html; do
  # Skip files listed in the exclude file
  if grep -Fxq "$file" "$EXCLUDE_FILE"; then
    echo "Skipping $file (excluded)"
    continue
  fi

  # Make sure it's an actual HTML file (not the boilerplate file itself)
  if [[ "$file" != "boilerplate.html" && -f "$file" ]]; then
    echo "Updating $file..."

    # Replace the content in <header> and <nav> sections with the content from boilerplate
    # Exclude the title tag from changes
    sed -i '/<title>/!s|<header>.*</header>|<header>$header_content</header>|g' "$file"
    sed -i '/<title>/!s|<nav>.*</nav>|<nav>$nav_content</nav>|g' "$file"

    echo "$file updated."
  fi
done

echo "Script execution completed!"
