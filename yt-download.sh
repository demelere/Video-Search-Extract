#!/bin/bash

# YouTube Video Downloader Script

# Default configuration variables
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/YouTube"
OUTPUT_FORMAT="%(playlist_index|)s%(playlist_index and ' - ' or '')%(title)s.%(ext)s"
VIDEO_FORMAT="bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"

# Function to validate YouTube URL
is_valid_youtube_url() {
    local url="$1"
    # Basic validation to ensure it looks like a YouTube URL
    [[ "$url" =~ ^https?://(www\.)?(youtube\.com/watch\?v=|youtu\.be/|youtube\.com/playlist\?list=)[a-zA-Z0-9_-]+(&.*)?$ ]]
}

# Function to extract YouTube URL from a line
extract_youtube_url() {
    local line="$1"
    # Extract the first part of the line before the first space
    local url=$(echo "$line" | cut -d' ' -f1)
    echo "$url"
}

# Function to generate unique filename
generate_unique_filename() {
    local base_filename="$1"
    local download_dir="$2"
    local filename="$base_filename"
    local counter=1

    # Split filename into name and extension
    local name="${base_filename%.*}"
    local ext="${base_filename##*.}"

    # Keep incrementing counter until a unique filename is found
    while [[ -f "$download_dir/$filename" ]]; do
        filename="${name}_${counter}.${ext}"
        counter=$((counter + 1))
    done

    echo "$filename"
}

# Function to get user choice with input validation
get_validated_choice() {
    local prompt="$1"
    local valid_choices="$2"
    local choice=""

    while true; do
        read -p "$prompt" choice
        # Convert to uppercase for case-insensitive comparison
        choice="${choice^^}"
        
        # Check if the choice is in the valid choices
        if [[ "$valid_choices" == *"$choice"* ]]; then
            echo "$choice"
            return 0
        fi
        
        echo "Invalid choice. Please try again."
    done
}

# Function to check if URL is a playlist
is_playlist() {
    local url="$1"
    [[ "$url" =~ playlist\?list= ]]
}

# Function to handle potentially invalid URLs
handle_url_validation() {
    local url="$1"
    
    # Check if URL is valid
    if ! is_valid_youtube_url "$url"; then
        echo "Warning: The URL does not match expected YouTube URL format."
        
        # Prompt user to proceed or skip
        local choice=$(get_validated_choice "Do you want to:
[P]roceed with this URL
[S]kip this URL
Enter your choice (P/S): " "PS")

        case "$choice" in
            P)
                echo "Proceeding with potentially invalid URL: $url"
                return 0
                ;;
            S)
                echo "Skipping URL: $url"
                return 1
                ;;
        esac
    fi
    
    return 0
}

# Function to handle existing files and download video
download_video() {
    local url="$1"
    local download_dir="$2"
    local original_filename=""
    local filename=""
    local is_playlist_url=$(is_playlist "$url" && echo "true" || echo "false")

    # If it's a playlist, inform the user
    if [[ "$is_playlist_url" == "true" ]]; then
        echo "Detected playlist URL. Videos will be downloaded with playlist index prefix."
        
        # For playlists, we'll use yt-dlp's playlist handling
        yt-dlp \
            --output "$download_dir/$OUTPUT_FORMAT" \
            --format "$VIDEO_FORMAT" \
            --merge-output-format mkv \
            --write-subs \
            --write-auto-subs \
            --embed-chapters \
            --embed-thumbnail \
            --add-metadata \
            --sponsorblock-mark all \
            --recode-video mkv \
            "$url"
        
        return
    fi

    # For single videos:
    # Dry run to get the filename
    original_filename=$(yt-dlp -o "$OUTPUT_FORMAT" --get-filename "$url")

    # Check if file exists and handle filename collision
    if [[ -f "$download_dir/$original_filename" ]]; then
        echo "File '$original_filename' already exists in $download_dir."
        
        # Get validated choice for file handling
        local choice=$(get_validated_choice "Choose an action: 
[S]kip this video
[R]ename automatically
[O]verwrite
[C]ancel download
Enter your choice (S/R/O/C): " "SROC")

        case "$choice" in
            S)
                echo "Skipping video: $url"
                return
                ;;
            R)
                # Generate a unique filename by adding incremental suffix
                filename=$(generate_unique_filename "$original_filename" "$download_dir")
                echo "Will save as: $filename"
                ;;
            O)
                filename="$original_filename"
                ;;
            C)
                echo "Download cancelled."
                return
                ;;
        esac
    else
        filename="$original_filename"
    fi

    # Download video with chosen filename
    yt-dlp \
        --output "$download_dir/$filename" \
        --format "$VIDEO_FORMAT" \
        --merge-output-format mkv \
        --write-subs \
        --write-auto-subs \
        --embed-chapters \
        --embed-thumbnail \
        --add-metadata \
        --sponsorblock-mark all \
        --recode-video mkv \
        "$url"
}

# Main script
main() {
    local input_file="$1"
    local download_dir=""

    # Get validated choice for download directory
    local dir_choice=$(get_validated_choice "Choose download directory:
[D]efault directory ($DEFAULT_DOWNLOAD_DIR)
[C]urrent directory ($(pwd))
[E]nter custom path
Enter your choice (D/C/E): " "DCE")

    case "$dir_choice" in
        D)
            download_dir="$DEFAULT_DOWNLOAD_DIR"
            mkdir -p "$download_dir"
            ;;
        C)
            download_dir="$(pwd)"
            ;;
        E)
            read -p "Enter full path for download directory: " custom_path
            download_dir="$(eval echo "$custom_path")"
            mkdir -p "$download_dir"
            ;;
    esac

    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file not found!"
        exit 1
    fi

    echo "Downloading to: $download_dir"
    
    # Read the file line by line
    while IFS= read -r line; do
        # Skip empty lines or lines starting with # (comments)
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract YouTube URL
        url=$(extract_youtube_url "$line")
        
        # Handle URL validation
        if handle_url_validation "$url"; then
            echo "Processing: $url"
            download_video "$url" "$download_dir"
            echo "---"
        fi
    done < "$input_file"

    echo "Download process completed."
}

# Check if an input file is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <input_file_with_youtube_links>"
    exit 1
fi

# Run the main function with the input file
main "$1"