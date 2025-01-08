#!/bin/bash

# Check for required commands
for cmd in pandoc pdflatex; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        if command -v apt-get &> /dev/null; then
            echo "Run: sudo apt-get install $cmd texlive-latex-base"
        elif command -v dnf &> /dev/null; then
            echo "Run: sudo dnf install $cmd texlive-scheme-basic"
        elif command -v pacman &> /dev/null; then
            echo "Run: sudo pacman -S $cmd texlive-basic"
        elif command -v zypper &> /dev/null; then
            echo "Run: sudo zypper install $cmd texlive-latex-base"
        else
            echo "Please install $cmd using your package manager"
        fi
        exit 1
    fi
done

log_file="conversion_log.txt"
echo "Conversion Log" > "$log_file"
echo "----------------" >> "$log_file"
failed=0

find . -type f -name "*.md" ! -name "readme.md" ! -name "README.md" | while read file; do
    filename=$(basename "${file%.*}")
    input_dir=$(dirname "$file")
    
    echo "Converting $file to $input_dir/${filename}.pdf"
    temp_output=$(mktemp)
    
    if (cd "$input_dir" && pandoc -t beamer "$(basename "$file")" -o "${filename}.pdf" \
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
        ')) 2>&1 >"$temp_output"; then
        echo "Successfully converted $file to $input_dir/${filename}.pdf"
        echo "Successfully converted $file to $input_dir/${filename}.pdf" >> "$log_file"
    else
        failed=1
        echo "Error converting $file. Error output:" | tee -a "$log_file"
        cat "$temp_output" | tee -a "$log_file"
        echo "----------------" | tee -a "$log_file"
    fi
    
    rm "$temp_output"
done

if [ $failed -eq 0 ]; then
    echo "All conversions complete!" | tee -a "$log_file"
else 
    echo "Some conversions failed. Check log for details." | tee -a "$log_file"
    exit 1
fi
