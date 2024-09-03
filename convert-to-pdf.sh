#!/bin/bash

# Create a log file
log_file="conversion_log.txt"
echo "Conversion Log" > "$log_file"
echo "----------------" >> "$log_file"

# Create a temporary LaTeX header file
header_file=$(mktemp)
cat << EOF > "$header_file"
\usepackage{graphicx}
\usepackage[export]{adjustbox}
\setbeamertemplate{caption}[numbered]
\setbeamertemplate{caption label separator}{: }
EOF

convert_files() {
    for file in "$1"/*.md
    do
        if [ -f "$file" ]; then
            filename=$(basename "${file%.*}")
            input_dir=$(dirname "$file")
            
            echo "Converting $file to $input_dir/${filename}.pdf"
            
            # Redirect both stdout and stderr to a temporary file
            temp_output=$(mktemp)
            
            # Change to the directory containing the Markdown file before running pandoc
            (cd "$input_dir" && pandoc -t beamer "$(basename "$file")" \
                -o "${filename}.pdf" \
                --include-in-header="$header_file" \
                --variable=links-as-notes \
                -f markdown+link_attributes \
                --lua-filter=<(echo '
                    function Image(elem)
                        elem.attributes.width = elem.attributes.width or "0.8\\textwidth"
                        elem.attributes.center = elem.attributes.center or "true"
                        if elem.attributes.center == "true" then
                            return {
                                pandoc.RawInline("latex", "\\begin{center}"),
                                pandoc.RawInline("latex", "\\includegraphics[width=" .. elem.attributes.width .. "]{" .. elem.src .. "}"),
                                pandoc.RawInline("latex", "\\end{center}")
                            }
                        else
                            return pandoc.RawInline("latex", "\\includegraphics[width=" .. elem.attributes.width .. "]{" .. elem.src .. "}")
                        end
                    end
                ')) > "$temp_output" 2>&1
            
            # Check if the conversion was successful
            if [ $? -eq 0 ]; then
                echo "Successfully converted $file to $input_dir/${filename}.pdf"
                echo "Successfully converted $file to $input_dir/${filename}.pdf" >> "$log_file"
            else
                echo "Error converting $file. Check the log for details."
                echo "Error converting $file:" >> "$log_file"
                cat "$temp_output" >> "$log_file"
                echo "----------------" >> "$log_file"
            fi
            
            # Remove the temporary file
            rm "$temp_output"
        fi
    done

    # Recursively process subdirectories
    for dir in "$1"/*/
    do
        if [ -d "$dir" ]; then
            convert_files "$dir"
        fi
    done
}

# Start the conversion process from the current directory
convert_files "."

echo "All conversions complete! Check $log_file for details."
echo "All conversions complete!" >> "$log_file"

# Remove the temporary header file
rm "$header_file"