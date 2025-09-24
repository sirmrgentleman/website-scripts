#!/bin/bash
#Published under the MIT licence 


#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Get the boilerplate file location (one level up)
read -p "Enter the directory you would like to use as a complete or relative path." working_directory
cd $working_directory || { echo "Directory is not valid! Exiting."; exit 1; }
echo "Working directory is $PWD"
BOILERPLATE="./boilerplate.html"

# Check if the boilerplate exists
if [[ ! -f "$BOILERPLATE" ]]; then
  echo "Error: $BOILERPLATE not found!"
  exit 1
fi

# Prompt for the new filename
read -p "Enter the name of the new file (e.g., newpage.html): " new_filename

# Prompt for the title of the page
read -p "Enter the title of the page: " page_title

# Copy the boilerplate file to the new file
cp "$BOILERPLATE" "$new_filename"

# Replace the title in the new file
sed -i "s|<title>.*</title>|<title>$page_title</title>|g" "$new_filename"

# If the user wants a custom stylesheet
if [[ "$custom_stylesheet" == "y" || "$custom_stylesheet" == "Y" ]]; then
  read -p "Enter the name of the stylesheet file (e.g., style.css): " stylesheet_name
  # Add a link to the stylesheet in the <head> section
  sed -i "s|</head>|  <link rel=\"stylesheet\" type=\"text/css\" href=\"$stylesheet_name\">\n</head>|" "$new_filename"
fi

echo "New page created: $new_filename"