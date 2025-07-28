#!/bin/bash

# YouTube Video Downloader Script

# Default configuration variables
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/YouTube"
OUTPUT_FORMAT="%(playlist_index|)s%(playlist_index and ' - ' or '')%(title)s.%(ext)s"
VIDEO_FORMAT="bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"

# Workflow flags
H264_MODE=false
CONVERT_ONLY=false

# Track processed URLs to avoid duplicates (Zsh compatible)
PROCESSED_URLS=""

# Function to validate YouTube URL
is_valid_youtube_url() {
    local url="$1"
    # Basic validation to ensure it looks like a YouTube URL (includes Shorts)
    [[ "$url" =~ ^https?://(www\.)?(youtube\.com/watch\?v=|youtube\.com/shorts/|youtu\.be/|youtube\.com/playlist\?list=)[a-zA-Z0-9_-]+(&.*)?$ ]]
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
        # Convert to uppercase for case-insensitive comparison (Zsh compatible)
        choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')
        
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

# Function to check for duplicate URLs (Zsh compatible)
is_duplicate_url() {
    local url="$1"
    if [[ "$PROCESSED_URLS" == *"$url"* ]]; then
        echo "Skipping duplicate URL: $url"
        return 0
    fi
    return 1
}

# Function to fix malformed URLs
fix_malformed_url() {
    local url="$1"
    # Fix common malformed URLs
    if [[ "$url" =~ ^ttps:// ]]; then
        url="h${url}"
        echo "Fixed malformed URL: $url"
    fi
    echo "$url"
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

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --h264)
                H264_MODE=true
                shift
                ;;
            --convert-only)
                CONVERT_ONLY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS] <input_file_with_youtube_links>"
                echo ""
                echo "Options:"
                echo "  --h264         Use H.264 conversion workflow (best for analysis)"
                echo "  --convert-only Convert existing files only (skip download)"
                echo "  --help         Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 links.txt                    # Standard workflow"
                echo "  $0 --h264 links.txt             # H.264 conversion workflow"
                echo "  $0 --convert-only               # Convert existing files only"
                exit 0
                ;;
            *)
                # Assume this is the input file
                INPUT_FILE="$1"
                shift
                ;;
        esac
    done
}

# Function to download video in H.264 mode
download_video_h264() {
    local url="$1"
    local download_dir="$2"
    local video_id=""
    local raw_filename=""
    local converted_filename=""
    
    # Extract video ID from URL
    if [[ "$url" =~ youtube\.com/watch\?v=([a-zA-Z0-9_-]+) ]]; then
        video_id="${BASH_REMATCH[1]}"
    elif [[ "$url" =~ youtu\.be/([a-zA-Z0-9_-]+) ]]; then
        video_id="${BASH_REMATCH[1]}"
    elif [[ "$url" =~ youtube\.com/shorts/([a-zA-Z0-9_-]+) ]]; then
        video_id="${BASH_REMATCH[1]}"
    else
        echo "Could not extract video ID from URL: $url"
        return 1
    fi
    
    # Get video title for filename
    local title=$(yt-dlp --get-title "$url" 2>/dev/null)
    if [[ -z "$title" ]]; then
        title="video_${video_id}"
    fi
    
    # Clean title for filename
    title=$(echo "$title" | tr '[:space:]' '_' | tr -d '[:punct:]')
    raw_filename="raw_${title}_${video_id}.%(ext)s"
    converted_filename="${title}_${video_id}_h264.mp4"
    
    echo "Downloading: $title"
    
    # Download best video quality (no audio)
    yt-dlp \
        --output "$download_dir/$raw_filename" \
        --format "bestvideo" \
        --no-audio \
        "$url"
    
    if [[ $? -eq 0 ]]; then
        # Find the downloaded file
        local raw_file=$(find "$download_dir" -name "raw_${title}_${video_id}.*" -type f | head -1)
        
        if [[ -n "$raw_file" ]]; then
            echo "Converting to H.264..."
            ffmpeg -i "$raw_file" -c:v libx264 -crf 23 -preset veryfast -an "$download_dir/$converted_filename" -y
            
            if [[ $? -eq 0 ]]; then
                echo "Successfully converted: $converted_filename"
                # Remove raw file
                rm "$raw_file"
            else
                echo "Conversion failed for: $title"
            fi
        else
            echo "Could not find downloaded file for: $title"
        fi
    else
        echo "Download failed for: $title"
    fi
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
    local input_file="$INPUT_FILE"
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
        
        # Trim whitespace and carriage returns
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Fix malformed lines (missing 'h' in https)
        if [[ "$line" =~ ^ttps:// ]]; then
            line="h${line}"
            echo "Fixed malformed line: $line"
        fi
        
        # Extract YouTube URL
        url=$(extract_youtube_url "$line")
        
        # Check for duplicates
        if is_duplicate_url "$url"; then
            continue
        fi
        
        # Handle URL validation
        if handle_url_validation "$url"; then
            echo "Processing: $url"
            if [[ "$H264_MODE" == "true" ]]; then
                download_video_h264 "$url" "$download_dir"
            else
                download_video "$url" "$download_dir"
            fi
            # Mark URL as processed (even if download failed)
            PROCESSED_URLS="$PROCESSED_URLS $url"
            echo "---"
        fi
    done < "$input_file"

    echo "Download process completed."
}

# Parse command line arguments
parse_arguments "$@"

# Check if an input file is provided
if [[ -z "$INPUT_FILE" ]]; then
    echo "Usage: $0 [OPTIONS] <input_file_with_youtube_links>"
    echo "Use --help for more information"
    exit 1
fi

# Run the main function
main