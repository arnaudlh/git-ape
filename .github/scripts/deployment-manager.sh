#!/bin/bash
# Cloud Deployment State Manager
# Utility script for managing deployment artifacts and state persistence
# Supports both Azure (.azure/deployments/) and AWS (.aws/deployments/)

set -euo pipefail

AZURE_DEPLOYMENTS_DIR=".azure/deployments"
AWS_DEPLOYMENTS_DIR=".aws/deployments"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detect cloud provider from deployment path or metadata
detect_cloud() {
    local deployment_path="$1"
    if [[ "$deployment_path" == *".aws/"* ]]; then
        echo "aws"
    elif [[ "$deployment_path" == *".azure/"* ]]; then
        echo "azure"
    elif [[ -f "$deployment_path/metadata.json" ]]; then
        jq -r '.cloud // "azure"' "$deployment_path/metadata.json"
    else
        echo "unknown"
    fi
}

# Resolve a deployment ID to its full path (searches both cloud dirs)
resolve_deployment_path() {
    local deployment_id="$1"
    local cloud_filter="${2:-}"

    if [[ -n "$cloud_filter" ]]; then
        case "$cloud_filter" in
            azure) echo "$WORKSPACE_ROOT/$AZURE_DEPLOYMENTS_DIR/$deployment_id"; return ;;
            aws)   echo "$WORKSPACE_ROOT/$AWS_DEPLOYMENTS_DIR/$deployment_id"; return ;;
        esac
    fi

    # Search both directories
    if [[ -d "$WORKSPACE_ROOT/$AZURE_DEPLOYMENTS_DIR/$deployment_id" ]]; then
        echo "$WORKSPACE_ROOT/$AZURE_DEPLOYMENTS_DIR/$deployment_id"
    elif [[ -d "$WORKSPACE_ROOT/$AWS_DEPLOYMENTS_DIR/$deployment_id" ]]; then
        echo "$WORKSPACE_ROOT/$AWS_DEPLOYMENTS_DIR/$deployment_id"
    else
        echo ""
    fi
}

# Print deployments from a single cloud directory
list_cloud_deployments() {
    local cloud="$1"
    local deployments_dir="$2"
    local full_path="$WORKSPACE_ROOT/$deployments_dir"

    if [[ ! -d "$full_path" ]]; then
        return 0
    fi

    local found=0
    for dir in $(ls -t "$full_path" 2>/dev/null); do
        if [[ -d "$full_path/$dir" ]]; then
            found=1
            METADATA_FILE="$full_path/$dir/metadata.json"

            if [[ -f "$METADATA_FILE" ]]; then
                STATUS=$(jq -r '.status // "unknown"' "$METADATA_FILE")
                TIMESTAMP=$(jq -r '.timestamp // "N/A"' "$METADATA_FILE")
                RESOURCES=$(jq -r '.resources // [] | length' "$METADATA_FILE")
                REGION=$(jq -r '.region // "N/A"' "$METADATA_FILE")
                PROJECT=$(jq -r '.project // "N/A"' "$METADATA_FILE")
                COST=$(jq -r '.estimatedMonthlyCost // "N/A"' "$METADATA_FILE")

                # Color code based on status
                case "$STATUS" in
                    "succeeded"|"completed")
                        COLOR=$GREEN
                        SYMBOL="✓"
                        ;;
                    "failed")
                        COLOR=$RED
                        SYMBOL="✗"
                        ;;
                    "in-progress"|"deploying")
                        COLOR=$YELLOW
                        SYMBOL="⧗"
                        ;;
                    "rolled-back")
                        COLOR=$YELLOW
                        SYMBOL="↶"
                        ;;
                    "destroyed"|"already-destroyed")
                        COLOR=$RED
                        SYMBOL="🔴"
                        ;;
                    "destroy-requested")
                        COLOR=$YELLOW
                        SYMBOL="⚠"
                        ;;
                    *)
                        COLOR=$NC
                        SYMBOL="?"
                        ;;
                esac

                echo -e "${COLOR}${SYMBOL} ${dir}${NC}"
                echo -e "  Status: ${STATUS} | Project: ${PROJECT} | Region: ${REGION}"
                echo -e "  Resources: ${RESOURCES} | Cost: ${COST} | Time: ${TIMESTAMP}"
            else
                echo -e "${YELLOW}? ${dir}${NC}"
                echo "  (missing metadata.json)"
            fi
            echo ""
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo -e "  ${YELLOW}No deployments found${NC}"
        echo ""
    fi
}

# Command: list
# List all deployments with status across both clouds
list_deployments() {
    local cloud_filter="${1:-}"

    echo -e "${BLUE}Recent Deployments${NC}"
    echo "-----------------------------------------------------------"

    if [[ -z "$cloud_filter" || "$cloud_filter" == "azure" ]]; then
        echo -e "\n${CYAN}☁ Azure${NC} (.azure/deployments/)"
        echo "-----------------------------------------------------------"
        list_cloud_deployments "azure" "$AZURE_DEPLOYMENTS_DIR"
    fi

    if [[ -z "$cloud_filter" || "$cloud_filter" == "aws" ]]; then
        echo -e "${CYAN}☁ AWS${NC} (.aws/deployments/)"
        echo "-----------------------------------------------------------"
        list_cloud_deployments "aws" "$AWS_DEPLOYMENTS_DIR"
    fi
}

# Command: show
# Show details of a specific deployment
show_deployment() {
    local DEPLOYMENT_ID="$1"
    local CLOUD_FILTER="${2:-}"
    local DEPLOYMENT_PATH
    DEPLOYMENT_PATH=$(resolve_deployment_path "$DEPLOYMENT_ID" "$CLOUD_FILTER")
    
    if [[ -z "$DEPLOYMENT_PATH" || ! -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    local CLOUD
    CLOUD=$(detect_cloud "$DEPLOYMENT_PATH")
    
    echo -e "${BLUE}Deployment Details: $DEPLOYMENT_ID${NC} (${CYAN}${CLOUD}${NC})"
    echo "-----------------------------------------------------------"
    
    # Show metadata if available
    if [[ -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        echo -e "\n${GREEN}Metadata:${NC}"
        jq '.' "$DEPLOYMENT_PATH/metadata.json"
    fi
    
    # Show requirements if available
    if [[ -f "$DEPLOYMENT_PATH/requirements.json" ]]; then
        echo -e "\n${GREEN}Requirements:${NC}"
        jq '.resources[] | {type, name, region}' "$DEPLOYMENT_PATH/requirements.json" 2>/dev/null || \
        jq '.' "$DEPLOYMENT_PATH/requirements.json"
    fi
    
    # Show deployment status
    if [[ -f "$DEPLOYMENT_PATH/deployment.log" ]]; then
        echo -e "\n${GREEN}Deployment Log (last 20 lines):${NC}"
        tail -20 "$DEPLOYMENT_PATH/deployment.log"
    fi
    
    # Show test results if available
    if [[ -f "$DEPLOYMENT_PATH/tests.json" ]]; then
        echo -e "\n${GREEN}Test Results:${NC}"
        jq '.tests[] | {name, status, result}' "$DEPLOYMENT_PATH/tests.json" 2>/dev/null || \
        jq '.' "$DEPLOYMENT_PATH/tests.json"
    fi
    
    # Show errors if any
    if [[ -f "$DEPLOYMENT_PATH/error.log" ]]; then
        echo -e "\n${RED}Errors:${NC}"
        cat "$DEPLOYMENT_PATH/error.log"
    fi
}

# Command: clean
# Clean up old/failed deployments
clean_deployments() {
    local KEEP_COUNT="${1:-10}"
    local CLOUD_FILTER="${2:-}"
    
    echo -e "${YELLOW}Cleaning up old deployments (keeping $KEEP_COUNT most recent per cloud)...${NC}"
    
    local dirs_to_clean=()
    if [[ -z "$CLOUD_FILTER" || "$CLOUD_FILTER" == "azure" ]]; then
        dirs_to_clean+=("$WORKSPACE_ROOT/$AZURE_DEPLOYMENTS_DIR")
    fi
    if [[ -z "$CLOUD_FILTER" || "$CLOUD_FILTER" == "aws" ]]; then
        dirs_to_clean+=("$WORKSPACE_ROOT/$AWS_DEPLOYMENTS_DIR")
    fi

    for deploy_dir in "${dirs_to_clean[@]}"; do
        if [[ ! -d "$deploy_dir" ]]; then
            continue
        fi

        echo -e "\n${CYAN}Cleaning: $deploy_dir${NC}"
        cd "$deploy_dir"
        
        TOTAL=$(ls -d */ 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ $TOTAL -le $KEEP_COUNT ]]; then
            echo "Only $TOTAL deployments found, nothing to clean"
            continue
        fi
        
        TO_DELETE=$(ls -tr | head -n -"$KEEP_COUNT")
        
        echo "Will delete the following deployments:"
        echo "$TO_DELETE"
        echo ""
        echo -n "Proceed? (y/N): "
        read -r CONFIRM
        
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            for dir in $TO_DELETE; do
                echo "Deleting $dir..."
                rm -rf "$dir"
            done
            echo -e "${GREEN}Cleanup complete${NC}"
        else
            echo "Cancelled"
        fi
    done
}

# Command: export
# Export deployment artifacts as a reusable template
export_deployment() {
    local DEPLOYMENT_ID="$1"
    local OUTPUT_FILE="${2:-}"
    local DEPLOYMENT_PATH
    DEPLOYMENT_PATH=$(resolve_deployment_path "$DEPLOYMENT_ID")
    
    if [[ -z "$DEPLOYMENT_PATH" || ! -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    local CLOUD
    CLOUD=$(detect_cloud "$DEPLOYMENT_PATH")

    # Determine template file name based on cloud
    local TEMPLATE_FILE="template.json"
    if [[ "$CLOUD" == "aws" && -f "$DEPLOYMENT_PATH/template.yaml" ]]; then
        TEMPLATE_FILE="template.yaml"
    fi

    if [[ ! -f "$DEPLOYMENT_PATH/$TEMPLATE_FILE" ]]; then
        echo -e "${RED}Template not found for deployment: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    # Default output path based on cloud
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE=".${CLOUD}/templates/${DEPLOYMENT_ID}.${TEMPLATE_FILE##*.}"
    fi
    
    # Create output directory
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    # Copy template
    cp "$DEPLOYMENT_PATH/$TEMPLATE_FILE" "$OUTPUT_FILE"
    
    # Copy parameters if available (Azure uses parameters.json)
    if [[ -f "$DEPLOYMENT_PATH/parameters.json" ]]; then
        cp "$DEPLOYMENT_PATH/parameters.json" "${OUTPUT_FILE%.*}.parameters.json"
        echo -e "${GREEN}Exported deployment template to:${NC}"
        echo "  Template: $OUTPUT_FILE"
        echo "  Parameters: ${OUTPUT_FILE%.*}.parameters.json"
    else
        echo -e "${GREEN}Exported deployment template to:${NC}"
        echo "  Template: $OUTPUT_FILE"
    fi
}

# Command: init
# Initialize deployment state directory structure
init_deployment() {
    local DEPLOYMENT_ID="${1:-deploy-$(date +%Y%m%d-%H%M%S)}"
    local CLOUD="${2:-azure}"

    local DEPLOYMENTS_DIR
    case "$CLOUD" in
        azure) DEPLOYMENTS_DIR="$AZURE_DEPLOYMENTS_DIR" ;;
        aws)   DEPLOYMENTS_DIR="$AWS_DEPLOYMENTS_DIR" ;;
        *)
            echo -e "${RED}Unknown cloud provider: $CLOUD (use 'azure' or 'aws')${NC}"
            exit 1
            ;;
    esac

    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"
    
    if [[ -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${YELLOW}Deployment already exists: $DEPLOYMENT_ID${NC}"
        exit 1
    fi
    
    # Create directory structure
    mkdir -p "$DEPLOYMENT_PATH"
    
    # Create initial metadata
    if [[ "$CLOUD" == "azure" ]]; then
        cat > "$DEPLOYMENT_PATH/metadata.json" <<EOF
{
  "deploymentId": "$DEPLOYMENT_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": "$(az account show --query user.name -o tsv 2>/dev/null || echo 'unknown')",
  "status": "initialized",
  "resources": []
}
EOF
    else
        cat > "$DEPLOYMENT_PATH/metadata.json" <<EOF
{
  "deploymentId": "$DEPLOYMENT_ID",
  "cloud": "aws",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": "$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo 'unknown')",
  "status": "initialized",
  "resources": []
}
EOF
    fi
    
    # Create empty deployment log
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deployment initialized ($CLOUD)" > "$DEPLOYMENT_PATH/deployment.log"
    
    echo -e "${GREEN}Initialized $CLOUD deployment: $DEPLOYMENT_ID${NC}"
    echo "Path: $DEPLOYMENT_PATH"
    echo ""
    echo "Next steps:"
    echo "  1. Save requirements to: $DEPLOYMENT_PATH/requirements.json"
    if [[ "$CLOUD" == "azure" ]]; then
        echo "  2. Save template to: $DEPLOYMENT_PATH/template.json"
    else
        echo "  2. Save template to: $DEPLOYMENT_PATH/template.yaml"
    fi
    echo "  3. Update status in: $DEPLOYMENT_PATH/metadata.json"
}

# Command: validate
# Validate deployment state files
validate_deployment() {
    local DEPLOYMENT_ID="$1"
    local DEPLOYMENT_PATH
    DEPLOYMENT_PATH=$(resolve_deployment_path "$DEPLOYMENT_ID")
    
    if [[ -z "$DEPLOYMENT_PATH" || ! -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    local CLOUD
    CLOUD=$(detect_cloud "$DEPLOYMENT_PATH")
    
    echo -e "${BLUE}Validating deployment: $DEPLOYMENT_ID${NC} (${CYAN}${CLOUD}${NC})"
    echo "-----------------------------------------------------------"
    
    local ERRORS=0
    
    # Check required files
    if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        echo -e "${RED}✗ Missing metadata.json${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ metadata.json found${NC}"
        # Validate JSON
        if ! jq empty "$DEPLOYMENT_PATH/metadata.json" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON format${NC}"
            ((ERRORS++))
        fi
    fi
    
    if [[ -f "$DEPLOYMENT_PATH/requirements.json" ]]; then
        echo -e "${GREEN}✓ requirements.json found${NC}"
        if ! jq empty "$DEPLOYMENT_PATH/requirements.json" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON format${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠ requirements.json not found${NC}"
    fi

    # Check for template (JSON for Azure, YAML or JSON for AWS)
    local template_found=0
    if [[ -f "$DEPLOYMENT_PATH/template.json" ]]; then
        echo -e "${GREEN}✓ template.json found${NC}"
        if ! jq empty "$DEPLOYMENT_PATH/template.json" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON format${NC}"
            ((ERRORS++))
        fi
        template_found=1
    fi
    if [[ -f "$DEPLOYMENT_PATH/template.yaml" ]]; then
        echo -e "${GREEN}✓ template.yaml found${NC}"
        template_found=1
    fi
    if [[ $template_found -eq 0 ]]; then
        echo -e "${YELLOW}⚠ template.json/template.yaml not found${NC}"
    fi

    if [[ -f "$DEPLOYMENT_PATH/architecture.md" ]]; then
        echo -e "${GREEN}✓ architecture.md found${NC}"
    else
        echo -e "${YELLOW}⚠ architecture.md not found${NC}"
    fi
    
    echo ""
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "${GREEN}✓ Deployment state is valid${NC}"
        return 0
    else
        echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
        return 1
    fi
}

# Main command dispatcher
main() {
    local COMMAND="${1:-}"
    
    case "$COMMAND" in
        list)
            list_deployments "${2:-}"
            ;;
        show)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 show <deployment-id> [cloud]"
                exit 1
            fi
            show_deployment "$2" "${3:-}"
            ;;
        clean)
            clean_deployments "${2:-10}" "${3:-}"
            ;;
        export)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 export <deployment-id> [output-file]"
                exit 1
            fi
            export_deployment "$2" "${3:-}"
            ;;
        init)
            init_deployment "${2:-}" "${3:-azure}"
            ;;
        validate)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 validate <deployment-id>"
                exit 1
            fi
            validate_deployment "$2"
            ;;
        *)
            echo "Cloud Deployment State Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  list [cloud]            List all deployments (filter: azure, aws, or omit for both)"
            echo "  show <id> [cloud]       Show details of a specific deployment"
            echo "  clean [keep] [cloud]    Clean up old deployments (default: keep 10)"
            echo "  export <id> [file]      Export deployment as reusable template"
            echo "  init [id] [cloud]       Initialize new deployment directory (default: azure)"
            echo "  validate <id>           Validate deployment state files"
            echo ""
            echo "Clouds: azure, aws"
            echo ""
            echo "Examples:"
            echo "  $0 list                              # List all deployments"
            echo "  $0 list aws                           # List AWS deployments only"
            echo "  $0 show deploy-20260218-143022"
            echo "  $0 init my-lambda-dev aws              # Initialize AWS deployment"
            echo "  $0 export deploy-20260218-143022 my-template.json"
            echo "  $0 clean 5"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
