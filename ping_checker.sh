#!/bin/bash

# Ping Checker - Enhanced Network Connectivity Tool with Parallel Processing
# Usage: ./ping_checker.sh [options] [sites...]

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_COUNT=3
DEFAULT_TIMEOUT=5
DEFAULT_MAX_PARALLEL=10

# Global arrays for results
declare -a RESULTS_SITE
declare -a RESULTS_STATUS
declare -a RESULTS_TIME
declare -a RESULTS_PACKET_LOSS
declare -a RESULTS_AVG_TIME

# Function to display help
show_help() {
    echo -e "${BLUE}Ping Checker - Enhanced Network Connectivity Tool${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] [SITES...]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --count NUM         Number of ping attempts (default: $DEFAULT_COUNT)"
    echo "  -t, --timeout SEC       Timeout in seconds (default: $DEFAULT_TIMEOUT)"
    echo "  -f, --file FILE         Read sites from file (one per line)"
    echo "  -v, --verbose           Show detailed ping output"
    echo "  -q, --quiet             Show only summary"
    echo "  -p, --parallel          Enable parallel pings (faster)"
    echo "  -j, --max-jobs NUM      Max parallel jobs (default: $DEFAULT_MAX_PARALLEL)"
    echo "  --csv FILE              Output results to CSV file"
    echo "  --json FILE             Output results to JSON file"
    echo "  --output-format FORMAT  Output format: text|csv|json (default: text)"
    echo ""
    echo "Examples:"
    echo "  $0 google.com github.com"
    echo "  $0 -p -j 5 -c 3 example.com"
    echo "  $0 --csv results.csv -f sites.txt"
    echo "  $0 --json results.json --parallel"
    echo "  $0 --output-format json > results.json"
}

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to parse ping output and extract statistics
parse_ping_output() {
    local output="$1"
    local packet_loss=""
    local avg_time=""
    
    # Extract packet loss percentage
    if echo "$output" | grep -q "packet loss"; then
        packet_loss=$(echo "$output" | grep "packet loss" | sed 's/.*(\([0-9]*\)% packet loss).*/\1/')
    else
        packet_loss="100"
    fi
    
    # Extract average time
    if echo "$output" | grep -q "min/avg/max"; then
        avg_time=$(echo "$output" | grep "min/avg/max" | cut -d'/' -f5 | cut -d' ' -f1)
    else
        avg_time="0"
    fi
    
    echo "$packet_loss|$avg_time"
}

# Function to ping a single site (designed for parallel execution)
ping_site_parallel() {
    local site="$1"
    local count="$2"
    local timeout="$3"
    local verbose="$4"
    local index="$5"
    
    local start_time=$(date +%s.%N)
    
    # Perform the ping
    local ping_output
    ping_output=$(ping -c "$count" -W "$timeout" "$site" 2>&1)
    local ping_result=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    # Parse ping statistics
    local stats
    stats=$(parse_ping_output "$ping_output")
    local packet_loss=$(echo "$stats" | cut -d'|' -f1)
    local avg_time=$(echo "$stats" | cut -d'|' -f2)
    
    # Store results in temporary files (for parallel processing)
    local temp_dir="/tmp/ping_checker_$$"
    mkdir -p "$temp_dir"
    
    echo "$site" > "$temp_dir/site_$index"
    echo "$ping_result" > "$temp_dir/status_$index"
    echo "$duration" > "$temp_dir/time_$index"
    echo "$packet_loss" > "$temp_dir/loss_$index"
    echo "$avg_time" > "$temp_dir/avg_$index"
    
    if [ "$verbose" = true ]; then
        echo "$ping_output" > "$temp_dir/output_$index"
    fi
    
    # Display immediate result if not quiet
    if [ "$verbose" = true ]; then
        echo -e "${BLUE}🔍 [$index] Pinging $site with $count packets, timeout ${timeout}s...${NC}"
        echo "$ping_output"
    fi
    
    if [ $ping_result -eq 0 ]; then
        echo -e "${GREEN}✅ [$index] $site is reachable (${avg_time}ms avg)${NC}"
    else
        echo -e "${RED}❌ [$index] $site is not reachable${NC}"
    fi
}

# Function to ping a single site (sequential version)
ping_site() {
    local site="$1"
    local count="$2"
    local timeout="$3"
    local verbose="$4"
    
    if [ "$verbose" = true ]; then
        echo -e "${BLUE}🔍 Pinging $site with $count packets, timeout ${timeout}s...${NC}"
    else
        echo -e "🔍 Pinging $site..."
    fi
    
    local start_time=$(date +%s.%N)
    
    # Perform the ping
    local ping_output
    if [ "$verbose" = true ]; then
        ping_output=$(ping -c "$count" -W "$timeout" "$site" 2>&1)
        ping_result=$?
        echo "$ping_output"
    else
        ping_output=$(ping -c "$count" -W "$timeout" "$site" 2>&1)
        ping_result=$?
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    # Parse ping statistics
    local stats
    stats=$(parse_ping_output "$ping_output")
    local packet_loss=$(echo "$stats" | cut -d'|' -f1)
    local avg_time=$(echo "$stats" | cut -d'|' -f2)
    
    # Store results
    RESULTS_SITE+=("$site")
    RESULTS_TIME+=("$duration")
    RESULTS_PACKET_LOSS+=("$packet_loss")
    RESULTS_AVG_TIME+=("$avg_time")
    
    # Check result and display status
    if [ $ping_result -eq 0 ]; then
        echo -e "${GREEN}✅ $site is reachable (${avg_time}ms avg, ${packet_loss}% loss)${NC}"
        RESULTS_STATUS+=("success")
        return 0
    else
        echo -e "${RED}❌ $site is not reachable (${packet_loss}% loss)${NC}"
        RESULTS_STATUS+=("failed")
        return 1
    fi
}

# Function to collect parallel results
collect_parallel_results() {
    local temp_dir="/tmp/ping_checker_$$"
    local total_sites="$1"
    
    # Clear previous results
    RESULTS_SITE=()
    RESULTS_STATUS=()
    RESULTS_TIME=()
    RESULTS_PACKET_LOSS=()
    RESULTS_AVG_TIME=()
    
    # Collect results from temporary files
    for ((i=0; i<total_sites; i++)); do
        if [ -f "$temp_dir/site_$i" ]; then
            RESULTS_SITE+=($(cat "$temp_dir/site_$i"))
            
            local status_code=$(cat "$temp_dir/status_$i")
            if [ "$status_code" -eq 0 ]; then
                RESULTS_STATUS+=("success")
            else
                RESULTS_STATUS+=("failed")
            fi
            
            RESULTS_TIME+=($(cat "$temp_dir/time_$i"))
            RESULTS_PACKET_LOSS+=($(cat "$temp_dir/loss_$i"))
            RESULTS_AVG_TIME+=($(cat "$temp_dir/avg_$i"))
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to output results in CSV format
output_csv() {
    local file="$1"
    local timestamp=$(get_timestamp)
    
    {
        echo "timestamp,site,status,duration_seconds,packet_loss_percent,avg_ping_ms"
        for ((i=0; i<${#RESULTS_SITE[@]}; i++)); do
            echo "$timestamp,${RESULTS_SITE[i]},${RESULTS_STATUS[i]},${RESULTS_TIME[i]},${RESULTS_PACKET_LOSS[i]},${RESULTS_AVG_TIME[i]}"
        done
    } > "$file"
}

# Function to output results in JSON format
output_json() {
    local file="$1"
    local timestamp=$(get_timestamp)
    
    {
        echo "{"
        echo "  \"timestamp\": \"$timestamp\","
        echo "  \"results\": ["
        
        for ((i=0; i<${#RESULTS_SITE[@]}; i++)); do
            echo "    {"
            echo "      \"site\": \"${RESULTS_SITE[i]}\","
            echo "      \"status\": \"${RESULTS_STATUS[i]}\","
            echo "      \"duration_seconds\": ${RESULTS_TIME[i]},"
            echo "      \"packet_loss_percent\": ${RESULTS_PACKET_LOSS[i]},"
            echo "      \"avg_ping_ms\": ${RESULTS_AVG_TIME[i]}"
            if [ $i -eq $((${#RESULTS_SITE[@]} - 1)) ]; then
                echo "    }"
            else
                echo "    },"
            fi
        done
        
        echo "  ],"
        echo "  \"summary\": {"
        
        local successful=0
        local failed=0
        for status in "${RESULTS_STATUS[@]}"; do
            if [ "$status" = "success" ]; then
                ((successful++))
            else
                ((failed++))
            fi
        done
        
        echo "    \"total\": $((successful + failed)),"
        echo "    \"successful\": $successful,"
        echo "    \"failed\": $failed"
        echo "  }"
        echo "}"
    } > "$file"
}

# Function to read sites from file
read_sites_from_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File '$file' not found${NC}"
        exit 1
    fi
    
    # Read non-empty lines, ignoring comments
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$'
}

# Function to validate if a string looks like a valid hostname/IP
is_valid_target() {
    local target="$1"
    # Basic validation - could be enhanced
    if [[ "$target" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main function
main() {
    local count=$DEFAULT_COUNT
    local timeout=$DEFAULT_TIMEOUT
    local verbose=false
    local quiet=false
    local parallel=false
    local max_jobs=$DEFAULT_MAX_PARALLEL
    local input_file=""
    local csv_file=""
    local json_file=""
    local output_format="text"
    local sites=()
    local successful=0
    local failed=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--count)
                count="$2"
                shift 2
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -f|--file)
                input_file="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -p|--parallel)
                parallel=true
                shift
                ;;
            -j|--max-jobs)
                max_jobs="$2"
                shift 2
                ;;
            --csv)
                csv_file="$2"
                shift 2
                ;;
            --json)
                json_file="$2"
                shift 2
                ;;
            --output-format)
                output_format="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}"
                show_help
                exit 1
                ;;
            *)
                sites+=("$1")
                shift
                ;;
        esac
    done
    
    # Validate numeric arguments
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
        echo -e "${RED}Error: Count must be a positive integer${NC}"
        exit 1
    fi
    
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [ "$timeout" -lt 1 ]; then
        echo -e "${RED}Error: Timeout must be a positive integer${NC}"
        exit 1
    fi
    
    if ! [[ "$max_jobs" =~ ^[0-9]+$ ]] || [ "$max_jobs" -lt 1 ]; then
        echo -e "${RED}Error: Max jobs must be a positive integer${NC}"
        exit 1
    fi
    
    # Validate output format
    if [[ "$output_format" != "text" && "$output_format" != "csv" && "$output_format" != "json" ]]; then
        echo -e "${RED}Error: Output format must be text, csv, or json${NC}"
        exit 1
    fi
    
    # Get sites list
    if [ -n "$input_file" ]; then
        mapfile -t file_sites < <(read_sites_from_file "$input_file")
        sites+=("${file_sites[@]}")
    fi
    
    # Use default sites if none provided
    if [ ${#sites[@]} -eq 0 ]; then
        sites=("google.com" "github.com" "stackoverflow.com" "8.8.8.8" "1.1.1.1")
        if [ "$quiet" = false ] && [ "$output_format" = "text" ]; then
            echo -e "${YELLOW}No sites specified. Using default sites...${NC}"
        fi
    fi
    
    # Display configuration (unless quiet or non-text output)
    if [ "$quiet" = false ] && [ "$output_format" = "text" ]; then
        echo -e "${BLUE}=== Ping Checker Started ===${NC}"
        echo -e "Sites to check: ${#sites[@]}"
        echo -e "Ping count: $count"
        echo -e "Timeout: ${timeout}s"
        if [ "$parallel" = true ]; then
            echo -e "Mode: Parallel (max $max_jobs jobs)"
        else
            echo -e "Mode: Sequential"
        fi
        echo ""
    fi
    
    # Record start time
    local start_time=$(date +%s)
    
    # Check each site
    if [ "$parallel" = true ]; then
        echo -e "${BLUE}🚀 Running parallel pings...${NC}"
        
        # Start background jobs with job control
        local job_count=0
        local site_index=0
        
        for site in "${sites[@]}"; do
            if ! is_valid_target "$site"; then
                if [ "$output_format" = "text" ]; then
                    echo -e "${RED}⚠️  Skipping invalid target: $site${NC}"
                fi
                continue
            fi
            
            # Wait if we've reached max parallel jobs
            while [ $job_count -ge $max_jobs ]; do
                wait -n  # Wait for any background job to complete
                ((job_count--))
            done
            
            # Start background ping
            ping_site_parallel "$site" "$count" "$timeout" "$verbose" "$site_index" &
            ((job_count++))
            ((site_index++))
        done
        
        # Wait for all remaining jobs to complete
        wait
        
        # Collect results from temporary files
        collect_parallel_results "$site_index"
        
    else
        # Sequential processing
        for site in "${sites[@]}"; do
            if ! is_valid_target "$site"; then
                if [ "$output_format" = "text" ]; then
                    echo -e "${RED}⚠️  Skipping invalid target: $site${NC}"
                fi
                continue
            fi
            
            if ping_site "$site" "$count" "$timeout" "$verbose"; then
                ((successful++))
            else
                ((failed++))
            fi
            
            # Add spacing between sites (unless quiet or last item)
            if [ "$quiet" = false ] && [ "$output_format" = "text" ] && [ "$site" != "${sites[-1]}" ]; then
                echo ""
            fi
        done
    fi
    
    # Calculate totals for parallel mode
    if [ "$parallel" = true ]; then
        for status in "${RESULTS_STATUS[@]}"; do
            if [ "$status" = "success" ]; then
                ((successful++))
            else
                ((failed++))
            fi
        done
    fi
    
    # Record end time and calculate duration
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Output results based on format
    case "$output_format" in
        "csv")
            output_csv "/dev/stdout"
            ;;
        "json")
            output_json "/dev/stdout"
            ;;
        *)
            # Display summary (text format)
            if [ "$output_format" = "text" ]; then
                echo ""
                echo -e "${BLUE}=== Summary ===${NC}"
                echo -e "${GREEN}✅ Successful: $successful${NC}"
                echo -e "${RED}❌ Failed: $failed${NC}"
                echo -e "Total checked: $((successful + failed))"
                echo -e "Total time: ${total_duration}s"
                
                if [ $failed -eq 0 ]; then
                    echo -e "${GREEN}All sites are reachable!${NC}"
                else
                    echo -e "${RED}Some sites are unreachable.${NC}"
                fi
            fi
            ;;
    esac
    
    # Save to files if specified
    if [ -n "$csv_file" ]; then
        output_csv "$csv_file"
        if [ "$output_format" = "text" ]; then
            echo -e "${BLUE}Results saved to $csv_file${NC}"
        fi
    fi
    
    if [ -n "$json_file" ]; then
        output_json "$json_file"
        if [ "$output_format" = "text" ]; then
            echo -e "${BLUE}Results saved to $json_file${NC}"
        fi
    fi
    
    # Exit with appropriate code
    if [ $failed -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Check for required dependencies
check_dependencies() {
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}Warning: 'bc' command not found. Duration calculations may not work properly.${NC}"
        echo "Install with: sudo apt-get install bc (Ubuntu/Debian) or brew install bc (macOS)"
    fi
}

# Check dependencies and run main function
check_dependencies
main "$@"    
