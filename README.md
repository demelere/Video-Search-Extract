# Video-Search-Extract

A specialized tool for collecting, analyzing, and extracting video data from specialized optical scenarios, with a focus on welding pool footage and other hard-to-capture industrial processes.

## Overview

This project addresses the challenge of collecting video data from specialized optical scenarios where standard recording setups are insufficient. Welding pool footage, for example, requires specific camera configurations, filters, and lighting conditions to capture clear, usable data.

## Current Functionality

- **Batch Video Ingestion**: Uses YouTube-DLP to batch download videos from personally identified and curated sources
- **Video Processing Pipeline**: Streamlined workflow for processing multiple videos simultaneously
- **Data Collection**: Focused on specialized industrial processes that require specific optical setups

## Planned Features

### Phase 1: Enhanced Video Collection
- [ ] Automated video discovery and filtering
- [ ] Quality assessment for specialized optical content
- [ ] Metadata extraction and tagging

### Phase 2: Semantic Video Understanding
- [ ] Integration with Vision Language Models (VLM) like SmolVLM
- [ ] Semantic analysis of video content
- [ ] Automatic detection of subjects of interest (e.g., weld pools)
- [ ] Timestamp extraction for relevant segments

### Phase 3: Intelligent Extraction
- [ ] Automated clip generation based on semantic analysis
- [ ] Batch processing of multiple videos for specific content
- [ ] Export functionality for extracted segments

## Use Cases

### Primary Focus: Welding Pool Analysis
- **Challenge**: Welding pools require specialized camera setups with specific filters and lighting
- **Solution**: Automated collection and analysis of available welding pool footage
- **Goal**: Build a comprehensive dataset for welding process analysis

### Extended Applications
- Other specialized industrial processes requiring specific optical conditions
- Research applications where standard video sources are insufficient
- Quality control and process monitoring in manufacturing

## Technical Stack

- **Video Download**: YouTube-DLP
- **Video Analysis**: Vision Language Models (planned)
- **Processing**: Python-based pipeline
- **Output**: Timestamped segments and extracted clips

## Getting Started

### Installation

1. **Make the script executable:**
   ```bash
   chmod +x yt-download.sh
   ```

2. **Add to PATH:**
   
   **For Bash:**
   ```bash
   echo 'export PATH="/Users/<username and path>/Video-Search-Extract:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```
   
   **For Zsh:**
   ```bash
   echo 'export PATH="/Users/<username and path>/Video-Search-Extract:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

### 📥 Usage

1. **Prepare Links File**
   
   Create a text file (e.g., `links.txt`) with YouTube URLs:
   ```
   https://youtu.be/video1 [Optional Description]
   https://youtube.com/watch?v=video2 [Another Description]
   ```

2. **Run the Script**
   
   **Standard workflow (with metadata):**
   ```bash
   yt-download.sh links.txt
   ```
   
   **H.264 conversion workflow (recommended for analysis):**
   ```bash
   yt-download.sh --h264 links.txt
   ```
   
   **Get help:**
   ```bash
   yt-download.sh --help
   ```

The script will prompt you for download directory preferences and handle file conflicts automatically.

### Workflow Options

- **Standard Mode**: Downloads with embedded metadata, subtitles, and chapters
- **H.264 Mode** (`--h264`): Downloads best video quality, converts to H.264 MP4 with CRF 23, removes audio and metadata for clean analysis files

## Contributing

This project is focused on specialized video data collection and analysis. Contributions related to:
- Vision Language Model integration
- Video processing optimization
- Specialized optical content detection
- Industrial process video analysis

are particularly welcome.

## License

*[To be determined]*
