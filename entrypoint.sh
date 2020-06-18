#!/bin/sh

# Retrieve target repository
echo "Getting latest commit of ${INPUT_REPOSITORY}@${INPUT_BRANCH} ..."
git clone https://${GITHUB_ACTOR}:${INPUT_TOKEN}@github.com/${INPUT_REPOSITORY}.git target_repo/
cd target_repo

# Setup git user
git config user.email "actions@github.com"
git config user.name "${GITHUB_ACTOR}"

git checkout -f ${INPUT_BRANCH}
echo "Getting latest commit of ${INPUT_REPOSITORY}@${INPUT_BRANCH} ... DONE!"

# Retrieve shell script to run changes
if [ -n "${INPUT_CHANGES}" ]; then
    wget --tries=5 https://${GITHUB_ACTOR}:${INPUT_TOKEN}@raw.githubusercontent.com/${GITHUB_REPOSITORY}/${GITHUB_SHA}/${INPUT_CHANGES}

    FILENAME=$(python -c "import os; print(os.path.basename('${INPUT_CHANGES}'))")

    echo "Running 'changes' input file '${FILENAME}' ..."
    /bin/sh ${FILENAME}
    echo "Running 'changes' input file '${FILENAME}' ... DONE!"
fi

# Create new temporary repository
TEMPORARY_BRANCH="push-action/${GITHUB_RUN_ID}/$(uuidgen)"
echo "Creating temporary repository '${TEMPORARY_BRANCH}' ..."
git checkout -f -b ${TEMPORARY_BRANCH}
git push -f origin ${TEMPORARY_BRANCH}
echo "Creating temporary repository '${TEMPORARY_BRANCH}' ... DONE!"

{
    # Wait for status checks to complete
    echo "Waiting for status checks to finish for '${TEMPORARY_BRANCH}' ..." &&
    push-action --token "${INPUT_TOKEN}" --repo "${INPUT_REPOSITORY}" --ref "${INPUT_BRANCH}" --temp-branch "${TEMPORARY_BRANCH}" --wait-timeout "${INPUT_TIMEOUT}" --wait-interval "${INPUT_INTERVAL}" -- wait_for_checks &&
    echo "Waiting for status checks to finish for '${TEMPORARY_BRANCH}' ... DONE!" &&

    # Merge into target branch
    echo "Merging (fast-forward) '${TEMPORARY_BRANCH}' -> '${INPUT_BRANCH}' ..." &&
    git checkout ${INPUT_BRANCH} &&
    git merge --ff-only origin/${TEMPORARY_BRANCH} &&
    git push &&
    echo "Merging (fast-forward) '${TEMPORARY_BRANCH}' -> '${INPUT_BRANCH}' ... DONE!" &&

    # Remove temporary repository
    echo "Removing temporary branch '${TEMPORARY_BRANCH}' ..." &&
    push-action --token "${INPUT_TOKEN}" --repo "${INPUT_REPOSITORY}" --ref "${INPUT_BRANCH}" --temp-branch "${TEMPORARY_BRANCH}" -- remove_temp_branch &&
    echo "Removing temporary branch '${TEMPORARY_BRANCH}' ... DONE!"
} || {
    # Remove temporary repository
    echo "Removing temporary branch '${TEMPORARY_BRANCH}' ..." &&
    push-action --token "${INPUT_TOKEN}" --repo "${INPUT_REPOSITORY}" --ref "${INPUT_BRANCH}" --temp-branch "${TEMPORARY_BRANCH}" -- remove_temp_branch &&
    echo "Removing temporary branch '${TEMPORARY_BRANCH}' ... DONE!" &&
    exit 1
}