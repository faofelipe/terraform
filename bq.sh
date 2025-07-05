#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

#----------------------------------------------------start--------------------------------------------------#

echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD}Starting Execution${RESET}"

# Step 1: Create a Cloud Resource Connection
echo "${BLUE}${BOLD}Creating a Cloud Resource Connection${RESET}"
bq mk --connection --location=US --project_id=$DEVSHELL_PROJECT_ID --connection_type=CLOUD_RESOURCE gemini_conn

# Step 2: Exporting service account
echo "${GREEN}${BOLD}Exporting service account${RESET}"
export SERVICE_ACCOUNT=$(bq show --format=json --connection $DEVSHELL_PROJECT_ID.US.gemini_conn | jq -r '.cloudResource.serviceAccountId')

# Step 3: Adding IAM Policy Binding for AI Platform User
echo "${YELLOW}${BOLD}Adding IAM Policy Binding for AI Platform User${RESET}"
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member=serviceAccount:$SERVICE_ACCOUNT \
    --role="roles/aiplatform.user"

# Step 4: Adding IAM Policy Binding for Storage Object Admin
echo "${BLUE}${BOLD}Adding IAM Policy Binding for Storage Object Admin${RESET}"
gcloud storage buckets add-iam-policy-binding gs://$DEVSHELL_PROJECT_ID-bucket \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/storage.objectAdmin"

# Step 5: Creating BigQuery Dataset gemini_demo
echo "${MAGENTA}${BOLD}Creating BigQuery Dataset gemini_demo${RESET}"
bq --location=US mk gemini_demo

# Step 6: Loading customer reviews data from CSV
echo "${CYAN}${BOLD}Loading customer reviews data from CSV${RESET}"
bq query --use_legacy_sql=false \
"
LOAD DATA OVERWRITE gemini_demo.customer_reviews
(customer_review_id INT64, customer_id INT64, location_id INT64, review_datetime DATETIME, review_text STRING, social_media_source STRING, social_media_handle STRING)
FROM FILES (
  format = 'CSV',
  uris = ['gs://$DEVSHELL_PROJECT_ID-bucket/gsp1246/customer_reviews.csv']);
"

# Create review_images external table
bq query --use_legacy_sql=false <<EOF
CREATE OR REPLACE EXTERNAL TABLE \`gemini_demo.review_images\`
WITH CONNECTION \`us.gemini_conn\`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://qwiklabs-gcp-03-c47f9de7fb22-bucket/gsp1246/images/*']
);
EOF
sleep 2

# Create Gemini model
bq query --use_legacy_sql=false <<EOF
CREATE OR REPLACE MODEL \`gemini_demo.gemini_2_0_flash\`
REMOTE WITH CONNECTION \`us.gemini_conn\`
OPTIONS (endpoint = 'gemini-2.0-flash');
EOF
sleep 2

echo "${GREEN}${BOLD}✔️ Setup concluído. Agora execute as queries do laboratório no console UI conforme as instruções do Qwiklabs.${RESET}"
